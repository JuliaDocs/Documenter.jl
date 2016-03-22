"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta, Compat

# Logging output.

const __log__ = Ref(true)
"""
    logging(flag::Bool)

Enable or disable logging output for [`log`]({ref}) and [`warn`]({ref}).
"""
logging(flag::Bool) = __log__[] = flag

"""
Format and print a message to the user.
"""
log(msg) = __log__[] ? print_with_color(:magenta, STDOUT, "LAPIDARY: ", msg, "\n") : nothing

debug(msg) = print_with_color(:green, " ?? ", msg, "\n")

"""
    warn(file, msg)
    warn(msg)

Format and print a warning message to the user. Passing a `file` will include the filename
where the warning was raised.
"""
function warn(file, msg)
    if __log__[]
        msg = string(" !! ", msg, " [", file, "]\n")
        print_with_color(:red, STDOUT, msg)
    else
        nothing
    end
end
warn(msg) = __log__[] ? print_with_color(:red, STDOUT, " !! ", msg, "\n") : nothing

# Directory paths.

"""
Returns the current directory.
"""
function currentdir()
    d = Base.source_dir()
    d === nothing ? pwd() : d
end

"""
Returns the path to the Lapidary `assets` directory.
"""
assetsdir() = normpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

cleandir(d::AbstractString) = (isdir(d) && rm(d, recursive = true); mkdir(d))

# Slugify text.

"""
Slugify a string into a suitable URL.
"""
function slugify(s)
    s = replace(s, r"\s+", "-")
    s = replace(s, r"^\d+", "")
    s = replace(s, r"&", "-and-")
    s = replace(s, r"[^\p{L}\p{P}\d\-]+", "")
    s = strip(replace(s, r"\-\-+", "-"), '-')
end

# Parse code blocks.

"""
Returns a vector of parsed expressions and their corresponding raw strings.

The keyword argument `skip = N` drops the leading `N` lines from the input string.
"""
function parseblock(code; skip = 0)
    code = string(code, '\n')
    code = last(split(code, '\n', limit = skip + 1))
    results, cursor = [], 1
    while cursor < length(code)
        ex, ncursor = parse(code, cursor)
        push!(results, (ex, code[cursor:ncursor-1]))
        cursor = ncursor
    end
    results
end
isassign(x) = isexpr(x, :(=), 2) && isa(x.args[1], Symbol)

# Checking arguments.

"""
Prints a formatted warning to the user listing unrecognised keyword arguments.
"""
function check_kwargs(kws)
    isempty(kws) && return
    out = IOBuffer()
    println(out, "Unknown keywords:\n")
    for (k, v) in kws
        println(out, "  ", k, " = ", v)
    end
    warn(takebuf_string(out))
end

# Finding submodules.

typealias ModVec Union{Module, Vector{Module}}

"""
Returns the set of submodules of a given root module/s.
"""
function submodules(modules::Vector{Module})
    out = Set{Module}()
    for each in modules
        union!(out, submodules(each))
    end
    out
end
function submodules(root::Module, out = Set([root]))
    for name in names(root, true)
        if isdefined(root, name)
            object = getfield(root, name)
            if isvalidmodule(root, object)
                push!(out, object)
                submodules(object)
            end
        end
    end
    out
end
isvalidmodule(a::Module, b::Module) = a !== b && b !== Main
isvalidmodule(a, b)                 = false

## objects
## =======

immutable Binding
    mod :: Module
    var :: Symbol

    function Binding(m::Module, v::Symbol)
        # Normalise the binding module for module symbols so that:
        #   Binding(Base, :Base) === Binding(Main, :Base)
        m = module_name(m) === v ? module_parent(m) : m
        new(Base.binding_module(m, v), v)
    end
end

function Base.show(io::IO, b::Binding)
    m = b.mod ≡ Main ? "" : string(b.mod, '.')
    print(io, m, b.var)
end

"""
Represents an object stored in the docsystem by its binding and signature.
"""
immutable Object
    binding   :: Binding
    signature :: Type
end

function splitexpr(x::Expr)
    isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
    isexpr(x, :.)         ? (x.args[1], x.args[2]) :
    error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(current_module()), quot(s)
splitexpr(other)     = error("Invalid @var syntax `$other`.")

Base.Docs.signature(::Symbol) = :(Union{})

"""
    object(ex, str)

Returns a expression that, when evaluated, returns an [`Object`]({ref}) representing `ex`.
"""
function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding   = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 1) && !endswith(str, "()") && (signature = :(Union{}))
    Expr(:call, Object, binding, signature)
end

function object(qn::QuoteNode, str::AbstractString)
    if haskey(Base.Docs.keywords, qn.value)
        binding = Expr(:call, Binding, Keywords, qn)
        Expr(:call, Object, binding, Union{})
    else
        error("'$(qn.value)' is not a documented keyword.")
    end
end

function Base.print(io::IO, obj::Object)
    print(io, obj.binding)
    print_signature(io, obj.signature)
end
print_signature(io::IO, signature::Union) = nothing
print_signature(io::IO, signature)        = print(io, '-', signature)

## docs
## ====

"""
    docs(ex, str)

Returns an expression that, when evaluated, returns the docstrings associated with `ex`.
"""
function docs end

# Macro representation changed between 0.4 and 0.5.
if VERSION < v"0.5-"
    function docs(ex::Union{Symbol, Expr}, str::AbstractString)
        :(Base.Docs.@doc $ex)
    end
else
    function docs(ex::Union{Symbol, Expr}, str::AbstractString)
        isexpr(ex, :macrocall, 1) && !endswith(rstrip(str), "()") && (ex = quot(ex))
        :(Base.Docs.@doc $ex)
    end
end
docs(qn::QuoteNode, str::AbstractString) = :(Base.Docs.@doc $(qn.value))

"""
Returns the category name of the provided [`Object`]({ref}).
"""
doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

doccat(b::Binding, ::Union) = b.mod == Keywords && haskey(Base.Docs.keywords, b.var) ?
    "Keyword" : doccat(getfield(b.mod, b.var))

doccat(b::Binding, ::Type)  = "Method"

doccat(::Function) = "Function"
doccat(::DataType) = "Type"
doccat(::Module)   = "Module"
doccat(::ANY)      = "Constant"

"""
    filterdocs(doc, modules)

Remove docstrings from the markdown object, `doc`, that are not from one of `modules`.
"""
function filterdocs(doc::Markdown.MD, modules::Set{Module})
    if isempty(modules)
        # When no modules are specified in `makedocs` then don't filter anything.
        Nullable(doc)
    else
        if haskey(doc.meta, :module)
            doc.meta[:module] ∈ modules ? Nullable(doc) : Nullable{Markdown.MD}()
        else
            out = []
            for each in doc.content
                r = filterdocs(each, modules)
                isnull(r) || push!(out, get(r))
            end
            isempty(out) ? Nullable{Markdown.MD}() : Nullable(Markdown.MD(out))
        end
    end
end
# Non-markdown docs won't have a `.meta` field so always just accept those.
filterdocs(other, modules::Set{Module}) = Nullable(other)

# Module used to uniquify keyword bindings.
baremodule Keywords end

"""
Does the given docstring represent actual documentation or a no docs error message?
"""
nodocs(x)      = contains(stringmime("text/plain", x), "No documentation found.")
nodocs(::Void) = false

header_level{N}(::Markdown.Header{N}) = N

if !isdefined(:walkdir)
    function walkdir(root; topdown=true, follow_symlinks=false, onerror=throw)
        content = nothing
        try
            content = readdir(root)
        catch err
            isa(err, SystemError) || throw(err)
            onerror(err)
            #Need to return an empty task to skip the current root folder
            return Task(()->())
        end
        dirs = Array(eltype(content), 0)
        files = Array(eltype(content), 0)
        for name in content
            if isdir(joinpath(root, name))
                push!(dirs, name)
            else
                push!(files, name)
            end
        end

        function _it()
            if topdown
                produce(root, dirs, files)
            end
            for dir in dirs
                path = joinpath(root,dir)
                if follow_symlinks || !islink(path)
                    for (root_l, dirs_l, files_l) in walkdir(path, topdown=topdown, follow_symlinks=follow_symlinks, onerror=onerror)
                        produce(root_l, dirs_l, files_l)
                    end
                end
            end
            if !topdown
                produce(root, dirs, files)
            end
        end
        Task(_it)
    end
end

end
