"""
Contains types and functions for handing repository remotes.
"""
module Remotes

# TODO: Remove this -- it's not used anywhere anymore
# Repository hosts
#   RepoUnknown denotes that the repository type could not be determined automatically
@enum RepoHost RepoGithub RepoBitbucket RepoGitlab RepoAzureDevOps RepoUnknown

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
    elseif occursin("azure", repoURL)
        return RepoAzureDevOps
    else
        return RepoUnknown
    end
end

struct LineRangeFormatting
    prefix::String
    separator::String

    function LineRangeFormatting(host::RepoHost)
        if host === RepoAzureDevOps
            new("&line=", "&lineEnd=")
        elseif host == RepoBitbucket
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

function format_commit(host::RepoHost, commit::AbstractString)
    if host === RepoAzureDevOps
        # if commit hash then preceeded by GC, if branch name then preceeded by GB
        if match(r"[0-9a-fA-F]{40}", commit) !== nothing
            commit = "GC$commit"
        else
            commit = "GB$commit"
        end
    else
        return commit
    end
end

"""
    abstract type Remote

Abstract supertype for implementing additional remote repositories that Documenter can use
when generating links to files hosted on Git hosting service (such as GitHub, GitLab etc).
For custom or less common Git hosting services, the user can create their own
`Remote` subtype and pass that as the `repo` argument to [`makedocs`](@ref).

When implementing a new type `T <: Remote`, the following methods should be defined for that
type:

* ```julia
  Documents._fileurl(remote::T, ref::String, filename::String) -> String
  ```

  Should return the full URL to the source file `filename`. `ref` is the Git reference such
  as a commit SHA, branch name or a tag name. `filename` is guaranteed to start with a `/`.

  E.g. for GitHub, for `ref="master"` and `filename="foo/bar.jl"` it would return
  `https://github.com/USER/REPO/blob/master/foo/bar.jl`.

* ```julia
  Documents._fileurl(remote::T, ref::String, filename::String, linerange::UnitRange{Int}) -> String
  ```

  As the other `_fileurl`, but allows the specification of the line number (if
  `first(linerange) == last(linerange)`) or a range of lines.

  This method is optional -- if it is not implemented, Documenter falls back to the other
  `_fileurl` and the resulting links do not refer to specific lines.

  E.g. for GitHub, for `ref="master"`, `filename="foo/bar.jl"` and `linerange=12:12` it
  would return `https://github.com/USER/REPO/blob/master/foo/bar.jl#L12`.

* ```julia
  Documents._repourl(remote::T) -> String
  ```

  Should return a string pointing to the landing page of the remote repository.

  E.g. for GitHub it would return `https://github.com/USER/REPO/`.
"""
abstract type Remote end
function _repourl end
_fileurl(remote::Remote, ref, filename, linerange) = _fileurl(remote, ref, filename)

repourl(remote::Remote) = _repourl(remote)
function repofile(remote::Remote, ref, filename, linerange=nothing)
     # sanitize the file name
    filename = startswith(filename, '/') ? filename : "/$(filename)"
    filename = replace(filename, '\\' => '/') # remove backslashes on Windows
    if linerange === nothing
        _fileurl(remote, ref, filename)
    else
        _fileurl(remote, ref, filename, Int(first(linerange)):Int(last(linerange)))
    end
end

"""
    struct GitHub <: Remote

Represents a remote Git repository hosted on GitHub. The repository is identified by the
names of the user (or organization) and the repository: `GitHub(user, repository)`. E.g.:

```julia
makedocs(
    repo = GitHub("JuliaDocs", "Documenter.jl")
)
```
"""
struct GitHub <: Remote
    user :: String
    repo :: String
end
function GitHub(remote::AbstractString)
    user, repo = split(remote, '/')
    GitHub(user, repo)
end
_repourl(remote::GitHub) = "https://github.com/$(remote.user)/$(remote.repo)"
_fileurl(remote::GitHub, ref::AbstractString, filename::AbstractString) = "$(_repourl(remote))/blob/$(ref)$(filename)"
function _fileurl(remote::GitHub, ref::AbstractString, filename::AbstractString, linerange::UnitRange{Int})
    fileurl = _fileurl(remote, ref, filename)
    lstart, lend = first(linerange), last(linerange)
    (lstart == lend) ? "$(fileurl)#L$(lstart)" : "$(fileurl)#L$(lstart)-L$(lend)"
end

"""
    struct URL <: Remote

A [`Remote`](@ref) type used internally in Documenter when the user passes a string templste
as the `repo` argument.

Can contain the following template sections that Documenter will replace:

* `{commit}`: replaced by the commit SHA, branch or tag name
* `{path}`: replaced by the path of the file, relative to the repository root
* `{line}`: replaced by the line (or line range) reference
"""
struct URL <: Remote
    urltemplate :: String
    repourl :: Union{String, Nothing}
    URL(urltemplate, repourl=nothing) = new(urltemplate, repourl)
end
_repourl(remote::URL) = remote.repourl
function _fileurl(remote::URL, ref, filename, linerange=nothing)
    hosttype = repo_host_from_url(remote.urltemplate)
    lines = (linerange === nothing) ? "" : format_line(linerange, LineRangeFormatting(hosttype))
    ref = format_commit(hosttype, ref)
    # lines = if linerange !== nothing
    # end
    s = replace(remote.urltemplate, "{commit}" => ref)
    s = replace(s, "{path}" => filename)
    replace(s, "{line}" => lines)
end

const julia = GitHub("JuliaLang", "julia")

end
