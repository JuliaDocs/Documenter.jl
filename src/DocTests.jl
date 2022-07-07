"""
Provides the [`doctest`](@ref) function that makes sure that the `jldoctest` code blocks
in the documents and docstrings run and are up to date.
"""
module DocTests
using DocStringExtensions
using Random: default_rng

import ..Documenter:
    DocSystem,
    DocMeta,
    Documenter,
    Documents,
    Expanders,
    Utilities,
    IdDict

import Markdown, REPL
import .Utilities: Markdown2, @docerror
import IOCapture

# Julia code block testing.
# -------------------------

mutable struct MutableMD2CodeBlock
    language :: String
    code :: String
end
MutableMD2CodeBlock(block :: Markdown2.CodeBlock) = MutableMD2CodeBlock(block.language, block.code)

struct DocTestContext
    file :: String
    doc :: Documents.Document
    meta :: Dict{Symbol, Any}
    DocTestContext(file::String, doc::Documents.Document) = new(file, doc, Dict())
end

"""
$(SIGNATURES)

Traverses the pages and modules in the documenter blueprint, searching and
executing doctests.

Will abort the document generation when an error is thrown. Use `doctest = false`
keyword in [`Documenter.makedocs`](@ref) to disable doctesting.
"""
function doctest(blueprint::Documents.DocumentBlueprint, doc::Documents.Document)
    @debug "Running doctests."
    # find all the doctest blocks in the pages
    for (src, page) in blueprint.pages
        if Utilities.is_draft(doc, page)
            @debug "Skipping page-doctests in draft mode" page.source
            continue
        end
        doctest(page, doc)
    end

    if Utilities.is_draft(doc)
        @debug "Skipping docstring-doctests in draft mode"
        return
    end

    # find all the doctest block in all the docstrings (within specified modules)
    for mod in blueprint.modules
        for (binding, multidoc) in DocSystem.getmeta(mod)
            for signature in multidoc.order
                doctest(multidoc.docs[signature], mod, doc)
            end
        end
    end
end

function doctest(page::Documents.Page, doc::Documents.Document)
    ctx = DocTestContext(page.source, doc) # FIXME
    ctx.meta[:CurrentFile] = page.source
    doctest(ctx, page.md2ast)
end

function doctest(docstr::Docs.DocStr, mod::Module, doc::Documents.Document)
    md = DocSystem.parsedoc(docstr)
    # Note: parsedocs / formatdoc in Base is weird. It double-wraps the docstring Markdown
    # in a Markdown.MD object..
    @assert isa(md, Markdown.MD) # relying on Julia internals here
    while length(md.content) == 1 && isa(first(md.content), Markdown.MD)
        md = first(md.content)
    end
    md2ast = try
        Markdown2.convert(Markdown2.MD, md)
    catch err
        @error """
            Markdown2 conversion error for a docstring in $(mod).
            This is a bug — please report this on the Documenter issue tracker
            """ docstr.data
        rethrow(err)
    end
    ctx = DocTestContext(docstr.data[:path], doc)
    merge!(ctx.meta, DocMeta.getdocmeta(mod))
    ctx.meta[:CurrentFile] = get(docstr.data, :path, nothing)
    doctest(ctx, md2ast)
end

function parse_metablock(ctx::DocTestContext, block::Markdown2.CodeBlock)
    @assert startswith(block.language, "@meta")
    meta = Dict{Symbol, Any}()
    for (ex, str) in Utilities.parseblock(block.code, ctx.doc, ctx.file)
        if Utilities.isassign(ex)
            try
                meta[ex.args[1]] = Core.eval(Main, ex.args[2])
            catch err
                @docerror(ctx.doc, :meta_block, "Failed to evaluate `$(strip(str))` in `@meta` block.", exception = err)
            end
        end
    end
    return meta
end

function doctest(ctx::DocTestContext, md2ast::Markdown2.MD)
    Markdown2.walk(md2ast) do node
        isa(node, Markdown2.CodeBlock) || return true
        if startswith(node.language, "jldoctest")
            doctest(ctx, node)
        elseif startswith(node.language, "@meta")
            merge!(ctx.meta, parse_metablock(ctx, node))
        else
            return true
        end
        return false
    end
end

function doctest(ctx::DocTestContext, block_immutable::Markdown2.CodeBlock)
    lang = block_immutable.language
    if startswith(lang, "jldoctest")
        # Define new module or reuse an old one from this page if we have a named doctest.
        name = match(r"jldoctest[ ]?(.*)$", split(lang, ';', limit = 2)[1])[1]
        sandbox = Utilities.get_sandbox_module!(ctx.meta, "doctest", name)

        # Normalise line endings.
        block = MutableMD2CodeBlock(block_immutable)
        block.code = replace(block.code, "\r\n" => "\n")

        # parse keyword arguments to doctest
        d = Dict()
        idx = findfirst(c -> c == ';', lang)
        if idx !== nothing
            kwargs = try
                Meta.parse("($(lang[nextind(lang, idx):end]),)")
            catch e
                e isa Meta.ParseError || rethrow(e)
                file = ctx.meta[:CurrentFile]
                lines = Utilities.find_block_in_file(block.code, file)
                @docerror(ctx.doc, :doctest,
                    """
                    Unable to parse doctest keyword arguments in $(Utilities.locrepr(file, lines))
                    Use ```jldoctest name; key1 = value1, key2 = value2

                    ```$(lang)
                    $(block.code)
                    ```
                    """, parse_error = e)
                return false
            end
            for kwarg in kwargs.args
                if !(isa(kwarg, Expr) && kwarg.head === :(=) && isa(kwarg.args[1], Symbol))
                    file = ctx.meta[:CurrentFile]
                    lines = Utilities.find_block_in_file(block.code, file)
                    @docerror(ctx.doc, :doctest,
                        """
                        invalid syntax for doctest keyword arguments in $(Utilities.locrepr(file, lines))
                        Use ```jldoctest name; key1 = value1, key2 = value2

                        ```$(lang)
                        $(block.code)
                        ```
                        """)
                    return false
                end
                d[kwarg.args[1]] = Core.eval(sandbox, kwarg.args[2])
            end
        end
        ctx.meta[:LocalDocTestArguments] = d

        for expr in [get(ctx.meta, :DocTestSetup, []); get(ctx.meta[:LocalDocTestArguments], :setup, [])]
            Meta.isexpr(expr, :block) && (expr.head = :toplevel)
            try
                Core.eval(sandbox, expr)
            catch e
                push!(ctx.doc.internal.errors, :doctest)
                @error("could not evaluate expression from doctest setup.",
                    expression = expr, exception = e)
                return false
            end
        end
        if occursin(r"^julia> "m, block.code)
            eval_repl(block, sandbox, ctx.meta, ctx.doc, ctx.file)
        elseif occursin(r"^# output$"m, block.code)
            eval_script(block, sandbox, ctx.meta, ctx.doc, ctx.file)
        else
            file = ctx.meta[:CurrentFile]
            lines = Utilities.find_block_in_file(block.code, file)
            @docerror(ctx.doc, :doctest,
                """
                invalid doctest block in $(Utilities.locrepr(file, lines))
                Requires `julia> ` or `# output`

                ```$(lang)
                $(block.code)
                ```
                """)
        end
        delete!(ctx.meta, :LocalDocTestArguments)
    end
    false
end
doctest(ctx::DocTestContext, block) = true

# Doctest evaluation.

mutable struct Result
    block  :: MutableMD2CodeBlock # The entire code block that is being tested.
    input  :: String # Part of `block.code` representing the current input.
    output :: String # Part of `block.code` representing the current expected output.
    file   :: String # File in which the doctest is written. Either `.md` or `.jl`.
    value  :: Any        # The value returned when evaluating `input`.
    hide   :: Bool       # Semi-colon suppressing the output?
    stdout :: IOBuffer   # Redirected stdout/stderr gets sent here.
    bt     :: Vector     # Backtrace when an error is thrown.

    function Result(block, input, output, file)
        new(block, input, rstrip(output, '\n'), file, nothing, false, IOBuffer())
    end
end

function eval_repl(block, sandbox, meta::Dict, doc::Documents.Document, page)
    for (input, output) in repl_splitter(block.code)
        result = Result(block, input, output, meta[:CurrentFile])
        for (ex, str) in Utilities.parseblock(input, doc, page; keywords = false, raise=false)
            # Input containing a semi-colon gets suppressed in the final output.
            result.hide = REPL.ends_with_semicolon(str)
            # Use the REPL softscope for REPL jldoctests,
            # see https://github.com/JuliaLang/julia/pull/33864
            ex = REPL.softscope!(ex)
            c = IOCapture.capture(rethrow = InterruptException) do
                Core.eval(sandbox, ex)
            end
            Core.eval(sandbox, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
            result.value = c.value
            print(result.stdout, c.output)
            if c.error
                result.bt = c.backtrace
            end
            # don't evaluate further if there is a parse error
            isa(ex, Expr) && ex.head === :error && break
        end
        checkresult(sandbox, result, meta, doc)
    end
end

function eval_script(block, sandbox, meta::Dict, doc::Documents.Document, page)
    # TODO: decide whether to keep `# output` syntax for this. It's a bit ugly.
    #       Maybe use double blank lines, i.e.
    #
    #
    #       to mark `input`/`output` separation.
    input, output = split(block.code, r"^# output$"m, limit = 2)
    input  = rstrip(input, '\n')
    output = lstrip(output, '\n')
    result = Result(block, input, output, meta[:CurrentFile])
    for (ex, str) in Utilities.parseblock(input, doc, page; keywords = false, raise=false)
        c = IOCapture.capture(rethrow = InterruptException) do
            Core.eval(sandbox, ex)
        end
        result.value = c.value
        print(result.stdout, c.output)
        if c.error
            result.bt = c.backtrace
            break
        end
    end
    checkresult(sandbox, result, meta, doc)
end

function filter_doctests(strings::NTuple{2, AbstractString},
                         doc::Documents.Document, meta::Dict)
    meta_block_filters = get(Vector{Any}, meta, :DocTestFilters)
    meta_block_filters === nothing && (meta_block_filters = [])
    doctest_local_filters = get(meta[:LocalDocTestArguments], :filter, [])
    for r in [doc.user.doctestfilters; meta_block_filters; doctest_local_filters]
        if all(occursin.((r,), strings))
            strings = replace.(strings, (r => "",))
        end
    end
    return strings
end

# Regex used here to replace gensym'd module names could probably use improvements.
function checkresult(sandbox::Module, result::Result, meta::Dict, doc::Documents.Document)
    sandbox_name = nameof(sandbox)
    mod_regex = Regex("(Main\\.)?(Symbol\\(\"$(sandbox_name)\"\\)|$(sandbox_name))[,.]")
    mod_regex_nodot = Regex(("(Main\\.)?$(sandbox_name)"))
    outio = IOContext(result.stdout, :module => sandbox)
    if isdefined(result, :bt) # An error was thrown and we have a backtrace.
        # To avoid dealing with path/line number issues in backtraces we use `[...]` to
        # mark ignored output from an error message. Only the text prior to it is used to
        # test for doctest success/failure.
        head = replace(split(result.output, "\n[...]"; limit = 2)[1], mod_regex  => "")
        head = replace(head, mod_regex_nodot => "Main")
        str  = replace(error_to_string(outio, result.value, result.bt), mod_regex => "")
        str  = replace(str, mod_regex_nodot => "Main")

        str, head = filter_doctests((str, head), doc, meta)
        # Since checking for the prefix of an error won't catch the empty case we need
        # to check that manually with `isempty`.
        if isempty(head) || !startswith(str, head)
            if doc.user.doctest === :fix
                fix_doctest(result, str, doc)
            else
                report(result, str, doc)
                @debug "Doctest metadata" meta
                push!(doc.internal.errors, :doctest)
            end
        end
    else
        value = result.hide ? nothing : result.value # `;` hides output.
        output = replace(rstrip(sanitise(IOBuffer(result.output))), mod_regex => "")
        str = replace(result_to_string(outio, value), mod_regex => "")
        # Replace a standalone module name with `Main`.
        str = rstrip(replace(str, mod_regex_nodot => "Main"))
        filteredstr, filteredoutput = filter_doctests((str, output), doc, meta)
        if filteredstr != filteredoutput
            if doc.user.doctest === :fix
                fix_doctest(result, str, doc)
            else
                report(result, str, doc)
                @debug "Doctest metadata" meta
                push!(doc.internal.errors, :doctest)
            end
        end
    end
    return nothing
end

# Display doctesting results.

function result_to_string(buf, value)
    rng = default_rng() # Avoids hard to replicate global random state mutation in `show`
    value === nothing || Base.invokelatest(show, IOContext(buf, :limit => true), MIME"text/plain"(), value)
    copyto!(default_rng(), rng)
    return sanitise(buf)
end

function error_to_string(buf, er, bt)
    # Remove unimportant backtrace info.
    bt = remove_common_backtrace(bt, backtrace())
    # Remove everything below the last eval call (which should be the one in IOCapture.capture)
    index = findlast(ptr -> Base.ip_matches_func(ptr, :eval), bt)
    bt = (index === nothing) ? bt : bt[1:(index - 1)]
    # Print a REPL-like error message.
    print(buf, "ERROR: ")
    Base.invokelatest(showerror, buf, er, bt)
    return sanitise(buf)
end

function remove_common_backtrace(bt, reference_bt)
    cutoff = nothing
    # We'll start from the top of the backtrace (end of the array) and go down, checking
    # if the backtraces agree
    for ridx in 1:length(bt)
        # Cancel search if we run out the reference BT or find a non-matching one frames:
        if ridx > length(reference_bt) || bt[length(bt) - ridx + 1] != reference_bt[length(reference_bt) - ridx + 1]
            cutoff = length(bt) - ridx + 1
            break
        end
    end
    # It's possible that the loop does not find anything, i.e. that all BT elements are in
    # the reference_BT too. In that case we'll just return an empty BT.
    bt[1:(cutoff === nothing ? 0 : cutoff)]
end

# Strip trailing whitespace from each line and return resulting string
function sanitise(buffer)
    out = IOBuffer()
    for line in eachline(seekstart(Base.unwrapcontext(buffer)[1]))
        println(out, rstrip(line))
    end
    return rstrip(String(take!(out)), '\n')
end

import .Utilities.TextDiff

function report(result::Result, str, doc::Documents.Document)
    diff = TextDiff.Diff{TextDiff.Words}(result.output, rstrip(str))
    lines = Utilities.find_block_in_file(result.block.code, result.file)
    line = lines === nothing ? nothing : first(lines)
    @error("""
        doctest failure in $(Utilities.locrepr(result.file, lines))

        ```$(result.block.language)
        $(result.block.code)
        ```

        Subexpression:

        $(result.input)

        Evaluated output:

        $(rstrip(str))

        Expected output:

        $(result.output)

        """, diff, _file=result.file, _line=line)
end

function fix_doctest(result::Result, str, doc::Documents.Document)
    code = result.block.code
    filename = Base.find_source_file(result.file)
    # read the file containing the code block
    content = read(filename, String)
    # output stream
    io = IOBuffer(sizehint = sizeof(content))
    # first look for the entire code block
    # make a regex of the code that matches leading whitespace
    rcode = "(\\h*)" * replace(Utilities.regex_escape(code), "\\n" => "\\n\\h*")
    r = Regex(rcode)
    codeidx = findfirst(r, content)
    if codeidx === nothing
        @warn "could not find code block in source file"
        return
    end
    # use the capture group to identify indentation
    indent = match(r, content).captures[1]
    # write everything up until the code block
    write(io, content[1:prevind(content, first(codeidx))])
    # next look for the particular input string in the given code block
    # make a regex of the input that matches leading whitespace (for multiline input)
    rinput = "\\h*" * replace(Utilities.regex_escape(result.input), "\\n" => "\\n\\h*")
    r = Regex(rinput)
    inputidx = findfirst(r, code)
    if inputidx === nothing
        @warn "could not find input line in code block"
        return
    end
    # construct the new code-snippet (without indent)
    # first part: everything up until the last index of the input string
    newcode = code[1:last(inputidx)]
    isempty(result.output) && (newcode *= '\n') # issue #772
    # second part: the rest, with the old output replaced with the new one
    if result.output == ""
        # This works around a regression in Julia 1.5.0 (https://github.com/JuliaLang/julia/issues/36953)
        # Technically, it is only necessary if VERSION >= v"1.5.0-DEV.826"
        newcode *= str
        newcode *= code[nextind(code, last(inputidx)):end]
    else
        newcode *= replace(code[nextind(code, last(inputidx)):end], result.output => str, count = 1)
    end
    # replace internal code block with the non-indented new code, needed if we come back
    # looking to replace output in the same code block later
    result.block.code = newcode
    # write the new code snippet to the stream, with indent
    newcode = replace(newcode, r"^(.+)$"m => Base.SubstitutionString(indent * "\\1"))
    write(io, newcode)
    # write rest of the file
    write(io, content[nextind(content, last(codeidx)):end])
    # write to file
    write(filename, seekstart(io))
    return
end

# REPL doctest splitter.

const PROMPT_REGEX = r"^julia> (.*)$"
const SOURCE_REGEX = r"^       (.*)$"

function repl_splitter(code)
    lines  = split(string(code, "\n"), '\n')
    input  = String[]
    output = String[]
    buffer = IOBuffer() # temporary buffer for doctest inputs and outputs
    found_first_prompt = false
    while !isempty(lines)
        line = popfirst!(lines)
        prompt = match(PROMPT_REGEX, line)
        # We allow comments before the first julia> prompt
        !found_first_prompt && startswith(line, '#') && continue
        if prompt === nothing
            source = match(SOURCE_REGEX, line)
            if source === nothing
                savebuffer!(input, buffer)
                println(buffer, line)
                takeuntil!(PROMPT_REGEX, buffer, lines)
            else
                println(buffer, source[1])
            end
        else
            found_first_prompt = true
            savebuffer!(output, buffer)
            println(buffer, prompt[1])
        end
    end
    savebuffer!(output, buffer)
    zip(input, output)
end

function savebuffer!(out, buf)
    n = bytesavailable(seekstart(buf))
    n > 0 ? push!(out, rstrip(String(take!(buf)))) : out
end

function takeuntil!(r, buf, lines)
    while !isempty(lines)
        line = lines[1]
        if !occursin(r, line)
            println(buf, popfirst!(lines))
        else
            break
        end
    end
end

end
