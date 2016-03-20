"""
Provides two functions, [`missingdocs`]({ref}) and [`doctest`]({ref}), for checking docs.
"""
module DocChecks

import ..Lapidary:

    Builder,
    Documents,
    Expanders,
    Lapidary,
    Utilities,
    Walkers

using Compat

# Missing docstrings.
# -------------------

"""
Checks that a [`Documents.Document`]({ref}) contains all available docstrings that are
defined in the `modules` keyword passed to [`Lapidary.makedocs`]({ref}).

Prints out the name of each object that has not had its docs spliced into the document.
"""
function missingdocs(doc::Documents.Document)
    bindings = allbindings(doc.user.modules)
    for object in keys(doc.internal.objects)
        if haskey(bindings, object.binding)
            signatures = bindings[object.binding]
            if object.signature == Union{} || length(signatures) == 1
                delete!(bindings, object.binding)
            end
        end
    end
    n = length(bindings)
    if n > 0
        b = IOBuffer()
        println(b, "$n docstring$(n == 1 ? "" : "s") potentially missing:\n")
        for (binding, signatures) in bindings
            println(b, "  - $binding")
        end
        Utilities.warn(takebuf_string(b))
    end
end

function allbindings(mods)
    out = Dict{Utilities.Binding, Vector{Type}}()
    for m in mods, (obj, doc) in meta(m)
        isa(obj, ObjectIdDict) && continue
        out[Utilities.Binding(m, nameof(obj))] = sigs(doc)
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
[`Lapidary.makedocs`]({ref}) to disable doctesting.
"""
function doctest(doc::Documents.Document)
    if doc.user.doctest
        for (src, page) in doc.internal.pages
            empty!(page.globals.meta)
            for element in page.elements
                Walkers.walk(page.globals.meta, page.mapping[element]) do block
                    doctest(block, page.globals.meta)
                end
            end
        end
    else
        Utilities.warn("Skipped doctesting.")
    end
end

function doctest(block::Markdown.Code, meta::Dict)
    if block.language == "julia"
        code, sandbox = block.code, Module(:Main)
        haskey(meta, :DocTestSetup) && eval(sandbox, meta[:DocTestSetup])
        ismatch(r"^julia> "m, code)   ? eval_repl(code, sandbox)   :
        ismatch(r"^# output$"m, code) ? eval_script(code, sandbox) : nothing
    end
    false
end
doctest(block, meta::Dict) = true

function eval_repl(code, sandbox)
    parts = split(code, "\njulia> ")
    for part in parts
        p = replace(part, "julia> ", "", 1)
        ex, cursor = parse(p, 1)
        result =
            try
                ans = eval(sandbox, ex)
                eval(sandbox, :(ans = $(ans)))
                endswith(strip(p[1:cursor-1]), ';') ?
                    "" : result_to_string(ans)
            catch err
                error_to_string(err, catch_backtrace())
            end
        checkresults(code, part, p[cursor:end], result)
    end
end
function eval_script(code, sandbox)
    code, expected = split(code, "\n# output\n", limit = 2)
    result =
        try
            ans = nothing
            for (ex, str) in Utilities.parseblock(code)
                ans = eval(sandbox, ex)
            end
            result_to_string(ans)
        catch err
            error_to_string(err, catch_backtrace())
        end
    checkresults(code, "", expected, result)
end

function result_to_string(value)
    buf = IOBuffer()
    dis = Base.Multimedia.TextDisplay(buf)
    display(dis, value)
    takebuf_string(buf)
end
result_to_string(::Void) = ""

function error_to_string(er, bt)
    buf = IOBuffer()
    print(buf, "ERROR: ")
    showerror(buf, er, bt)
    println(buf)
    takebuf_string(buf)
end

function checkresults(code, part, expected, result)
    ex, res = map(stripws, (expected, result))
    ex == res ? nothing : throw(DocTestError(code, part, ex, res))
end
function stripws(str)
    buf = IOBuffer()
    for line in split(str, ['\n', '\r'])
        line = rstrip(line)
        isempty(line) || println(buf, line)
    end
    takebuf_string(buf)
end

immutable DocTestError <: Exception
    code     :: UTF8String
    part     :: UTF8String
    expected :: UTF8String
    result   :: UTF8String
end

function Base.showerror(io::IO, docerr::DocTestError)
    println(io, "DocTestError in block:\n")
    print_indented(io, docerr.code)
    if !isempty(docerr.part)
        println(io, "\nfor sub-expression:\n")
        print_indented(io, docerr.part)
    end
    println(io, "\n[Expected Result]\n")
    print_indented(io, docerr.expected)
    println(io, "\n[Actual Result]\n")
    print_indented(io, docerr.result)
end

function print_indented(buf::IO, str::AbstractString; indent = 4)
    for line in split(str, ['\n', '\r'])
        println(buf, " "^indent, line)
    end
end

end
