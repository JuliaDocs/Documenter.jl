using Base.Meta
import Base: isdeprecated, Docs.Binding
using DocStringExtensions: SIGNATURES, TYPEDSIGNATURES
import Markdown, MarkdownAST, LibGit2
import Base64: stringmime


using .Remotes: Remote, repourl, repofile
# These imports are here to support code that still assumes that these names are defined
# in the Utilities module.
using .Remotes: RepoHost, RepoGithub, RepoBitbucket, RepoGitlab, RepoAzureDevOps,
    RepoUnknown, format_commit, format_line, repo_host_from_url, LineRangeFormatting

const original_pwd = Ref{String}()  # for printing relative paths in error messages


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
    isa(tag, QuoteNode) && isa(tag.value, Symbol) || error("invalid call of @docerror: tag=$tag")
    tag.value ∈ ERROR_NAMES || throw(ArgumentError("tag $(tag) is not a valid Documenter error"))
    doc, msg = esc(doc), esc(msg)
    # The `exs` portion can contain variable name / label overrides, i.e. `foo = bar()`
    # We don't want to apply esc() on new labels, since they get printed as expressions then.
    exs = map(exs) do ex
        if isa(ex, Expr) && ex.head == :(=) && ex.args[1] isa Symbol
            ex.args[2:end] .= esc.(ex.args[2:end])
            ex
        else
            esc(ex)
        end
    end
    return quote
        let doc = $(doc)
            push!(doc.internal.errors, $(tag))
            if is_strict(doc, $(tag))
                @error $(msg) $(exs...)
            else
                @warn $(msg) $(exs...)
            end
        end
    end
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
function locrepr(file, line = nothing)
    basedir = isassigned(original_pwd) ? original_pwd[] : currentdir()
    file = abspath(file)
    str = Base.contractuser(relpath(file, basedir))
    line !== nothing && (str = str * ":$(line.first)-$(line.second)")
    return str
end

# Directory paths.

"""
Returns the current directory.
"""
function currentdir()
    d = Base.source_dir()
    return d === nothing ? pwd() : d
end

"""
Returns the path to the Documenter `assets` directory.
"""
assetsdir() = normpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

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
    s = replace(s, r"&" => "-and-")
    s = replace(s, r"[^\p{L}\p{P}\d\-]+" => "")
    s = strip(replace(s, r"\-\-+" => "-"), '-')
    return s
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
function parseblock(
        code::AbstractString, doc, file; skip = 0, keywords = true, raise = true,
        linenumbernode = nothing
    )
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
                Meta.parse(code, cursor; raise = raise)
            catch err
                @docerror(doc, :parse_error, "failed to parse exception in $(locrepr(file))", exception = err)
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
        exs = Meta.parseall(code; filename = linenumbernode.file).args
        @assert length(exs) == 2 * length(results) "Issue at $linenumbernode:\n$code"
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
            results[i] = (expr, results[i][2])
        end
    end
    return results
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


# Finding submodules.

"""
Returns the set of submodules of a given root module/s.
"""
function submodules(modules::Vector{Module}; ignore = Set{Module}())
    out = Set{Module}()
    for each in modules
        submodules(each, out; ignore = ignore)
    end
    return out
end
function submodules(root::Module, seen = Set{Module}(); ignore = Set{Module}())
    push!(seen, root)
    for name in names(root, all = true)
        if Base.isidentifier(name) && isdefined(root, name) && !isdeprecated(root, name)
            object = getfield(root, name)
            if isa(object, Module) && !(object in seen) && !(object in ignore) && parentmodule(object::Module) == root
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
    binding::Binding
    signature::Type
    noncanonical_extra::Union{String, Nothing}

    function Object(b::Binding, signature::Type, noncanonical_extra = nothing)
        m = nameof(b.mod) === b.var ? parentmodule(b.mod) : b.mod
        return new(Binding(m, b.var), signature, noncanonical_extra)
    end
end

is_canonical(o::Object) = o.noncanonical_extra === nothing

function splitexpr(x::Expr)
    return isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
        isexpr(x, :.) ? (x.args[1], x.args[2]) :
        error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(Main), quot(s)
splitexpr(other) = error("Invalid @var syntax `$other`.")

"""
    object(ex, str)

Returns a expression that, when evaluated, returns an [`Object`](@ref) representing `ex`.
"""
function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 2) && !endswith(str, "()") && (signature = :(Union{}))
    return Expr(:call, Object, binding, signature)
end

function object(qn::QuoteNode, str::AbstractString)
    if haskey(Base.Docs.keywords, qn.value)
        binding = Expr(:call, Binding, Main, qn)
        return Expr(:call, Object, binding, Union{})
    else
        error("'$(qn.value)' is not a documented keyword.")
    end
end

function Base.print(io::IO, obj::Object)
    print(io, obj.binding)
    print_signature(io, obj.signature)
    print_extra(io, obj.noncanonical_extra)
    return
end
print_extra(io::IO, noncanonical_extra::Nothing) = nothing
print_extra(io::IO, noncanonical_extra::String) = print(io, "-", noncanonical_extra)
print_signature(io::IO, signature::Union{Union, Type{Union{}}}) = nothing
print_signature(io::IO, signature) = print(io, '-', signature)

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
    return :(Base.Docs.@doc $ex)
end
docs(qn::QuoteNode, str::AbstractString) = :(Base.Docs.@doc $(qn.value))

"""
Returns the category name of the provided [`Object`](@ref).
"""
doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

function doccat(b::Binding, ::Union{Union, Type{Union{}}})
    if b.mod === Main && haskey(Base.Docs.keywords, b.var)
        return "Keyword"
    elseif startswith(string(b.var), '@')
        return "Macro"
    else
        return doccat(getfield(b.mod, b.var))
    end
end

doccat(b::Binding, ::Type) = "Method"

doccat(::Function) = "Function"
doccat(::Type) = "Type"
doccat(x::UnionAll) = doccat(Base.unwrap_unionall(x))
doccat(::Module) = "Module"
doccat(::Any) = "Constant"

"""
    $(SIGNATURES)

Tries to determine the "root" of the directory hierarchy containing `path`.
Returns the absolute path to the root directory or `nothing` if no root was found.
If `path` is a directory, it may itself already be a root.

The predicate `f` gets called with absolute paths to directories and must return `true`
if the directory is a "root". An example predicate is `is_git_repo_root` that checks if
the directory is a Git repository root.

The `dbdir` keyword argument specifies the name of the directory we are searching for to
determine if this is a repository or not. If there is a file called `dbdir`, then it's
contents is checked under the assumption that it is a Git worktree or a submodule.
"""
function find_root_parent(f, path)
    ispath(path) || throw(ArgumentError("find_root_parent called with non-existent path\n path: $path"))
    path = realpath(path)
    parent_dir = isdir(path) ? path : dirname(path)
    parent_dir_last = ""
    while parent_dir != parent_dir_last
        f(parent_dir) && return parent_dir
        parent_dir, parent_dir_last = dirname(parent_dir), parent_dir
    end
    return nothing
end

"""
    $(SIGNATURES)

Check is `directory` is a Git repository root.

The `dbdir` keyword argument specifies the name of the directory we are searching for to
determine if this is a repository or not. If there is a file called `dbdir`, then it's
contents is checked under the assumption that it is a Git worktree or a submodule.
"""
function is_git_repo_root(directory::AbstractString; dbdir = ".git")
    isdir(directory) || error("is_git_repo_root called with non-directory path: $directory")
    dbdir_path = joinpath(directory, dbdir)
    isdir(dbdir_path) && return true
    if isfile(dbdir_path)
        contents = chomp(read(dbdir_path, String))
        if startswith(contents, "gitdir: ")
            if isdir(joinpath(directory, contents[9:end]))
                return true
            end
        end
    end
    return false
end

struct RepoCommitError <: Exception
    directory::String
    msg::String
    err_bt::Union{Tuple{Any, Any}, Nothing}
    RepoCommitError(directory::AbstractString, msg::AbstractString) = new(directory, msg, nothing)
    RepoCommitError(directory::AbstractString, msg::AbstractString, e, bt) = new(directory, msg, (e, bt))
end

function repo_commit(repository_root::AbstractString)
    isdir(repository_root) || throw(RepoCommitError(repository_root, "repository_root not a directory"))
    return cd(repository_root) do
        try
            toplevel = readchomp(`$(git()) rev-parse --show-toplevel`)
            if !ispath(toplevel)
                throw(RepoCommitError(repository_root, "`git rev-parse --show-toplevel` returned invalid path: $toplevel"))
            end
            if realpath(toplevel) != realpath(repository_root)
                throw(
                    RepoCommitError(
                        repository_root,
                        """
                        repository_root is not the top-level of the repository
                          `git rev-parse --show-toplevel`: $toplevel
                          repository_root: $repository_root
                        """
                    )
                )
            end
        catch e
            isa(e, RepoCommitError) && rethrow(e)
            throw(RepoCommitError(repository_root, "`git rev-parse --show-toplevel` failed", e, catch_backtrace()))
        end
        try
            readchomp(`$(git()) rev-parse HEAD`)
        catch e
            throw(RepoCommitError(repository_root, "`git rev-parse HEAD` failed", e, catch_backtrace()))
        end
    end
end

"""
A [`Remote`](@ref) corresponding to the main Julia language repository.
"""
const julia_remote = Remotes.GitHub("JuliaLang", "julia")

"""
Stores the memoized results of [`getremote`](@ref).
"""
const GIT_REMOTE_CACHE = Dict{String, Union{Remotes.Remote, Nothing}}()

function parse_remote_url(remote::AbstractString)
    # TODO: we only match for GitHub repositories automatically. Could we engineer a
    # system where, if there is a user-created Remote, the user could also define a
    # matching function here that tries to interpret other URLs?
    m = match(LibGit2.GITHUB_REGEX, remote)
    isnothing(m) && return nothing
    return Remotes.GitHub(m[2], m[3])
end

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
            readchomp(setenv(`$(git()) config --get remote.origin.url`; dir = dir))
        catch e
            @debug "git config --get remote.origin.url failed" exception = (e, catch_backtrace())
            ""
        end
        return parse_remote_url(remote)
    end
end

function inbase(m::Module)
    if m ≡ Base
        return true
    else
        parent = parentmodule(m)
        return parent ≡ m ? false : inbase(parent)
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
function mdparse(s::AbstractString; mode = :single)::Vector{MarkdownAST.Node{Nothing}}
    mode in [:single, :blocks, :span] || throw(ArgumentError("Invalid mode keyword $(mode)"))
    mdast = convert(MarkdownAST.Node, Markdown.parse(s))
    if mode == :blocks
        return MarkdownAST.unlink!.(mdast.children)
    elseif length(mdast.children) == 0
        # case where s == "". We'll just return an empty string / paragraph.
        if mode == :single
            return [
                MarkdownAST.@ast(
                    MarkdownAST.Paragraph() do
                        ""
                    end
                ),
            ]
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
    out = Dict{MIME, Any}()
    x === nothing && return out
    # Always generate text/plain
    out[MIME"text/plain"()] = limitstringmime(MIME"text/plain"(), x, context = context)
    for m in [
            MIME"text/html"(), MIME"image/svg+xml"(), MIME"image/png"(),
            MIME"image/webp"(), MIME"image/gif"(), MIME"image/jpeg"(),
            MIME"text/latex"(), MIME"text/markdown"(),
        ]
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
    value::T
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

function get_sandbox_module!(meta, prefix, name = nothing; share_default_module = false)
    sym = if name === nothing || isempty(name)
        if share_default_module
            Symbol("__", prefix, "__share_default_module__")
        else
            Symbol("__", prefix, "__", lstrip(string(gensym()), '#'))
        end
    else
        Symbol("__", prefix, "__named__", name)
    end
    # Either fetch and return an existing sandbox from the meta dictionary (based on the generated name),
    # or initialize a new clean one, which gets stored in meta for future re-use.
    return get!(meta, sym) do
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
        setenv(`$gitcmd remote show $(remotename)`, dir = root),
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
        return fallback
    else
        return String(m[1])
    end
end

# Check global draft setting
is_draft(doc) = doc.user.draft
# Check if the page is built with draft mode
function is_draft(doc, page)::Bool
    # Check both Draft and draft from @meta block
    return get(page.globals.meta, :Draft, get(page.globals.meta, :draft, is_draft(doc)))
end

function git(; nothrow = false, kwargs...)
    # DOCUMENTER_KEY etc are never needed for git operations
    cmd = addenv(Git.git(), NO_KEY_ENV)
    if Sys.iswindows()
        cmd = addenv(
            cmd,
            # For deploydocs() in particular, we need to use symlinks, but it looks like those
            # need to be explicitly force-enabled on Windows. So we make sure that we configure
            # core.symlinks=true via environment variables on that platform.
            "GIT_CONFIG_COUNT" => "1",
            "GIT_CONFIG_KEY_0" => "core.symlinks",
            "GIT_CONFIG_VALUE_0" => "true",
            # Previously we used to set GIT_TEMPLATE_DIR=/usr/share/git-core/templates on all platforms.
            # This was so that we wouldn't pick up the user's Git configuration. Git.jl, however, points
            # the GIT_TEMPLATE_DIR to the artifact directory, and so we're mostly fine without setting
            # now.. _except_ on Windows, where it doesn't set it. So we still set the environment variable
            # on Windows, just in case.
            "GIT_TEMPLATE_DIR" => "/usr/share/git-core/templates",
        )
    end
    return cmd
end

function remove_common_backtrace(bt, reference_bt = backtrace())
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
    return bt[1:(cutoff === nothing ? 0 : cutoff)]
end
