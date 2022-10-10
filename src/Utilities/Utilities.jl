"""
Provides a collection of utility functions and types that are used in other submodules.
"""
module Utilities

using Base.Meta
import Base: isdeprecated, Docs.Binding
using DocStringExtensions
import Markdown, MarkdownAST, LibGit2
import Base64: stringmime
import ..ERROR_NAMES

include("Remotes.jl")
using .Remotes: Remote, repourl, repofile
# These imports are here to support code that still assumes that these names are defined
# in the Utilities module.
using .Remotes: RepoHost, RepoGithub, RepoBitbucket, RepoGitlab, RepoAzureDevOps,
    RepoUnknown, format_commit, format_line, repo_host_from_url, LineRangeFormatting

"""
    @docerror(doc, tag, msg, exs...)

Add `tag` to the `doc.internal.errors` array and log the message `msg` as an
error (if `tag` matches the `doc.user.strict` setting) or warning.

- `doc` must be the instance of `Document` used for the Documenter run
- `tag` must be one of the `Symbol`s in `ERROR_NAMES`
- `msg` is the explanation of the issue to the user
- `exs...` are additional expressions that will be included with the message;
  see `@error` and `@warn`
"""
macro docerror(doc, tag, msg, exs...)
    tag isa QuoteNode || error("invalid call of @docerror")
    tag.value ∈ ERROR_NAMES || throw(ArgumentError("tag $(tag) is not a valid Documenter error"))
    esc(quote
        let
            push!($(doc).internal.errors, $(tag))
            if $Utilities.is_strict($(doc).user.strict, $(tag))
                @error $(msg) $(exs...)
            else
                @warn $(msg) $(exs...)
            end
        end
    end)
end

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
    return startline => endline
end

# Pretty-printing locations
function locrepr(file, line=nothing)
    str = Base.contractuser(file) # TODO: Maybe print this relative the doc-root??
    line !== nothing && (str = str * ":$(line.first)-$(line.second)")
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

If `raise=false` is passed, the `Meta.parse` does not raise an exception on parse errors,
but instead returns an expression that will raise an error when evaluated. `parseblock`
returns this expression normally and it must be handled appropriately by the caller.

The `linenumbernode` can be passed as a `LineNumberNode` to give information about filename
and starting line number of the block (requires Julia 1.6 or higher).
"""
function parseblock(code::AbstractString, doc, file; skip = 0, keywords = true, raise=true,
                    linenumbernode=nothing)
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
                    Meta.parse(code, cursor; raise=raise)
                catch err
                    @docerror(doc, :parse_error, "failed to parse exception in $(Utilities.locrepr(file))", exception = err)
                    break
                end
            end
        str = SubString(code, cursor, prevind(code, ncursor))
        if !isempty(strip(str)) && ex !== nothing
            push!(results, (ex, str))
        end
        cursor = ncursor
    end
    if linenumbernode isa LineNumberNode
        exs = Meta.parseall(code; filename=linenumbernode.file).args
        @assert length(exs) == 2 * length(results)
        for (i, ex) in enumerate(Iterators.partition(exs, 2))
            @assert ex[1] isa LineNumberNode
            expr = Expr(:toplevel, ex...) # LineNumberNode + expression
            # in the REPL each evaluation is considered a new file, e.g.
            # REPL[1], REPL[2], ..., so try to mimic that by incrementing
            # the counter for each sub-expression in this code block
            if linenumbernode.file === Symbol("REPL")
                newfile = "REPL[$i]"
                # to reset the line counter for each new "file"
                lineshift = 1 - ex[1].line
                update_linenumbernodes!(expr, newfile, lineshift)
            else
                update_linenumbernodes!(expr, linenumbernode.file, linenumbernode.line)
            end
            results[i] = (expr , results[i][2])
        end
    end
    results
end
isassign(x) = isexpr(x, :(=), 2) && isa(x.args[1], Symbol)

function update_linenumbernodes!(x::Expr, newfile, lineshift)
    for i in 1:length(x.args)
        x.args[i] = update_linenumbernodes!(x.args[i], newfile, lineshift)
    end
    return x
end
update_linenumbernodes!(x::Any, newfile, lineshift) = x
function update_linenumbernodes!(x::LineNumberNode, newfile, lineshift)
    return LineNumberNode(x.line + lineshift, newfile)
end


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
doccat(::Type)     = "Type"
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
    isfile(file) || error("relpath_from_repo_root called with nonexistent file: $file")
    cd(dirname(file)) do
        root = repo_root(file)
        root !== nothing && startswith(file, root) ? relpath(file, root) : nothing
    end
end

function repo_commit(file)
    isfile(file) || error("repo_commit called with nonexistent file: $file")
    cd(dirname(file)) do
        readchomp(`$(git()) rev-parse HEAD`)
    end
end

function edit_url(repo, file; commit=nothing)
    file = abspath(file)
    if !isfile(file)
        @warn "couldn't find file \"$file\" when generating URL"
        return nothing
    end
    file = realpath(file)
    isnothing(repo) && (repo = getremote(dirname(file)))
    isnothing(commit) && (commit = repo_commit(file))
    path = relpath_from_repo_root(file)
    isnothing(path) || isnothing(repo) ? nothing : repofile(repo, commit, path)
end

source_url(repo, doc) = source_url(repo, doc.data[:module], doc.data[:path], linerange(doc))

function source_url(repo, mod, file, linerange)
    file === nothing && return nothing # needed on julia v0.6, see #689
    remote = getremote(dirname(file))
    isabspath(file) && isnothing(remote) && isnothing(repo) && return nothing

    # make sure we get the true path, as otherwise we will get different paths when we compute `root` below
    if isfile(file)
        file = realpath(abspath(file))
    end

    # Macro-generated methods such as those produced by `@deprecate` list their file as
    # `deprecated.jl` since that is where the macro is defined. Use that to help
    # determine the correct URL.
    if inbase(mod) || !isabspath(file)
        ref = if isempty(Base.GIT_VERSION_INFO.commit)
            "v$VERSION"
        else
            Base.GIT_VERSION_INFO.commit
        end
        repofile(julia_remote, ref, "base/$file", linerange)
    elseif isfile(file)
        path = relpath_from_repo_root(file)
        # If we managed to determine a remote for the current file with getremote,
        # then we use that information instead of the user-provided repo (doc.user.remote)
        # argument to generate source links. This means that in the case where some
        # docstrings come from another repository (like the DocumenterTools doc dependency
        # for Documenter), then we generate the correct links, since we actually user the
        # remote determined from the Git repository.
        #
        # In principle, this prevents the user from overriding the remote for the main
        # repository if the repo is cloned from GitHub (e.g. when you clone from a fork, but
        # want the source links to point to the upstream repository; however, this feels
        # like a very unlikely edge case). If the repository is cloned from somewhere else
        # than GitHub, then everything is fine --- getremote will fail and remote is
        # `nothing`, in which case we fall back to using `repo`.
        isnothing(remote) && (remote = repo)
        if isnothing(path) || isnothing(remote)
            return nothing
        end
        repofile(remote, repo_commit(file), path, linerange)
    else
        return nothing
    end
end

"""
A [`Remote`](@ref) corresponding to the main Julia language repository.
"""
const julia_remote = Remotes.GitHub("JuliaLang", "julia")

"""
Stores the memoized results of [`getremote`](@ref).
"""
const GIT_REMOTE_CACHE = Dict{String,Union{Remotes.Remote,Nothing}}()

"""
$(TYPEDSIGNATURES)

Determines the GitHub remote of a directory by checking `remote.origin.url` of the
repository. Returns a [`Remotes.GitHub`](@ref), or `nothing` is something has gone wrong
(e.g. it's run on a directory not in a Git repo, or `origin.url` points to a non-GitHub
remote).

The results for a given directory are memoized in [`GIT_REMOTE_CACHE`](@ref), since calling
`git` is expensive and it is often called on the same directory over and over again.
"""
function getremote(dir::AbstractString)
    isdir(dir) || return nothing
    return get!(GIT_REMOTE_CACHE, dir) do
        remote = try
            readchomp(setenv(`$(git()) config --get remote.origin.url`; dir=dir))
        catch
            ""
        end
        # TODO: we only match for GitHub repositories automatically. Could we engineer a
        # system where, if there is a user-created Remote, the user could also define a
        # matching function here that tries to interpret other URLs?
        m = match(LibGit2.GITHUB_REGEX, remote)
        isnothing(m) && return nothing
        return Remotes.GitHub(m[2], m[3])
    end
end

"""
$(SIGNATURES)

Returns the first 5 characters of the current git commit hash of the directory `dir`.
"""
function get_commit_short(dir)
    commit = cd(dir) do
        readchomp(`$(git()) rev-parse HEAD`)
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

# Find line numbers.
# ------------------

linerange(doc) = linerange(doc.text, doc.data[:linenumber])

function linerange(text, from)
    # text is assumed to be a Core.SimpleVector (svec) from the .text field of a Docs.DocStr object.
    # Hence, we need to be careful when summing over an empty svec below.
    #
    # Also, the isodd logic _appears_ to be there to handle variable interpolation into docstrings. In that case,
    # the .text field seems to become longer than just 1 element and every even element is the interpolated object,
    # and only the odd ones actually contain the docstring text as a string.
    lines = sum(Int[isodd(n) ? newlines(s) : 0 for (n, s) in enumerate(text)])
    return lines > 0 ? (from:(from + lines + 1)) : (from:from)
end

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0


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
keyword. The resulting Markdown AST is converted into an array of `MarkdownAST.Node`s.

The `mode` keyword argument can be one of the following:

* `:single` (default) -- returns a single block-level object (e.g. `Markdown.Paragraph` or
  `Markdown.Admonition`) and errors if the string parses into multiple blocks.
* `:blocks` -- the function returns a `Vector{Any}` of Markdown blocks.
* `:span` -- Returns a `Vector{Any}` of span-level items, stripping away the outer block.
  This requires the string to parse into a single `Markdown.Paragraph`, the contents of
  which gets returned.
"""
function mdparse(s::AbstractString; mode=:single) :: Vector{MarkdownAST.Node{Nothing}}
    mode in [:single, :blocks, :span] || throw(ArgumentError("Invalid mode keyword $(mode)"))
    mdast = convert(MarkdownAST.Node, Markdown.parse(s))
    if mode == :blocks
        MarkdownAST.unlink!.(mdast.children)
    elseif length(mdast.children) == 0
        # case where s == "". We'll just return an empty string / paragraph.
        if mode == :single
            [MarkdownAST.@ast(MarkdownAST.Paragraph() do; ""; end)]
        else
            # If we're in span mode we return a single Text node
            [MarkdownAST.@ast("")]
        end
    elseif (mode == :single || mode == :span) && length(mdast.children) > 1
        @error "mode == :$(mode) requires the Markdown string to parse into a single block" s mdast
        throw(ArgumentError("Unsuitable string for mode=:$(mode)"))
    else
        @assert length(mdast.children) == 1
        childnode = first(mdast.children)
        @assert mode == :span || mode == :single
        if mode == :span && !isa(childnode.element, MarkdownAST.Paragraph)
            @error "mode == :$(mode) requires the Markdown string to parse into a MarkdownAST.Paragraph" s mdast
            throw(ArgumentError("Unsuitable string for mode=:$(mode)"))
        end
        (mode == :single) ? [MarkdownAST.unlink!(childnode)] : MarkdownAST.unlink!.(childnode.children)
    end
end

# Capturing output in different representations similar to IJulia.jl
function limitstringmime(m::MIME"text/plain", x; context = nothing)
    io = IOBuffer()
    ioc = IOContext(context === nothing ? io : IOContext(io, context), :limit => true)
    show(ioc, m, x)
    return String(take!(io))
end
function display_dict(x; context = nothing)
    out = Dict{MIME,Any}()
    x === nothing && return out
    # Always generate text/plain
    out[MIME"text/plain"()] = limitstringmime(MIME"text/plain"(), x, context = context)
    for m in [MIME"text/html"(), MIME"image/svg+xml"(), MIME"image/png"(),
              MIME"image/webp"(), MIME"image/gif"(), MIME"image/jpeg"(),
              MIME"text/latex"(), MIME"text/markdown"()]
        showable(m, x) && (out[m] = stringmime(m, x, context = context))
    end
    return out
end

"""
    struct Default{T}

Internal wrapper type that is meant to be used in situations where it is necessary to
distinguish whether the user explicitly passed the same value as the default value to a
keyword argument, or whether the keyword argument was not passed at all.

```julia
function foo(; kwarg = Default("default value"))
    if isa(kwarg, Default)
        # User did not explicitly pass a value for kwarg
    else kwarg === "default value"
        # User passed "default value" explicitly
    end
end
```
"""
struct Default{T}
    value :: T
end
Base.getindex(default::Default) = default.value

"""
    $(SIGNATURES)

Extracts the language identifier from the info string of a Markdown code block.
"""
function codelang(infostring::AbstractString)
    m = match(r"^\s*(\S*)", infostring)
    return m[1]
end

function get_sandbox_module!(meta, prefix, name = nothing)
    sym = if name === nothing || isempty(name)
        Symbol("__", prefix, "__", lstrip(string(gensym()), '#'))
    else
        Symbol("__", prefix, "__named__", name)
    end
    # Either fetch and return an existing sandbox from the meta dictionary (based on the generated name),
    # or initialize a new clean one, which gets stored in meta for future re-use.
    get!(meta, sym) do
        # If the module does not exists already, we need to construct a new one.
        m = Module(sym)
        # eval(expr) is available in the REPL (i.e. Main) so we emulate that for the sandbox
        Core.eval(m, :(eval(x) = Core.eval($m, x)))
        # modules created with Module() does not have include defined
        Core.eval(m, :(include(x) = Base.include($m, abspath(x))))
        return m
    end
end

"""
    is_strict(strict, val::Symbol) -> Bool

Internal function to check if `strict` is strict about `val`, i.e.
if errors of type `val` should be fatal, according
to the setting `strict` (as a keyword to `makedocs`).

Single-argument `is_strict(strict)` provides a curried function.
"""
is_strict

is_strict(strict::Bool, ::Symbol) = strict
is_strict(strict::Symbol, val::Symbol) = strict === val
is_strict(strict::Vector{Symbol}, val::Symbol) = val ∈ strict
is_strict(strict) = Base.Fix1(is_strict, strict)

"""
    check_strict_kw(strict) -> Nothing

Internal function to check if `strict` is a valid value for
the keyword argument `strict` to `makedocs.` Throws an
`ArgumentError` if it is not valid.
"""
check_strict_kw

check_strict_kw(::Bool) = nothing
check_strict_kw(s::Symbol) = check_strict_kw(tuple(s))
function check_strict_kw(strict)
    extra_names = setdiff(strict, ERROR_NAMES)
    if !isempty(extra_names)
        throw(ArgumentError("""
        Keyword argument `strict` given unknown values: $(extra_names)

        Valid options are: $(ERROR_NAMES)
        """))
    end
    return nothing
end

"""
Calls `git remote show \$(remotename)` to try to determine the main (development) branch
of the remote repository. Returns `master` and prints a warning if it was unable to figure
it out automatically.

`root` is the the directory where `git` gets run. `varname` is just informational and used
to construct the warning messages.
"""
function git_remote_head_branch(varname, root; remotename = "origin", fallback = "master")
    gitcmd = git(nothrow = true)
    if gitcmd === nothing
        @warn """
        Unable to determine $(varname) from remote HEAD branch, defaulting to "$(fallback)".
        Unable to find the `git` binary. Unless this is due to a configuration error, the
        relevant variable should be set explicitly.
        """
        return fallback
    end
    # We need to do addenv() here to merge the new variables with the environment set by
    # Git_jll and the git() function.
    cmd = addenv(
        setenv(`$gitcmd remote show $(remotename)`, dir=root),
        "GIT_TERMINAL_PROMPT" => "0",
        "GIT_SSH_COMMAND" => get(ENV, "GIT_SSH_COMMAND", "ssh -o \"BatchMode yes\""),
    )
    stderr_output = IOBuffer()
    git_remote_output = try
        read(pipeline(cmd; stderr = stderr_output), String)
    catch e
        @warn """
        Unable to determine $(varname) from remote HEAD branch, defaulting to "$(fallback)".
        Calling `git remote` failed with an exception. Set JULIA_DEBUG=Documenter to see the error.
        Unless this is due to a configuration error, the relevant variable should be set explicitly.
        """
        @debug "Command: $cmd" exception = (e, catch_backtrace()) stderr = String(take!(stderr_output))
        return fallback
    end
    m = match(r"^\s*HEAD branch:\s*(.*)$"m, git_remote_output)
    if m === nothing
        @warn """
        Unable to determine $(varname) from remote HEAD branch, defaulting to "$(fallback)".
        Failed to parse the `git remote` output. Set JULIA_DEBUG=Documenter to see the output.
        Unless this is due to a configuration error, the relevant variable should be set explicitly.
        """
        @debug """
        stdout from $cmd:
        $(git_remote_output)
        """
        fallback
    else
        String(m[1])
    end
end

# Check global draft setting
is_draft(doc) = doc.user.draft
# Check if the page is built with draft mode
function is_draft(doc, page)::Bool
    # Check both Draft and draft from @meta block
    return get(page.globals.meta, :Draft, get(page.globals.meta, :draft, is_draft(doc)))
end

## Markdown Utilities.

# Remove all header nodes from a markdown object and replace them with bold font.
# Only for use in `text/plain` output, since we'll use some css to make these less obtrusive
# in the HTML rendering instead of using this hack.
function dropheaders(md::Markdown.MD)
    out = Markdown.MD()
    out.meta = md.meta
    out.content = map(dropheaders, md.content)
    out
end
dropheaders(h::Markdown.Header) = Markdown.Paragraph([Markdown.Bold(h.text)])
dropheaders(v::Vector) = map(dropheaders, v)
dropheaders(other) = other

function git(; nothrow = false, kwargs...)
    system_git_path = Sys.which("git")
    if system_git_path === nothing
        return nothrow ? nothing : error("Unable to find `git`")
    end
    # According to the Git man page, the default GIT_TEMPLATE_DIR is at /usr/share/git-core/templates
    # We need to set this to something so that Git wouldn't pick up the user
    # templates (e.g. from init.templateDir config).
    return addenv(`$(system_git_path)`, "GIT_TEMPLATE_DIR" => "/usr/share/git-core/templates")
end

include("DOM.jl")
include("MDFlatten.jl")
include("TextDiff.jl")
include("Selectors.jl")
include("JSDependencies.jl")

end
