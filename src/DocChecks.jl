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

using Compat

# Missing docstrings.
# -------------------

"""
Checks that a [`Documents.Document`](@ref) contains all available docstrings that are
defined in the `modules` keyword passed to [`Documenter.makedocs`](@ref).

Prints out the name of each object that has not had its docs spliced into the document.
"""
function missingdocs(doc::Documents.Document)
    bindings = allbindings(doc.user.modules)
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
        Utilities.warn(takebuf_string(b))
    end
end

function allbindings(mods)
    out = Dict{Utilities.Binding, Set{Type}}()
    for m in mods
        allbindings(m, out)
    end
    out
end

function allbindings(mod::Module, out = Dict{Utilities.Binding, Set{Type}}())
    for (obj, doc) in meta(mod)
        isa(obj, ObjectIdDict) && continue
        out[Utilities.Binding(mod, nameof(obj))] = Set(sigs(doc))
    end
    out
end

if isdefined(Base.Docs, :META′) # 0.4
    meta(m) = isdefined(m, Docs.META′) ? Docs.meta(m) : ObjectIdDict()
else # 0.5
    meta(m) = Docs.meta(m)
end

if isleaftype(Function) # 0.4
    nameof(x::Function) = x.env.name
else # 0.5
    nameof(x::Function) = typeof(x).name.mt.name
end
nameof(b::Base.Docs.Binding) = b.var
nameof(x::DataType)          = x.name.name
nameof(m::Module)            = module_name(m)

if isdefined(Base.Docs, :MultiDoc) # 0.5
    sigs(x::Base.Docs.MultiDoc) = x.order
else # 0.4
    sigs(x::Base.Docs.FuncDoc) = x.order
    sigs(x::Base.Docs.TypeDoc) = x.order
end
sigs(::Any) = Type[Union{}]

# Julia code block testing.
# -------------------------

"""
Traverses the document tree and tries to run each Julia code block encountered. Will abort
the document generation when an error is thrown. Use `doctest = false` keyword in
[`Documenter.makedocs`](@ref) to disable doctesting.
"""
function doctest(doc::Documents.Document)
    if doc.user.doctest
        for (src, page) in doc.internal.pages
            empty!(page.globals.meta)
            for element in page.elements
                Walkers.walk(page.globals.meta, page.mapping[element]) do block
                    doctest(block, page.globals.meta, doc, page)
                end
            end
        end
    else
        Utilities.warn("Skipped doctesting.")
    end
end

function doctest(block::Markdown.Code, meta::Dict, doc::Documents.Document, page)
    if block.language == "julia" || block.language == "jlcon"
        code, sandbox = block.code, Module(:Main)
        haskey(meta, :DocTestSetup) && eval(sandbox, meta[:DocTestSetup])
        ismatch(r"^julia> "m, code)   ? eval_repl(code, sandbox, doc, page)   :
        ismatch(r"^# output$"m, code) ? eval_script(code, sandbox, doc, page) : nothing
    end
    false
end
doctest(block, meta::Dict, doc::Documents.Document, page) = true

# Doctest evaluation.

type Result
    code   :: Compat.String # The entire code block that is being tested.
    input  :: Compat.String # Part of `code` representing the current input.
    output :: Compat.String # Part of `code` representing the current expected output.
    value  :: Any        # The value returned when evaluating `input`.
    hide   :: Bool       # Semi-colon suppressing the output?
    stdout :: IOBuffer   # Redirected STDOUT/STDERR gets sent here.
    bt     :: Vector     # Backtrace when an error is thrown.

    function Result(code, input, output)
        new(code, input, rstrip(output, '\n'), nothing, false, IOBuffer())
    end
end

function eval_repl(code, sandbox, doc::Documents.Document, page)
    for (input, output) in repl_splitter(code)
        result = Result(code, input, output)
        for (ex, str) in Utilities.parseblock(input, doc, page)
            # Input containing a semi-colon gets suppressed in the final output.
            result.hide = ends_with_semicolon(str)
            (value, success, backtrace, text) = Utilities.withoutput() do
                eval(sandbox, ex)
            end
            result.value = value
            print(result.stdout, text)
            if success
                # Redefine the magic `ans` binding available in the REPL.
                eval(sandbox, :(ans = $(result.value)))
            else
                result.bt = backtrace
            end
        end
        checkresult(result)
    end
end

function eval_script(code, sandbox, doc::Documents.Document, page)
    # TODO: decide whether to keep `# output` syntax for this. It's a bit ugly.
    #       Maybe use double blank lines, i.e.
    #
    #
    #       to mark `input`/`output` separation.
    input, output = split(code, "\n# output\n", limit = 2)
    result = Result(code, "", output)
    for (ex, str) in Utilities.parseblock(input, doc, page)
        (value, success, backtrace, text) = Utilities.withoutput() do
            eval(sandbox, ex)
        end
        result.value = value
        print(result.stdout, text)
        if !success
            result.bt = backtrace
            break
        end
    end
    checkresult(result)
end

function checkresult(result::Result)
    if isdefined(result, :bt) # An error was thrown and we have a backtrace.
        # To avoid dealing with path/line number issues in backtraces we use `[...]` to
        # mark ignored output from an error message. Only the text prior to it is used to
        # test for doctest success/failure.
        head = split(result.output, "\n[...]"; limit = 2)[1]
        str  = error_to_string(result.stdout, result.value, result.bt)
        startswith(str, head) || report(result, str)
    else
        value = result.hide ? nothing : result.value # `;` hides output.
        str   = result_to_string(result.stdout, value)
        strip(str) == strip(sanitise(IOBuffer(result.output))) || report(result, str)
    end
end

# from base/REPL.jl
function ends_with_semicolon(line)
    match = rsearch(line, ';')
    if match != 0
        for c in line[(match+1):end]
            isspace(c) || return c == '#'
        end
        return true
    end
    return false
end

# Display doctesting results.

function result_to_string(buf, value)
    dis = text_display(buf)
    value === nothing || display(dis, value)
    sanitise(buf)
end

if VERSION < v"0.5.0-dev+4305"
    text_display(buf) = TextDisplay(buf)
else
    text_display(buf) = TextDisplay(IOContext(buf, multiline = true, limit = true))
end

function error_to_string(buf, er, bt)
    print(buf, "ERROR: ")
    showerror(buf, er, bt)
    sanitise(buf)
end

# Strip trailing whitespace and remove terminal colors.
function sanitise(buffer)
    out = IOBuffer()
    for line in eachline(seekstart(buffer))
        println(out, rstrip(line))
    end
    remove_term_colors(rstrip(takebuf_string(out), '\n'))
end

function report(result::Result, str)
    buffer = IOBuffer()
    println(buffer, "Test error in the following code block:")
    print_indented(buffer, result.code; indent = 8)
    if result.input != ""
        print_indented(buffer, "in expression:")
        print_indented(buffer, result.input; indent = 8)
    end
    print_indented(buffer, "expected:")
    print_indented(buffer, result.output; indent = 8)
    print_indented(buffer, "returned:")
    print_indented(buffer, rstrip(str); indent = 8) # Drops trailing whitespace.
    Utilities.warn(takebuf_string(buffer))
end

function print_indented(buffer::IO, str::AbstractString; indent = 4)
    println(buffer)
    for line in split(str, '\n')
        println(buffer, " "^indent, line)
    end
end

# Remove terminal colors.

const TERM_COLOR_REGEX =
    let _1 = map(escape_string, values(Base.text_colors)),
        _2 = map(each -> replace(each, "[", "\\["), _1)
        Regex(string("(", join(_2, "|"), ")"))
    end

remove_term_colors(s) = replace(s, TERM_COLOR_REGEX, "")

# REPL doctest splitter.

const PROMPT_REGEX = r"^julia> (.*)$"
const SOURCE_REGEX = r"^       (.*)$"

function repl_splitter(code)
    lines  = split(code, '\n')
    input  = Compat.String[]
    output = Compat.String[]
    buffer = IOBuffer()
    while !isempty(lines)
        line = shift!(lines)
        # REPL code blocks may contain leading lines with comments. Drop them.
        # TODO: handle multiline comments?
        startswith(line, '#') && continue
        prompt = Utilities.nullmatch(PROMPT_REGEX, line)
        if isnull(prompt)
            source = Utilities.nullmatch(SOURCE_REGEX, line)
            if isnull(source)
                savebuffer!(input, buffer)
                println(buffer, line)
                takeuntil!(PROMPT_REGEX, buffer, lines)
            else
                println(buffer, Utilities.getmatch(source, 1))
            end
        else
            savebuffer!(output, buffer)
            println(buffer, Utilities.getmatch(prompt, 1))
        end
    end
    savebuffer!(output, buffer)
    zip(input, output)
end

function savebuffer!(out, buf)
    n = nb_available(seekstart(buf))
    n > 0 ? push!(out, rstrip(takebuf_string(buf))) : out
end

function takeuntil!(r, buf, lines)
    while !isempty(lines)
        line = lines[1]
        if isnull(Utilities.nullmatch(r, line))
            println(buf, shift!(lines))
        else
            break
        end
    end
end

end
