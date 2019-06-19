"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta
import Base: isdeprecated, Docs.Binding
using DocStringExtensions
import Markdown, LibGit2
import Base64: stringmime

# escape characters that has a meaning in regex
regex_escape(str) = sprint(escape_string, str, "\\^\$.|?*+()[{")

# helper to display linerange for error printing
function find_block_in_file(code, file)
    source_file = Base.find_source_file(file)
    source_file === nothing && return nothing
    isfile(source_file) || return nothing
    content = read(source_file, String)
    content = replace(content, "\r\n" => "\n")
    # make a regex of the code that matches leading whitespace
    rcode = "\\h*" * replace(regex_escape(code), "\\n" => "\\n\\h*")
    blockidx = findfirst(Regex(rcode), content)
    blockidx === nothing && return nothing
    startline = countlines(IOBuffer(content[1:prevind(content, first(blockidx))]))
    endline = startline + countlines(IOBuffer(code)) + 1 # +1 to include the closing ```
    return ":$(startline)-$(endline)"
end

# Pretty-printing locations
function locrepr(file, line=nothing)
    str = Base.contractuser(file) # TODO: Maybe print this relative the doc-root??
    line !== nothing && (str = str * "$(line)")
    return str
end

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
    s = replace(s, r"\s+" => "-")
    s = replace(s, r"^\d+" => "")
    s = replace(s, r"&" => "-and-")
    s = replace(s, r"[^\p{L}\p{P}\d\-]+" => "")
    s = strip(replace(s, r"\-\-+" => "-"), '-')
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
function parseblock(code::AbstractString, doc, file; skip = 0, keywords = true)
    # Drop `skip` leading lines from the code block. Needed for deprecated `{docs}` syntax.
    code = string(code, '\n')
    code = last(split(code, '\n', limit = skip + 1))
    endofstr = lastindex(code)
    results = []
    cursor = 1
    while cursor < endofstr
        # Check for keywords first since they will throw parse errors if we `parse` them.
        line = match(r"^(.*)\r?\n"m, SubString(code, cursor)).match
        keyword = Symbol(strip(line))
        (ex, ncursor) =
            # TODO: On 0.7 Symbol("") is in Docs.keywords, remove that check when dropping 0.6
            if keywords && (haskey(Docs.keywords, keyword) || keyword == Symbol(""))
                (QuoteNode(keyword), cursor + lastindex(line))
            else
                try
                    Meta.parse(code, cursor)
                catch err
                    push!(doc.internal.errors, :parse_error)
                    @warn "failed to parse exception in $(Utilities.locrepr(file))" exception = err
                    break
                end
            end
        str = SubString(code, cursor, prevind(code, ncursor))
        if !isempty(strip(str))
            push!(results, (ex, str))
        end
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
    @warn(String(take!(out)))
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
    for name in names(root, all=true)
        if Base.isidentifier(name) && isdefined(root, name) && !isdeprecated(root, name)
            object = getfield(root, name)
            if isa(object, Module) && !(object in seen) && parentmodule(object::Module) == root
                submodules(object, seen)
            end
        end
    end
    return seen
end



## objects
## =======



"""
Represents an object stored in the docsystem by its binding and signature.
"""
struct Object
    binding   :: Binding
    signature :: Type

    function Object(b::Binding, signature::Type)
        m = nameof(b.mod) === b.var ? parentmodule(b.mod) : b.mod
        new(Binding(m, b.var), signature)
    end
end

function splitexpr(x::Expr)
    isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
    isexpr(x, :.)         ? (x.args[1], x.args[2]) :
    error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(Main), quot(s)
splitexpr(other)     = error("Invalid @var syntax `$other`.")

"""
    object(ex, str)

Returns a expression that, when evaluated, returns an [`Object`](@ref) representing `ex`.
"""
function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding   = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 2) && !endswith(str, "()") && (signature = :(Union{}))
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
function docs(ex::Union{Symbol, Expr}, str::AbstractString)
    isexpr(ex, :macrocall, 2) && !endswith(rstrip(str), "()") && (ex = quot(ex))
    :(Base.Docs.@doc $ex)
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
doccat(x::UnionAll) = doccat(Base.unwrap_unionall(x))
doccat(::Module)   = "Module"
doccat(::Any)      = "Constant"

"""
    filterdocs(doc, modules)

Remove docstrings from the markdown object, `doc`, that are not from one of `modules`.
"""
function filterdocs(doc::Markdown.MD, modules::Set{Module})
    if isempty(modules)
        # When no modules are specified in `makedocs` then don't filter anything.
        doc
    else
        if haskey(doc.meta, :module)
            doc.meta[:module] ∈ modules ? doc : nothing
        else
            if haskey(doc.meta, :results)
                out = []
                results = []
                for (each, result) in zip(doc.content, doc.meta[:results])
                    r = filterdocs(each, modules)
                    if r !== nothing
                        push!(out, r)
                        push!(results, result)
                    end
                end
                if isempty(out)
                    nothing
                else
                    md = Markdown.MD(out)
                    md.meta[:results] = results
                    md
                end
            else
                out = []
                for each in doc.content
                    r = filterdocs(each, modules)
                    r === nothing || push!(out, r)
                end
                isempty(out) ? nothing : Markdown.MD(out)
            end
        end
    end
end
# Non-markdown docs won't have a `.meta` field so always just accept those.
filterdocs(other, modules::Set{Module}) = other

"""
Does the given docstring represent actual documentation or a no docs error message?
"""
nodocs(x) = occursin("No documentation found.", stringmime("text/plain", x))
nodocs(::Nothing) = false

header_level(::Markdown.Header{N}) where {N} = N

"""
    repo_root(file; dbdir=".git")

Tries to determine the root directory of the repository containing `file`. If the file is
not in a repository, the function returns `nothing`.

The `dbdir` keyword argument specifies the name of the directory we are searching for to
determine if this is a repostory or not. If there is a file called `dbdir`, then it's
contents is checked under the assumption that it is a Git worktree or a submodule.
"""
function repo_root(file; dbdir=".git")
    parent_dir, parent_dir_last = dirname(abspath(file)), ""
    while parent_dir != parent_dir_last
        dbdir_path = joinpath(parent_dir, dbdir)
        isdir(dbdir_path) && return parent_dir
        # Let's see if this is a worktree checkout
        if isfile(dbdir_path)
            contents = chomp(read(dbdir_path, String))
            if startswith(contents, "gitdir: ")
                if isdir(joinpath(parent_dir, contents[9:end]))
                    return parent_dir
                end
            end
        end
        parent_dir, parent_dir_last = dirname(parent_dir), parent_dir
    end
    return nothing
end

"""
    $(SIGNATURES)

Returns the path of `file`, relative to the root of the Git repository, or `nothing` if the
file is not in a Git repository.
"""
function relpath_from_repo_root(file)
    cd(dirname(file)) do
        root = repo_root(file)
        root !== nothing && startswith(file, root) ? relpath(file, root) : nothing
    end
end

function repo_commit(file)
    cd(dirname(file)) do
        readchomp(`git rev-parse HEAD`)
    end
end

function url(repo, file; commit=nothing)
    file = realpath(abspath(file))
    remote = getremote(dirname(file))
    isempty(repo) && (repo = "https://github.com/$remote/blob/{commit}{path}")
    path = relpath_from_repo_root(file)
    if path === nothing
        nothing
    else
        repo = replace(repo, "{commit}" => commit === nothing ? repo_commit(file) : commit)
        # Note: replacing any backslashes in path (e.g. if building the docs on Windows)
        repo = replace(repo, "{path}" => string("/", replace(path, '\\' => '/')))
        repo = replace(repo, "{line}" => "")
        repo
    end
end

url(remote, repo, doc) = url(remote, repo, doc.data[:module], doc.data[:path], linerange(doc))

function url(remote, repo, mod, file, linerange)
    file === nothing && return nothing # needed on julia v0.6, see #689
    remote = getremote(dirname(file))
    isabspath(file) && isempty(remote) && isempty(repo) && return nothing

    # make sure we get the true path, as otherwise we will get different paths when we compute `root` below
    if isfile(file)
        file = realpath(abspath(file))
    end

    # Format the line range.
    line = format_line(linerange, LineRangeFormatting(repo_host_from_url(repo)))
    # Macro-generated methods such as those produced by `@deprecate` list their file as
    # `deprecated.jl` since that is where the macro is defined. Use that to help
    # determine the correct URL.
    if inbase(mod) || !isabspath(file)
        file = replace(file, '\\' => '/')
        base = "https://github.com/JuliaLang/julia/blob"
        dest = "base/$file#$line"
        if isempty(Base.GIT_VERSION_INFO.commit)
            "$base/v$VERSION/$dest"
        else
            commit = Base.GIT_VERSION_INFO.commit
            "$base/$commit/$dest"
        end
    else
        path = relpath_from_repo_root(file)
        if isempty(repo)
            repo = "https://github.com/$remote/blob/{commit}{path}#{line}"
        end
        if path === nothing
            nothing
        else
            repo = replace(repo, "{commit}" => repo_commit(file))
            # Note: replacing any backslashes in path (e.g. if building the docs on Windows)
            repo = replace(repo, "{path}" => string("/", replace(path, '\\' => '/')))
            repo = replace(repo, "{line}" => line)
            repo
        end
    end
end

function getremote(dir::AbstractString)
    remote =
        try
            cd(() -> readchomp(`git config --get remote.origin.url`), dir)
        catch err
            ""
        end
    m = match(LibGit2.GITHUB_REGEX, remote)
    if m === nothing
        travis = get(ENV, "TRAVIS_REPO_SLUG", "")
        isempty(travis) ? "" : travis
    else
        m[1]
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
        parent = parentmodule(m)
        parent ≡ m ? false : inbase(parent)
    end
end

# Repository hosts
#   RepoUnknown denotes that the repository type could not be determined automatically
@enum RepoHost RepoGithub RepoBitbucket RepoGitlab RepoUnknown

# Repository host from repository url
# i.e. "https://github.com/something" => RepoGithub
#      "https://bitbucket.org/xxx" => RepoBitbucket
# If no match, returns RepoUnknown
function repo_host_from_url(repoURL::String)
    if occursin("bitbucket", repoURL)
        return RepoBitbucket
    elseif occursin("github", repoURL) || isempty(repoURL)
        return RepoGithub
    elseif occursin("gitlab", repoURL)
        return RepoGitlab
    else
        return RepoUnknown
    end
end

# Find line numbers.
# ------------------

linerange(doc) = linerange(doc.text, doc.data[:linenumber])

function linerange(text, from)
    lines = sum([isodd(n) ? newlines(s) : 0 for (n, s) in enumerate(text)])
    return lines > 0 ? (from:(from + lines + 1)) : (from:from)
end

struct LineRangeFormatting
    prefix::String
    separator::String

    function LineRangeFormatting(host::RepoHost)
        if host == RepoBitbucket
            new("", ":")
        elseif host == RepoGitlab
            new("L", "-")
        else
            # default is github-style
            new("L", "-L")
        end
    end
end

function format_line(range::AbstractRange, format::LineRangeFormatting)
    if length(range) <= 1
        string(format.prefix, first(range))
    else
        string(format.prefix, first(range), format.separator, last(range))
    end
end

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0


# Output redirection.
# -------------------
using Logging

"""
Call a function and capture all `stdout` and `stderr` output.

    withoutput(f) --> (result, success, backtrace, output)

where

  * `result` is the value returned from calling function `f`.
  * `success` signals whether `f` has thrown an error, in which case `result` stores the
    `Exception` that was raised.
  * `backtrace` a `Vector{Ptr{Cvoid}}` produced by `catch_backtrace()` if an error is thrown.
  * `output` is the combined output of `stdout` and `stderr` during execution of `f`.

"""
function withoutput(f)
    # Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr

    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)
    # Also redirect logging stream to the same pipe
    logger = ConsoleLogger(pipe.in)

    # Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    output = UInt8[]

    # Run the function `f`, capturing all output that it might have generated.
    # Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace = with_logger(logger) do
        try
            f(), true, Vector{Ptr{Cvoid}}()
        catch err
            # InterruptException should never happen during normal doc-testing
            # and not being able to abort the doc-build is annoying (#687).
            isa(err, InterruptException) && rethrow(err)

            err, false, catch_backtrace()
        finally
            # Force at least a single write to `pipe`, otherwise `readavailable` blocks.
            println()
            # Restore the original output streams.
            redirect_stdout(default_stdout)
            redirect_stderr(default_stderr)
            # NOTE: `close` must always be called *after* `readavailable`.
            append!(output, readavailable(pipe))
            close(pipe)
        end
    end
    return result, success, backtrace, chomp(String(output))
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
    (sub === mod) || issubmodule(parentmodule(sub), mod)
end

"""
    isabsurl(url)

Checks whether `url` is an absolute URL (as opposed to a relative one).
"""
isabsurl(url) = occursin(ABSURL_REGEX, url)
const ABSURL_REGEX = r"^[[:alpha:]+-.]+://"

"""
    mdparse(s::AbstractString; mode=:single)

Parses the given string as Markdown using `Markdown.parse`, but strips away the surrounding
layers, such as the outermost `Markdown.MD`. What exactly is returned depends on the `mode`
keyword.

The `mode` keyword argument can be one of the following:

* `:single` (default) -- returns a single block-level object (e.g. `Markdown.Paragraph` or
  `Markdown.Admonition`) and errors if the string parses into multiple blocks.
* `:blocks` -- the function returns a `Vector{Any}` of Markdown blocks.
* `:span` -- Returns a `Vector{Any}` of span-level items, stripping away the outer block.
  This requires the string to parse into a single `Markdown.Paragraph`, the contents of
  which gets returned.
"""
function mdparse(s::AbstractString; mode=:single)
    mode in [:single, :blocks, :span] || throw(ArgumentError("Invalid mode keyword $(mode)"))
    md = Markdown.parse(s)
    if mode == :blocks
        md.content
    elseif length(md.content) == 0
        # case where s == "". We'll just return an empty string / paragraph.
        (mode == :single) ? Markdown.Paragraph(Any[""]) : Any[""]
    elseif (mode == :single || mode == :span) && length(md.content) > 1
        @error "mode == :$(mode) requires the Markdown string to parse into a single block" s md.content
        throw(ArgumentError("Unsuitable string for mode=:$(mode)"))
    else
        @assert length(md.content) == 1
        @assert mode == :span || mode == :single
        if mode == :span && !isa(md.content[1], Markdown.Paragraph)
            @error "mode == :$(mode) requires the Markdown string to parse into a Markdown.Paragraph" s md.content
            throw(ArgumentError("Unsuitable string for mode=:$(mode)"))
        end
        (mode == :single) ? md.content[1] : md.content[1].content
    end
end

# Capturing output in different representations similar to IJulia.jl
function limitstringmime(m::MIME"text/plain", x)
    io = IOBuffer()
    show(IOContext(io, :limit=> true), m, x)
    return String(take!(io))
end
function display_dict(x)
    out = Dict{MIME,Any}()
    x === nothing && return out
    # Always generate text/plain
    out[MIME"text/plain"()] = limitstringmime(MIME"text/plain"(), x)
    for m in [MIME"text/html"(), MIME"image/svg+xml"(), MIME"image/png"(),
              MIME"image/webp"(), MIME"image/gif"(), MIME"image/jpeg"(),
              MIME"text/latex"(), MIME"text/markdown"()]
        showable(m, x) && (out[m] = stringmime(m, x))
    end
    return out
end

include("DOM.jl")
include("MDFlatten.jl")
include("TextDiff.jl")
include("Selectors.jl")
include("Markdown2.jl")

end
