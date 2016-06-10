"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta, Compat

# Logging output.

const __log__ = Ref(true)
"""
    logging(flag::Bool)

Enable or disable logging output for [`log`](@ref) and [`warn`](@ref).
"""
logging(flag::Bool) = __log__[] = flag

"""
Format and print a message to the user.
"""
log(msg) = __log__[] ? print_with_color(:magenta, STDOUT, "Documenter: ", msg, "\n") : nothing

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

# Nullable regex matches.

wrapnothing(T, ::Void) = Nullable{T}()
wrapnothing(T, value)  = Nullable(value)

nullmatch(r::Regex, str::AbstractString) = wrapnothing(RegexMatch, match(r, str))

getmatch(n::Nullable{RegexMatch}, i) = get(n)[i]

# Directory paths.

"""
Returns the current directory.
"""
function currentdir()
    d = Base.source_dir()
    d === nothing ? pwd() : d
end

"""
Returns the path to the Documenter `assets` directory.
"""
assetsdir() = normpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

cleandir(d::AbstractString) = (isdir(d) && rm(d, recursive = true); mkdir(d))

# Slugify text.

"""
Slugify a string into a suitable URL.
"""
function slugify(s::AbstractString)
    s = replace(s, r"\s+", "-")
    s = replace(s, r"^\d+", "")
    s = replace(s, r"&", "-and-")
    s = replace(s, r"[^\p{L}\p{P}\d\-]+", "")
    s = strip(replace(s, r"\-\-+", "-"), '-')
end
slugify(object) = string(object) # Non-string slugifying doesn't do anything.

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
    m = b.mod ∈ (Main, Keywords) ? "" : string(b.mod, '.')
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

Returns a expression that, when evaluated, returns an [`Object`](@ref) representing `ex`.
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
Returns the category name of the provided [`Object`](@ref).
"""
doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

function doccat(b::Binding, ::Union)
    if b.mod === Keywords && haskey(Base.Docs.keywords, b.var)
        "Keyword"
    elseif startswith(string(b.var), '@')
        "Macro"
    else
        doccat(getfield(b.mod, b.var))
    end
end

doccat(b::Binding, ::Type)  = "Method"

doccat(::Function) = "Function"
doccat(::DataType) = "Type"
doccat(::Module)   = "Module"
doccat(::Any)      = "Constant"

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
            if haskey(doc.meta, :results)
                out = []
                results = []
                for (each, result) in zip(doc.content, doc.meta[:results])
                    r = filterdocs(each, modules)
                    if !isnull(r)
                        push!(out, get(r))
                        push!(results, result)
                    end
                end
                if isempty(out)
                    Nullable{Markdown.MD}()
                else
                    md = Markdown.MD(out)
                    md.meta[:results] = results
                    Nullable(md)
                end
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

# Finding URLs -- based partially on code from the main Julia repo in `base/methodshow.jl`.

url(remote, doc) = url(remote, doc.data[:module], doc.data[:path], linerange(doc))

# Correct file and line info only available from this version onwards.
if VERSION >= v"0.5.0-dev+3442"
    function url(remote, mod, file, line)
        isempty(remote) && return Nullable{Compat.String}()
        if inbase(mod)
            base = "https://github.com/JuliaLang/julia/tree"
            dest = "base/$file#L$line"
            Nullable{Compat.String}(
                if isempty(Base.GIT_VERSION_INFO.commit)
                    "$base/v$VERSION/$dest"
                else
                    commit = Base.GIT_VERSION_INFO.commit
                    "$base/$commit/$dest"
                end
            )
        else
            commit, root = cd(dirname(file)) do
                readchomp(`git rev-parse HEAD`), readchomp(`git rev-parse --show-toplevel`)
            end
            if startswith(file, root)
                base = "https://github.com/$remote/tree"
                _, path = split(file, root; limit = 2)
                Nullable{Compat.String}("$base/$commit/$path#L$line")
            else
                Nullable{Compat.String}()
            end
        end
    end
else
    url(remote, mod, file, line) = Nullable{Compat.String}()
end

function getremote(dir::AbstractString)
    remote =
        try
            cd(() -> readchomp(`git config --get remote.origin.url`), dir)
        catch err
            ""
        end
    match  = Utilities.nullmatch(Pkg.Git.GITHUB_REGEX, remote)
    if isnull(match)
        travis = get(ENV, "TRAVIS_REPO_SLUG", "")
        isempty(travis) ? "" : travis
    else
        getmatch(match, 1)
    end
end

function inbase(m::Module)
    if m ≡ Base
        true
    else
        parent = module_parent(m)
        parent ≡ m ? false : inbase(parent)
    end
end

# Find line numbers.
# ------------------

linerange(doc) = linerange(doc.text, doc.data[:linenumber])

function linerange(text, from)
    lines = sum([isodd(n) ? newlines(s) : 0 for (n, s) in enumerate(text)])
    lines > 0 ? string(from, '-', from + lines + 1) : string(from)
end

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0


unwrap(f, x::Nullable) = isnull(x) ? nothing : f(get(x))

end
