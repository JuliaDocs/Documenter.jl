"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta, Compat
using DocStringExtensions

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

# Print logging output to the "real" STDOUT.
function log(doc, msg)
    __log__[] && print_with_color(:magenta, STDOUT, "Documenter: ", msg, "\n")
    return nothing
end

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

function warn(file, msg, err, ex, mod)
    if __log__[]
        warn(file, msg)
        print_with_color(:red, STDOUT, "\nERROR: $err\n\nexpression '$ex' in module '$mod'\n\n")
    else
        nothing
    end
end

function warn(doc, page, msg, err)
    file = page.source
    print_with_color(:red, STDOUT, " !! Warning in $(file):\n\n$(msg)\n\nERROR: $(err)\n\n")
end

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

"""
Find the path of a file relative to the `source` directory. `root` is the path
to the directory containing the file `file`.

It is meant to be used with `walkdir(source)`.
"""
srcpath(source, root, file) = normpath(joinpath(relpath(root, source), file))

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

Returns a `Vector` of tuples `(expr, code)`, where `expr` is the corresponding expression
(e.g. a `Expr` or `Symbol` object) and `code` is the string of code the expression was
parsed from.

The keyword argument `skip = N` drops the leading `N` lines from the input string.
"""
function parseblock(code::AbstractString, doc, page; skip = 0, keywords = true)
    # Drop `skip` leading lines from the code block. Needed for deprecated `{docs}` syntax.
    code = string(code, '\n')
    code = last(split(code, '\n', limit = skip + 1))
    # Check whether we have windows-style line endings.
    local offset = contains(code, "\n\r") ? 2 : 1
    local endofstr = endof(code)
    local results = []
    local cursor = 1
    while cursor < endofstr
        # Check for keywords first since they will throw parse errors if we `parse` them.
        local line = match(r"^(.+)$"m, SubString(code, cursor)).captures[1]
        local keyword = Symbol(strip(line))
        (ex, ncursor) =
            if keywords && haskey(Docs.keywords, keyword)
                # adding offset below should be OK, as `\n` and `\r` are single byte
                (QuoteNode(keyword), cursor + endof(line) + offset)
            else
                try
                    parse(code, cursor)
                catch err
                    push!(doc.internal.errors, :parse_error)
                    Utilities.warn(doc, page, "Failed to parse expression.", err)
                    break
                end
            end
        push!(results, (ex, SubString(code, cursor, prevind(code, ncursor))))
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
    warn(Utilities.takebuf_str(out))
end

# Finding submodules.

const ModVec = Union{Module, Vector{Module}}

"""
Returns the set of submodules of a given root module/s.
"""
function submodules(modules::Vector{Module})
    out = Set{Module}()
    for each in modules
        submodules(each, out)
    end
    out
end
function submodules(root::Module, seen = Set{Module}())
    push!(seen, root)
    for name in names(root, true)
        if Base.isidentifier(name) && isdefined(root, name) && !isdeprecated(root, name)
            object = getfield(root, name)
            if isa(object, Module) && !(object in seen)
                submodules(object, seen)
            end
        end
    end
    return seen
end

# Compat for `isdeprecated` which does not exist in Julia 0.4.
if isdefined(Base, :isdeprecated)
    isdeprecated(m, s) = Base.isdeprecated(m, s)
else
    isdeprecated(m, s) = ccall(:jl_is_binding_deprecated, Cint, (Any, Any), m, s) != 0
end

## objects
## =======

import Base.Docs: Binding

if VERSION < v"0.5.0-dev"
    @eval function Base.call(::Type{Binding}, m::Module, v::Symbol)
        m = module_name(m) === v ? module_parent(m) : m
        m = Base.binding_module(m, v)
        $(Expr(:new, :Binding, :m, :v))
    end
end

"""
Represents an object stored in the docsystem by its binding and signature.
"""
immutable Object
    binding   :: Binding
    signature :: Type

    function Object(b::Binding, signature::Type)
        m = module_name(b.mod) === b.var ? module_parent(b.mod) : b.mod
        new(Binding(m, b.var), signature)
    end
end

function splitexpr(x::Expr)
    isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
    isexpr(x, :.)         ? (x.args[1], x.args[2]) :
    error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(current_module()), quot(s)
splitexpr(other)     = error("Invalid @var syntax `$other`.")

"""
    object(ex, str)

Returns a expression that, when evaluated, returns an [`Object`](@ref) representing `ex`.
"""
function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding   = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 1 + Compat.macros_have_sourceloc) && !endswith(str, "()") && (signature = :(Union{}))
    Expr(:call, Object, binding, signature)
end

function object(qn::QuoteNode, str::AbstractString)
    if haskey(Base.Docs.keywords, qn.value)
        binding = Expr(:call, Binding, Main, qn)
        Expr(:call, Object, binding, Union{})
    else
        error("'$(qn.value)' is not a documented keyword.")
    end
end

function Base.print(io::IO, obj::Object)
    print(io, obj.binding)
    print_signature(io, obj.signature)
end
print_signature(io::IO, signature::Union{Union, Type{Union{}}}) = nothing
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
        isexpr(ex, :macrocall, 1 + Compat.macros_have_sourceloc) && !endswith(rstrip(str), "()") && (ex = quot(ex))
        :(Base.Docs.@doc $ex)
    end
end
docs(qn::QuoteNode, str::AbstractString) = :(Base.Docs.@doc $(qn.value))

"""
Returns the category name of the provided [`Object`](@ref).
"""
doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

function doccat(b::Binding, ::Union{Union, Type{Union{}}})
    if b.mod === Main && haskey(Base.Docs.keywords, b.var)
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
if isdefined(Base, :UnionAll)
    doccat(::UnionAll) = "Type"
end
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

"""
Does the given docstring represent actual documentation or a no docs error message?
"""
nodocs(x)      = contains(stringmime("text/plain", x), "No documentation found.")
nodocs(::Void) = false

header_level{N}(::Markdown.Header{N}) = N

if VERSION < v"0.6.0-dev.1254"
    takebuf_str(b) = takebuf_string(b)
else
    takebuf_str(b) = String(take!(b))
end

# Finding URLs -- based partially on code from the main Julia repo in `base/methodshow.jl`.
#
# Paths on Windows contain backslashes, so the `url` function needs to take care of them.
# However, the exact formatting is not consistent and depends on whether Julia runs
# separately or in Cygwin.
#
# We get paths from Julia's docsystem, e.g.
#     Docs.docstr(Docs.Binding(Documenter,:Documenter)).data[:path]
# and from git
#     git rev-parse --show-toplevel
#
# * Ordinary Windows binaries (both Julia and git)
#   In this case the paths from the docsystem are Windows-like with backslashes, e.g.:
#       C:\Users\<user>\.julia\v0.6\Documenter\src\Documenter.jl
#   But the paths from git have forward slashes, e.g.:
#       C:/Users/<user>julia/v0.6/Documenter
#
# * Running under Cygwin
#   The paths from the docsystem are the same as before, e.g.:
#       C:\Users\<user>\.julia\v0.6\Documenter\src\Documenter.jl
#   However, git returns UNIX-y paths using a /cygdrive mount, e.g.:
#       /cygdrive/c/<user>/.julia/v0.6/Documenter
#   We can fix that with `cygpath -m <path>` to get a Windows-like path with forward
#   slashes, e.g.:
#       C:/Users/<user>/.julia/v0.6/Documenter)
#
# In the docsystem paths we replace the backslashes with forward slashes before we start
# comparing paths with the ones from git.
#

"""
    in_cygwin()

Check if we're running under cygwin. Useful when we need to translate cygwin paths to
windows paths.
"""
function in_cygwin()
    if is_windows()
        try
            return success(`cygpath -h`)
        catch
            return false
        end
    else
        return false
    end
end

function url(repo, file)
    file = abspath(file)
    remote = getremote(dirname(file))
    isempty(repo) && (repo = "https://github.com/$remote/tree/{commit}{path}")
    # Replace any backslashes in links, if building the docs on Windows
    file = replace(file, '\\', '/')
    commit, root = cd(dirname(file)) do
        toplevel = readchomp(`git rev-parse --show-toplevel`)
        if in_cygwin()
            toplevel = readchomp(`cygpath -m "$toplevel"`)
        end
        readchomp(`git rev-parse HEAD`), toplevel
    end
    if startswith(file, root)
        _, path = split(file, root; limit = 2)
        repo = replace(repo, "{commit}", commit)
        repo = replace(repo, "{path}", path)
        Nullable{Compat.String}(repo)
    else
        Nullable{Compat.String}()
    end
end

url(remote, repo, doc) = url(remote, repo, doc.data[:module], doc.data[:path], linerange(doc))

# Correct file and line info only available from this version onwards.
if VERSION >= v"0.5.0-dev+3442"
    function url(remote, repo, mod, file, linerange)
        remote = getremote(dirname(file))
        isabspath(file) && isempty(remote) && isempty(repo) && return Nullable{Compat.String}()
        # Replace any backslashes in links, if building the docs on Windows
        file = replace(file, '\\', '/')
        # Format the line range.
        line = format_line(linerange)
        # Macro-generated methods such as those produced by `@deprecate` list their file as
        # `deprecated.jl` since that is where the macro is defined. Use that to help
        # determine the correct URL.
        if inbase(mod) || !isabspath(file)
            base = "https://github.com/JuliaLang/julia/tree"
            dest = "base/$file#$line"
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
                toplevel = readchomp(`git rev-parse --show-toplevel`)
                if in_cygwin()
                    toplevel = readchomp(`cygpath -m "$toplevel"`)
                end
                readchomp(`git rev-parse HEAD`), toplevel
            end
            if startswith(file, root)
                if isempty(repo)
                    repo = "https://github.com/$remote/tree/{commit}{path}#{line}"
                end

                _, path = split(file, root; limit = 2)
                repo = replace(repo, "{commit}", commit)
                repo = replace(repo, "{path}", path)
                repo = replace(repo, "{line}", line)

                Nullable{Compat.String}(repo)
            else
                Nullable{Compat.String}()
            end
        end
    end
else
    url(remote, repo, mod, file, line) = Nullable{Compat.String}()
end

function getremote(dir::AbstractString)
    remote =
        try
            cd(() -> readchomp(`git config --get remote.origin.url`), dir)
        catch err
            ""
        end
    match  = Utilities.nullmatch(isdefined(Base, :LibGit2) ?
        Base.LibGit2.GITHUB_REGEX : Pkg.Git.GITHUB_REGEX, remote)
    if isnull(match)
        travis = get(ENV, "TRAVIS_REPO_SLUG", "")
        isempty(travis) ? "" : travis
    else
        getmatch(match, 1)
    end
end

"""
$(SIGNATURES)

Returns the first 5 characters of the current git commit hash of the directory `dir`.
"""
function get_commit_short(dir)
    commit = cd(dir) do
        readchomp(`git rev-parse HEAD`)
    end
    (length(commit) > 5) ? commit[1:5] : commit
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
    return lines > 0 ? (from:(from + lines + 1)) : (from:from)
end

function format_line(range::Range)
    local top = format_line(first(range))
    return length(range) <= 1 ? top : string(top, '-', format_line(last(range)))
end
format_line(line::Integer) = string('L', line)

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0


unwrap(f, x::Nullable) = isnull(x) ? nothing : f(get(x))

# Output redirection.
# -------------------

"""
Call a function and capture all `STDOUT` and `STDERR` output.

    withoutput(f) --> (result, success, backtrace, output)

where

  * `result` is the value returned from calling function `f`.
  * `success` signals whether `f` has thrown an error, in which case `result` stores the
    `Exception` that was raised.
  * `backtrace` a `Vector{Ptr{Void}}` produced by `catch_backtrace()` if an error is thrown.
  * `output` is the combined output of `STDOUT` and `STDERR` during execution of `f`.

"""
function withoutput(f)
    # Save the default output streams.
    local stdout = STDOUT
    local stderr = STDERR

    # Redirect both the `STDOUT` and `STDERR` streams to a single `Pipe` object.
    local pipe = Pipe()
    Base.link_pipe(pipe; julia_only_read = true, julia_only_write = true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)

    # Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    local output = UInt8[]

    # Run the function `f`, capturing all output that it might have generated.
    # Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace =
        try
            f(), true, Vector{Ptr{Void}}()
        catch err
            err, false, catch_backtrace()
        finally
            # Force at least a single write to `pipe`, otherwise `readavailable` blocks.
            println()
            # Restore the original output streams.
            redirect_stdout(stdout)
            redirect_stderr(stderr)
            # NOTE: `close` must always be called *after* `readavailable`.
            append!(output, readavailable(pipe))
            close(pipe)
        end
    return result, success, backtrace, chomp(Compat.String(output))
end


"""
    issubmodule(sub, mod)

Checks whether `sub` is a submodule of `mod`. A module is also considered to be
its own submodule.

E.g. `A.B.C` is a submodule of `A`, `A.B` and `A.B.C`, but it is not a submodule
of `D`, `A.D` nor `A.B.C.D`.
"""
function issubmodule(sub, mod)
    if (sub === Main) && (mod !== Main)
        return false
    end
    (sub === mod) || issubmodule(module_parent(sub), mod)
end

"""
    isabsurl(url)

Checks whether `url` is an absolute URL (as opposed to a relative one).
"""
isabsurl(url) = ismatch(ABSURL_REGEX, url)
const ABSURL_REGEX = r"^[[:alpha:]+-.]+://"

include("DOM.jl")
include("MDFlatten.jl")
include("TextDiff.jl")

end
