"""
Provides two functions, [`missingdocs`](@ref) and [`doctest`](@ref), for checking docs.
"""
module DocChecks

import ..Documenter:
    Builder,
    Documents,
    Expanders,
    Documenter,
    Utilities,
    Walkers

using Compat, DocStringExtensions

# Missing docstrings.
# -------------------

"""
$(SIGNATURES)

Checks that a [`Documents.Document`](@ref) contains all available docstrings that are
defined in the `modules` keyword passed to [`Documenter.makedocs`](@ref).

Prints out the name of each object that has not had its docs spliced into the document.
"""
function missingdocs(doc::Documents.Document)
    doc.user.checkdocs === :none && return
    println(" > checking for missing docstrings.")
    bindings = allbindings(doc.user.checkdocs, doc.user.modules)
    for object in keys(doc.internal.objects)
        if haskey(bindings, object.binding)
            signatures = bindings[object.binding]
            if object.signature ≡ Union{} || length(signatures) ≡ 1
                delete!(bindings, object.binding)
            elseif object.signature in signatures
                delete!(signatures, object.signature)
            end
        end
    end
    n = reduce(+, 0, map(length, values(bindings)))
    if n > 0
        b = IOBuffer()
        println(b, "$n docstring$(n ≡ 1 ? "" : "s") potentially missing:\n")
        for (binding, signatures) in bindings
            for sig in signatures
                println(b, "    $binding", sig ≡ Union{} ? "" : " :: $sig")
            end
        end
        push!(doc.internal.errors, :missing_docs)
        Utilities.warn(Utilities.takebuf_str(b))
    end
end

function allbindings(checkdocs::Symbol, mods)
    out = Dict{Utilities.Binding, Set{Type}}()
    for m in mods
        allbindings(checkdocs, m, out)
    end
    out
end

function allbindings(checkdocs::Symbol, mod::Module, out = Dict{Utilities.Binding, Set{Type}}())
    for (obj, doc) in meta(mod)
        isa(obj, ObjectIdDict) && continue
        name = nameof(obj)
        isexported = Base.isexported(mod, name)
        if checkdocs === :all || (isexported && checkdocs === :exports)
            out[Utilities.Binding(mod, name)] = Set(sigs(doc))
        end
    end
    out
end

meta(m) = Docs.meta(m)

nameof(x::Function)          = typeof(x).name.mt.name
nameof(b::Base.Docs.Binding) = b.var
nameof(x::DataType)          = x.name.name
nameof(m::Module)            = module_name(m)

sigs(x::Base.Docs.MultiDoc) = x.order
sigs(::Any) = Type[Union{}]

# Julia code block testing.
# -------------------------

"""
$(SIGNATURES)

Traverses the document tree and tries to run each Julia code block encountered. Will abort
the document generation when an error is thrown. Use `doctest = false` keyword in
[`Documenter.makedocs`](@ref) to disable doctesting.
"""
function doctest(doc::Documents.Document)
    if doc.user.doctest
        println(" > running doctests.")
        for (src, page) in doc.internal.pages
            empty!(page.globals.meta)
            for element in page.elements
                page.globals.meta[:CurrentFile] = page.source
                Walkers.walk(page.globals.meta, page.mapping[element]) do block
                    doctest(block, page.globals.meta, doc, page)
                end
            end
        end
    else
        Utilities.warn("Skipped doctesting.")
    end
end

function __ans__!(m::Module, value)
    isdefined(m, :__ans__!) || eval(m, :(__ans__!(value) = global ans = value))
    return eval(m, Expr(:call, () -> m.__ans__!(value)))
end

function doctest(block::Markdown.Code, meta::Dict, doc::Documents.Document, page)
    m = match(r"jldoctest[ ]?(.*)$", block.language)
    if m !== nothing
        # Define new module or reuse an old one from this page if we have a named doctest.
        name = m[1]
        sym = isempty(name) ? gensym("doctest-") : Symbol("doctest-", name)
        sandbox = get!(page.globals.meta, sym) do
            newmod = Module(sym)
            eval(newmod, :(eval(x) = Core.eval($newmod, x)))
            eval(newmod, :(eval(m, x) = Core.eval(m, x)))
            newmod
        end
        # Normalise line endings.
        code = replace(block.code, "\r\n", "\n")
        if haskey(meta, :DocTestSetup)
            expr = meta[:DocTestSetup]
            Meta.isexpr(expr, :block) && (expr.head = :toplevel)
            eval(sandbox, expr)
        end
        if ismatch(r"^julia> "m, code)
            eval_repl(code, sandbox, meta, doc, page)
            block.language = "julia-repl"
        elseif ismatch(r"^# output$"m, code)
            eval_script(code, sandbox, meta, doc, page)
            block.language = "julia"
        else
            push!(doc.internal.errors, :doctest)
            Utilities.warn(
                """
                Invalid doctest block. Requires `julia> ` or `# output` in '$(meta[:CurrentFile])'

                ```jldoctest
                $(code)
                ```
                """
            )
        end
    end
    false
end
doctest(block, meta::Dict, doc::Documents.Document, page) = true

function doctest(block::Markdown.MD, meta::Dict, doc::Documents.Document, page)
    haskey(block.meta, :path) && (meta[:CurrentFile] = block.meta[:path])
    return true
end

# Doctest evaluation.

mutable struct Result
    code   :: String # The entire code block that is being tested.
    input  :: String # Part of `code` representing the current input.
    output :: String # Part of `code` representing the current expected output.
    file   :: String # File in which the doctest is written. Either `.md` or `.jl`.
    value  :: Any        # The value returned when evaluating `input`.
    hide   :: Bool       # Semi-colon suppressing the output?
    stdout :: IOBuffer   # Redirected STDOUT/STDERR gets sent here.
    bt     :: Vector     # Backtrace when an error is thrown.

    function Result(code, input, output, file)
        new(code, input, rstrip(output, '\n'), file, nothing, false, IOBuffer())
    end
end

function eval_repl(code, sandbox, meta::Dict, doc::Documents.Document, page)
    for (input, output) in repl_splitter(code)
        result = Result(code, input, output, meta[:CurrentFile])
        for (ex, str) in Utilities.parseblock(input, doc, page; keywords = false)
            # Input containing a semi-colon gets suppressed in the final output.
            result.hide = Base.REPL.ends_with_semicolon(str)
            (value, success, backtrace, text) = Utilities.withoutput() do
                disable_color() do
                    Core.eval(sandbox, ex)
                end
            end
            result.value = value
            print(result.stdout, text)
            if success
                # Redefine the magic `ans` binding available in the REPL.
                __ans__!(sandbox, result.value)
            else
                result.bt = backtrace
            end
        end
        checkresult(sandbox, result, doc)
    end
end

function eval_script(code, sandbox, meta::Dict, doc::Documents.Document, page)
    # TODO: decide whether to keep `# output` syntax for this. It's a bit ugly.
    #       Maybe use double blank lines, i.e.
    #
    #
    #       to mark `input`/`output` separation.
    input, output = split(code, "\n# output\n", limit = 2)
    result = Result(code, "", output, meta[:CurrentFile])
    for (ex, str) in Utilities.parseblock(input, doc, page; keywords = false)
        (value, success, backtrace, text) = Utilities.withoutput() do
            Core.eval(sandbox, ex)
        end
        result.value = value
        print(result.stdout, text)
        if !success
            result.bt = backtrace
            break
        end
    end
    checkresult(sandbox, result, doc)
end

# Regex used here to replace gensym'd module names could probably use improvements.
function checkresult(sandbox::Module, result::Result, doc::Documents.Document)
    sandbox_name = module_name(sandbox)
    mod_regex = Regex("(Main\\.)?(Symbol\\(\"$(sandbox_name)\"\\)|$(sandbox_name))[,.]")
    mod_regex_nodot = Regex(("(Main\\.)?$(sandbox_name)"))
    if isdefined(result, :bt) # An error was thrown and we have a backtrace.
        # To avoid dealing with path/line number issues in backtraces we use `[...]` to
        # mark ignored output from an error message. Only the text prior to it is used to
        # test for doctest success/failure.
        head = replace(split(result.output, "\n[...]"; limit = 2)[1], mod_regex, "")
        head = replace(head, mod_regex_nodot, "Main")
        str  = replace(error_to_string(result.stdout, result.value, result.bt), mod_regex, "")
        str  = replace(str, mod_regex_nodot, "Main")
        # Since checking for the prefix of an error won't catch the empty case we need
        # to check that manually with `isempty`.
        if isempty(head) || !startswith(str, head)
            report(result, str, doc)
        end
    else
        value = result.hide ? nothing : result.value # `;` hides output.
        str = replace(result_to_string(result.stdout, value), mod_regex, "")
        # Replace a standalone module name with `Main`.
        str = replace(str, mod_regex_nodot, "Main")
        output = replace(strip(sanitise(IOBuffer(result.output))), mod_regex, "")
        strip(str) == output || report(result, str, doc)
    end
    return nothing
end

# Display doctesting results.

function result_to_string(buf, value)
    dis = text_display(buf)
    value === nothing || disable_color() do
        eval(Expr(:call, display, dis, QuoteNode(value)))
    end
    sanitise(buf)
end

text_display(buf) = TextDisplay(IOContext(buf, :limit => true))

funcsym() = CAN_INLINE[] ? :disable_color : :eval

function error_to_string(buf, er, bt)
    fs = funcsym()
    # Remove unimportant backtrace info.
    index = findlast(ptr -> Base.REPL.ip_matches_func(ptr, fs), bt)
    # Print a REPL-like error message.
    disable_color() do
        print(buf, "ERROR: ")
        showerror(buf, er, index == 0 ? bt : bt[1:(index - 1)])
    end
    sanitise(buf)
end

# Strip trailing whitespace and remove terminal colors.
function sanitise(buffer)
    out = IOBuffer()
    for line in eachline(seekstart(buffer))
        println(out, rstrip(line))
    end
    remove_term_colors(rstrip(Utilities.takebuf_str(out), '\n'))
end

import .Utilities.TextDiff

function report(result::Result, str, doc::Documents.Document)
    buffer = IOBuffer()
    println(buffer, "=====[Test Error]", "="^30)
    println(buffer)
    print_with_color(:cyan, buffer, "> File: ", result.file, "\n")
    print_with_color(:cyan, buffer, "\n> Code block:\n")
    println(buffer, "\n```jldoctest")
    println(buffer, result.code)
    println(buffer, "```")
    if !isempty(result.input)
        print_with_color(:cyan, buffer, "\n> Subexpression:\n")
        print_indented(buffer, result.input; indent = 4)
    end
    warning = Base.have_color ? "" : " (REQUIRES COLOR)"
    print_with_color(:cyan, buffer, "\n> Output Diff", warning, ":\n\n")
    diff = TextDiff.Diff{TextDiff.Words}(result.output, rstrip(str))
    Utilities.TextDiff.showdiff(buffer, diff)
    println(buffer, "\n\n", "=====[End Error]=", "="^30)
    push!(doc.internal.errors, :doctest)
    print_with_color(:normal, Utilities.takebuf_str(buffer))
end

function print_indented(buffer::IO, str::AbstractString; indent = 4)
    println(buffer)
    for line in split(str, '\n')
        println(buffer, " "^indent, line)
    end
end

# Remove terminal colors.

const TERM_COLOR_REGEX = r"\e\[[0-9;]*m"
remove_term_colors(s) = replace(s, TERM_COLOR_REGEX, "")

# REPL doctest splitter.

const PROMPT_REGEX = r"^julia> (.*)$"
const SOURCE_REGEX = r"^       (.*)$"
const ANON_FUNC_DECLARATION = r"#[0-9]+ \(generic function with [0-9]+ method(s)?\)"

function repl_splitter(code)
    lines  = split(string(code, "\n"), '\n')
    input  = String[]
    output = String[]
    buffer = IOBuffer()
    while !isempty(lines)
        line = shift!(lines)
        # REPL code blocks may contain leading lines with comments. Drop them.
        # TODO: handle multiline comments?
        # ANON_FUNC_DECLARATION deals with `x->x` -> `#1 (generic function ....)` on 0.7
        # TODO: Remove this special case and just disallow lines with comments?
        startswith(line, '#') && !ismatch(ANON_FUNC_DECLARATION, line) && continue
        prompt = match(PROMPT_REGEX, line)
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
            savebuffer!(output, buffer)
            println(buffer, prompt[1])
        end
    end
    savebuffer!(output, buffer)
    zip(input, output)
end

function savebuffer!(out, buf)
    n = nb_available(seekstart(buf))
    n > 0 ? push!(out, rstrip(Utilities.takebuf_str(buf))) : out
end

function takeuntil!(r, buf, lines)
    while !isempty(lines)
        line = lines[1]
        if !ismatch(r, line)
            println(buf, shift!(lines))
        else
            break
        end
    end
end

# Footnote checks.
# ----------------

function footnotes(doc::Documents.Document)
    println(" > checking footnote links.")
    # A mapping of footnote ids to a tuple counter of how many footnote references and
    # footnote bodies have been found.
    #
    # For all ids the final result should be `(N, 1)` where `N > 1`, i.e. one or more
    # footnote references and a single footnote body.
    footnotes = Dict{Documents.Page, Dict{String, Tuple{Int, Int}}}()
    for (src, page) in doc.internal.pages
        empty!(page.globals.meta)
        orphans = Dict{String, Tuple{Int, Int}}()
        for element in page.elements
            Walkers.walk(page.globals.meta, page.mapping[element]) do block
                footnote(block, orphans)
            end
        end
        footnotes[page] = orphans
    end
    for (page, orphans) in footnotes
        for (id, (ids, bodies)) in orphans
            # Multiple footnote bodies.
            if bodies > 1
                push!(doc.internal.errors, :footnote)
                Utilities.warn(page.source, "Footnote '$id' has $bodies bodies.")
            end
            # No footnote references for an id.
            if ids === 0
                push!(doc.internal.errors, :footnote)
                Utilities.warn(page.source, "Unused footnote named '$id'.")
            end
            # No footnote bodies for an id.
            if bodies === 0
                push!(doc.internal.errors, :footnote)
                Utilities.warn(page.source, "No footnotes found for '$id'.")
            end
        end
    end
end

function footnote(fn::Markdown.Footnote, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    if fn.text === nothing
        # Footnote references: syntax `[^1]`.
        orphans[fn.id] = (ids + 1, bodies)
        return false # No more footnotes inside footnote references.
    else
        # Footnote body: syntax `[^1]:`.
        orphans[fn.id] = (ids, bodies + 1)
        return true # Might be footnotes inside footnote bodies.
    end
end

footnote(other, orphans::Dict) = true

# Link Checks.
# ------------

hascurl() = (try; success(`curl --version`); catch err; false; end)

function linkcheck(doc::Documents.Document)
    if doc.user.linkcheck
        if hascurl()
            println(" > checking external URLs:")
            for (src, page) in doc.internal.pages
                println("   - ", src)
                for element in page.elements
                    Walkers.walk(page.globals.meta, page.mapping[element]) do block
                        linkcheck(block, doc)
                    end
                end
            end
        else
            push!(doc.internal.errors, :linkcheck)
            Utilities.warn("linkcheck requires `curl`.")
        end
    end
    return nothing
end

function linkcheck(link::Base.Markdown.Link, doc::Documents.Document)
    INDENT = " "^6

    # first, make sure we're not supposed to ignore this link
    for r in doc.user.linkcheck_ignore
        if linkcheck_ismatch(r, link.url)
            print_with_color(:normal, INDENT, "--- ", link.url, "\n")
            return false
        end
    end

    if !haskey(doc.internal.locallinks, link)
        local result
        try
            result = read(`curl -sI $(link.url)`, String)
        catch err
            push!(doc.internal.errors, :linkcheck)
            Utilities.warn("`curl -sI $(link.url)` failed:\n\n$(err)")
            return false
        end
        local STATUS_REGEX   = r"^HTTP/1.1 (\d+) (.+)$"m
        if ismatch(STATUS_REGEX, result)
            status = parse(Int, match(STATUS_REGEX, result).captures[1])
            if status < 300
                print_with_color(:green, INDENT, "$(status) ", link.url, "\n")
            elseif status < 400
                LOCATION_REGEX = r"^Location: (.+)$"m
                if ismatch(LOCATION_REGEX, result)
                    location = strip(match(LOCATION_REGEX, result).captures[1])
                    print_with_color(:yellow, INDENT, "$(status) ", link.url, "\n")
                    print_with_color(:yellow, INDENT, " -> ", location, "\n\n")
                else
                    print_with_color(:yellow, INDENT, "$(status) ", link.url, "\n")
                end
            else
                push!(doc.internal.errors, :linkcheck)
                print_with_color(:red, INDENT, "$(status) ", link.url, "\n")
            end
        else
            push!(doc.internal.errors, :linkcheck)
            Utilities.warn("invalid result returned by `curl -sI $(link.url)`:\n\n$(result)")
        end
    end
    return false
end
linkcheck(other, doc::Documents.Document) = true

linkcheck_ismatch(r::String, url) = (url == r)
linkcheck_ismatch(r::Regex, url) = ismatch(r, url)

function disable_color(func)
    orig = setcolor!(false)
    try
        func()
    finally
        setcolor!(orig)
    end
end

const CAN_INLINE = Ref(true)
function __init__()
    global setcolor! = eval(Base, :(x -> (y = have_color; global have_color = x; y)))
    CAN_INLINE[] = Base.JLOptions().can_inline == 0 ? false : true
end

end
