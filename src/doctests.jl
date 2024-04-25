# Provides the [`doctest`](@ref) function that makes sure that the `jldoctest` code blocks
# in the documents and docstrings run and are up to date.

# Julia code block testing.
# -------------------------

mutable struct MutableMD2CodeBlock
    language :: String
    code :: String
end
MutableMD2CodeBlock(block :: MarkdownAST.CodeBlock) = MutableMD2CodeBlock(block.info, block.code)

struct DocTestContext
    file :: String
    doc :: Documenter.Document
    meta :: Dict{Symbol, Any}
    DocTestContext(file::String, doc::Documenter.Document) = new(file, doc, Dict())
end

"""
$(SIGNATURES)

Traverses the pages and modules in the documenter blueprint, searching and
executing doctests.

Will abort the document generation when an error is thrown. Use `doctest = false`
keyword in [`Documenter.makedocs`](@ref) to disable doctesting.
"""
function _doctest(blueprint::Documenter.DocumentBlueprint, doc::Documenter.Document)
    @debug "Running doctests."
    # find all the doctest blocks in the pages
    for (src, page) in blueprint.pages
        if Documenter.is_draft(doc, page)
            @debug "Skipping page-doctests in draft mode" page.source
            continue
        end
        _doctest(page, doc)
    end

    if Documenter.is_draft(doc)
        @debug "Skipping docstring-doctests in draft mode"
        return
    end

    # find all the doctest block in all the docstrings (within specified modules)
    for mod in blueprint.modules
        for (binding, multidoc) in DocSystem.getmeta(mod)
            for signature in multidoc.order
                _doctest(multidoc.docs[signature], mod, doc)
            end
        end
    end
end

mutable struct MutablePrefix
    content :: String
    MutablePrefix() = new("")
end

function _doctest(page::Documenter.Page, doc::Documenter.Document)
    ctx = DocTestContext(page.source, doc) # FIXME
    ctx.meta[:CurrentFile] = page.source
    _doctest(ctx, page.mdast)
end

function _doctest(docstr::Docs.DocStr, mod::Module, doc::Documenter.Document)
    md::Markdown.MD = DocSystem.parsedoc(docstr)
    mdast = try
        convert(MarkdownAST.Node, md)
    catch err
        @error """
            MarkdownAST conversion error for a docstring in $(mod).
            This is a bug — please report this on the Documenter issue tracker
            """ docstr.data
        rethrow(err)
    end
    ctx = DocTestContext(docstr.data[:path], doc)
    merge!(ctx.meta, DocMeta.getdocmeta(mod))
    ctx.meta[:CurrentFile] = get(docstr.data, :path, nothing)
    _doctest(ctx, mdast)
end

function parse_metablock(ctx::DocTestContext, block::MarkdownAST.CodeBlock)
    @assert startswith(block.info, "@meta")
    meta = Dict{Symbol, Any}()
    for (ex, str) in Documenter.parseblock(block.code, ctx.doc, ctx.file)
        if Documenter.isassign(ex)
            try
                meta[ex.args[1]] = Core.eval(Main, ex.args[2])
            catch err
                @docerror(ctx.doc, :meta_block, "Failed to evaluate `$(strip(str))` in `@meta` block.", exception = err)
            end
        end
    end
    return meta
end

function _doctest(ctx::DocTestContext, mdast::MarkdownAST.Node)
    for node in AbstractTrees.Leaves(mdast)
        isa(node.element, MarkdownAST.CodeBlock) || continue
        if startswith(node.element.info, "jldoctest")
            _doctest(ctx, node.element)
        elseif startswith(node.element.info, "@meta")
            merge!(ctx.meta, parse_metablock(ctx, node.element))
        end
    end
end

function _doctest(ctx::DocTestContext, block_immutable::MarkdownAST.CodeBlock)
    lang = block_immutable.info
    if startswith(lang, "jldoctest")
        # Define new module or reuse an old one from this page if we have a named doctest.
        name = match(r"jldoctest[ ]?(.*)$", split(lang, ';', limit = 2)[1])[1]
        sandbox = Documenter.get_sandbox_module!(ctx.meta, "doctest", name)

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
                lines = Documenter.find_block_in_file(block.code, file)
                @docerror(ctx.doc, :doctest,
                    """
                    Unable to parse doctest keyword arguments in $(Documenter.locrepr(file, lines))
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
                    lines = Documenter.find_block_in_file(block.code, file)
                    @docerror(ctx.doc, :doctest,
                        """
                        invalid syntax for doctest keyword arguments in $(Documenter.locrepr(file, lines))
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
        elseif occursin(r"^# output\s+$"m, block.code)
            file = ctx.meta[:CurrentFile]
            lines = Documenter.find_block_in_file(block.code, file)
            @docerror(ctx.doc, :doctest,
                """
                invalid doctest block in $(Documenter.locrepr(file, lines))
                Requires `# output` without trailing whitespace

                ```$(lang)
                $(block.code)
                ```
                """)
        else
            file = ctx.meta[:CurrentFile]
            lines = Documenter.find_block_in_file(block.code, file)
            @docerror(ctx.doc, :doctest,
                """
                invalid doctest block in $(Documenter.locrepr(file, lines))
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
_doctest(ctx::DocTestContext, block) = true

# Doctest evaluation.

mutable struct Result
    block      :: MutableMD2CodeBlock # The entire code block that is being tested.
    raw_input  :: String # Part of `block.code` representing the current input.
    input      :: String # Part of `block.code` representing the current input
                         # without leading repl prompts and spaces.
    output     :: String # Part of `block.code` representing the current expected output.
    file       :: String # File in which the doctest is written. Either `.md` or `.jl`.
    value      :: Any        # The value returned when evaluating `input`.
    hide       :: Bool       # Semi-colon suppressing the output?
    stdout     :: IOBuffer   # Redirected stdout/stderr gets sent here.
    bt         :: Vector     # Backtrace when an error is thrown.

    function Result(block, input, output, file)
        new(block, input, input, rstrip(output, '\n'), file, nothing, false, IOBuffer())
    end
    function Result(block, raw_input, input, output, file)
        new(block, raw_input, input, rstrip(output, '\n'), file, nothing, false, IOBuffer())
    end
end


function eval_repl(block, sandbox, meta::Dict, doc::Documenter.Document, page)
    src_lines = Documenter.find_block_in_file(block.code, meta[:CurrentFile])
    (prefix, split) = repl_splitter(block.code)
    for (raw_input, input, output) in split
        result = Result(block, raw_input, input, output, meta[:CurrentFile])
        for (ex, str) in Documenter.parseblock(input, doc, page; keywords = false, raise=false)
            # Input containing a semi-colon gets suppressed in the final output.
            @debug "Evaluating REPL line from doctest at $(Documenter.locrepr(result.file, src_lines))" unparsed_string = str parsed_expression = ex
            result.hide = REPL.ends_with_semicolon(str)
            # Use the REPL softscope for REPL jldoctests,
            # see https://github.com/JuliaLang/julia/pull/33864
            ex = REPL.softscope(ex)
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
        checkresult(sandbox, result, meta, doc; prefix)
    end
end

function eval_script(block, sandbox, meta::Dict, doc::Documenter.Document, page)
    # TODO: decide whether to keep `# output` syntax for this. It's a bit ugly.
    #       Maybe use double blank lines, i.e.
    #
    #
    #       to mark `input`/`output` separation.
    input, output = split(block.code, r"^# output$"m, limit = 2)
    input  = rstrip(input, '\n')
    output = lstrip(output, '\n')
    result = Result(block, input, output, meta[:CurrentFile])
    for (ex, str) in Documenter.parseblock(input, doc, page; keywords = false, raise=false)
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

function filter_doctests(filters, strings)
    for rs in filters
        # If a doctest filter is just a string or regex, everything that matches gets
        # removed before comparing the inputs and outputs of a doctest. However, it can
        # also be a regex => substitution pair in which case the match gets replaced by
        # the substitution string.
        r, s = if isa(rs, Pair{Regex,T} where T <: AbstractString)
            rs
        elseif isa(rs, Regex) || isa(rs, AbstractString)
            rs, ""
        else
            error("Invalid doctest filter:\n$rs :: $(typeof(rs))")
        end
        if all(occursin.((r,), strings))
            strings = replace.(strings, (r => s,))
        end
    end
    return strings
end

# Regex used here to replace gensym'd module names could probably use improvements.
function checkresult(sandbox::Module, result::Result, meta::Dict, doc::Documenter.Document; prefix::MutablePrefix=MutablePrefix())
    sandbox_name = nameof(sandbox)
    mod_regex = Regex("(Main\\.)?(Symbol\\(\"$(sandbox_name)\"\\)|$(sandbox_name))[,.]")
    mod_regex_nodot = Regex(("(Main\\.)?$(sandbox_name)"))
    outio = IOContext(result.stdout, :module => sandbox)
    filters = collect_doctest_filters(doc, meta)
    if isdefined(result, :bt) # An error was thrown and we have a backtrace.
        # To avoid dealing with path/line number issues in backtraces we use `[...]` to
        # mark ignored output from an error message. Only the text prior to it is used to
        # test for doctest success/failure.
        head = replace(split(result.output, "\n[...]"; limit = 2)[1], mod_regex  => "")
        head = replace(head, mod_regex_nodot => "Main")
        str  = error_to_string(outio, result.value, result.bt)
        str  = replace(str, mod_regex => "")
        str  = replace(str, mod_regex_nodot => "Main")
        filteredstr, filteredhead = filter_doctests(filters, (str, head))
        @debug debug_report(
            result=result, filters = filters, expected_filtered = filteredhead,
            evaluated = rstrip(str), evaluated_filtered = filteredstr
        )
        # Since checking for the prefix of an error won't catch the empty case we need
        # to check that manually with `isempty`.
        # In the doc.user.doctest === :fix we need actual equality of
        # filteredstr and filteredhead, otherwise this needs to get repaired.
        if isempty(head) || !startswith(filteredstr, filteredhead) || 
                (doc.user.doctest === :fix && filteredstr != filteredhead)
            if doc.user.doctest === :fix
                fix_doctest(result, str, doc; prefix)
            else
                report(result, str, doc)
                @debug "Doctest metadata" meta
                push!(doc.internal.errors, :doctest)
            end
        else
            # Prefix was not modified, unless output was different.
            prefix.content *= result.raw_input*"\n"
            if str != ""
                prefix.content *= str * "\n"
            end
            prefix.content *= "\n"
        end
    else
        value = result.hide ? nothing : result.value # `;` hides output.
        output = replace(rstrip(sanitise(IOBuffer(result.output))), mod_regex => "")
        str = replace(result_to_string(outio, value), mod_regex => "")
        # Replace a standalone module name with `Main`.
        str = rstrip(replace(str, mod_regex_nodot => "Main"))
        filteredstr, filteredoutput = filter_doctests(filters, (str, output))
        @debug debug_report(
            result=result, filters = filters, expected_filtered = filteredoutput,
            evaluated = rstrip(str), evaluated_filtered = filteredstr
        )
        if filteredstr != filteredoutput
            if doc.user.doctest === :fix
                fix_doctest(result, str, doc; prefix)
            else
                report(result, str, doc)
                @debug "Doctest metadata" meta
                push!(doc.internal.errors, :doctest)
            end
        else
            # Prefix was not modified, unless output was different.
            prefix.content *= result.raw_input*"\n"
            if str != ""
                prefix.content *= str * "\n"
            end
            prefix.content *= "\n"
        end
    end
    return nothing
end

function debug_report(; result, expected_filtered, evaluated, evaluated_filtered, filters)
    lines = Documenter.find_block_in_file(result.block.code, result.file)
    r = """
    Verifying doctest at $(Documenter.locrepr(result.file, lines))

    ```$(result.block.language)
    $(result.block.code)
    ```

    Subexpression:

    $(result.input)

    Evaluated output:

    $(evaluated)

    Expected output:

    $(result.output)
    """
    if !isempty(filters)
        r *= "\n"
        r *= (length(filters) == 1) ? "1 doctest filter was applied:\n\n" :
            "$(length(filters)) doctest filters were applied:\n\n"
        for rs in filters
            r *= "  $rs\n"
        end
        r *= """

        Evaluated output (filtered):

        $(evaluated_filtered)

        Expected output (filtered):

        $(expected_filtered)
        """
    end
    return r
end

function collect_doctest_filters(doc::Documenter.Document, meta::Dict)
    meta_block_filters = get(Vector{Any}, meta, :DocTestFilters)
    meta_block_filters === nothing && (meta_block_filters = [])
    doctest_local_filters = get(meta[:LocalDocTestArguments], :filter, [])
    [doc.user.doctestfilters; meta_block_filters; doctest_local_filters]
end

# Display doctesting results.

function result_to_string(buf, value)
    value === nothing || Base.invokelatest(show, IOContext(buf, :limit => true), MIME"text/plain"(), value)
    return sanitise(buf)
end

function error_to_string(buf, er, bt)
    # Remove unimportant backtrace info.
    bt = Documenter.remove_common_backtrace(bt, backtrace())
    # Remove everything below the last eval call (which should be the one in IOCapture.capture)
    index = findlast(ptr -> Base.ip_matches_func(ptr, :eval), bt)
    bt = (index === nothing) ? bt : bt[1:(index - 1)]
    # Print a REPL-like error message.
    print(buf, "ERROR: ")
    Base.invokelatest(showerror, buf, er, bt)
    return sanitise(buf)
end

# Strip trailing whitespace from each line and return resulting string
function sanitise(buffer)
    out = IOBuffer()
    for line in eachline(seekstart(Base.unwrapcontext(buffer)[1]))
        println(out, rstrip(line))
    end
    return rstrip(String(take!(out)), '\n')
end

import .Documenter.TextDiff

function report(result::Result, str, doc::Documenter.Document)
    diff = TextDiff.Diff{TextDiff.Words}(result.output, rstrip(str))
    lines = Documenter.find_block_in_file(result.block.code, result.file)
    line = lines === nothing ? nothing : first(lines)
    @error("""
        doctest failure in $(Documenter.locrepr(result.file, lines))

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

function fix_doctest(result::Result, str, doc::Documenter.Document; prefix::MutablePrefix=MutablePrefix())
    code = result.block.code
    filename = Base.find_source_file(result.file)
    # read the file containing the code block
    content = read(filename, String)
    # output stream
    io = IOBuffer(sizehint = sizeof(content))
    # first look for the entire code block
    # make a regex of the code that matches leading whitespace
    rcode = "(\\h*)" * replace(Documenter.regex_escape(code), "\\n" => "\\n\\h*")
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
    composed = prefix.content * result.raw_input
    rinput = replace(Documenter.regex_escape(composed), "\\n" => "\\n\\h*")
    r = Regex(rinput)
    inputidx = findfirst(r, code)
    if inputidx === nothing
        @warn "could not find input line in code block"
        return
    end
    # construct the new code-snippet (without indent)
    # first part: everything up until the last index of the input string
    newcode = code[1:last(inputidx)]
    prefix.content = newcode * "\n"
    if str != ""
        prefix.content *= str * "\n"
    end
    prefix.content *= "\n"
    isempty(result.output) && (newcode *= '\n') # issue #772
    # second part: the rest, with the old output replaced with the new one
    if result.output == ""
        # This works around a regression in Julia 1.5.0 (https://github.com/JuliaLang/julia/issues/36953)
        # Technically, it is only necessary if VERSION >= v"1.5.0-DEV.826"
        newcode *= str
        newcode *= code[nextind(code, last(inputidx)):end]
    else
        if str == ""
            newcode *= replace(code[nextind(code, last(inputidx)):end], result.output * "\n" => str, count = 1)
        else
            newcode *= replace(code[nextind(code, last(inputidx)):end], result.output => str, count = 1)
        end
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
    raw_inputs = String[]
    output = String[]
    prefix = MutablePrefix()
    buffer = IOBuffer() # temporary buffer for doctest inputs and outputs
    raw_input_buffer = IOBuffer()
    found_first_prompt = false
    while !isempty(lines)
        line = popfirst!(lines)
        prompt = match(PROMPT_REGEX, line)
        # We allow comments before the first julia> prompt
        if !found_first_prompt && startswith(line, '#')
            prefix.content *= line * "\n"
            continue
        end
        if prompt === nothing
            source = match(SOURCE_REGEX, line)
            if source === nothing
                savebuffer!(input, buffer)
                savebuffer!(raw_inputs, raw_input_buffer)
                println(buffer, line)
                takeuntil!(PROMPT_REGEX, buffer, lines)
            else
                println(buffer, source[1])
                println(raw_input_buffer, line)
            end
        else
            found_first_prompt = true
            savebuffer!(output, buffer)
            println(buffer, prompt[1])
            println(raw_input_buffer, line)
        end
    end
    savebuffer!(output, buffer)
    return prefix, zip(raw_inputs, input, output)
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
