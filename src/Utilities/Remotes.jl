"""
Types and functions for handling repository remotes.
"""
module Remotes

"""
    abstract type Remote

Abstract supertype for implementing additional remote repositories that Documenter can use
when generating links to files hosted on Git hosting service (such as GitHub, GitLab etc).
For custom or less common Git hosting services, the user can create their own `Remote`
subtype and pass that as the `repo` argument to [`makedocs`](@ref Main.Documenter.makedocs).

When implementing a new type `T <: Remote`, the following methods should be defined for that
type:

* ```julia
  Remotes.repourl(remote::T) -> String
  ```

  Should return a string pointing to the landing page of the remote repository.

  E.g. for GitHub it should return `https://github.com/USER/REPO/`.

* ```julia
  Remotes.fileurl(remote::T, ref::String, filename::String) -> String
  ```

  Should return the full remote URL to the source file `filename`. `ref` is the Git reference
  such as a commit SHA, branch name or a tag name. `filename` will contain the full path of
  the file in the repository without any leading `/` characters.

  E.g. for GitHub, for `ref="master"` and `filename="foo/bar.jl"` it should return
  `https://github.com/USER/REPO/blob/master/foo/bar.jl`.

* ```julia
  Remotes.fileurl(remote::T, ref::String, filename::String, linerange::UnitRange{Int}) -> String
  ```

  Like the the other `fileurl` method, but allows the specification of the line number (if
  `first(linerange) == last(linerange)`) or a range of lines. Should return the full URL,
  including the line numbers.

  Implementing this method is optional. If it is not implemented, Documenter will fall back
  to `Remotes.fileurl(remote, ref, filename)` and resulting links will not refer to specific
  lines.

  E.g. for GitHub, for `ref="master"`, `filename="foo/bar.jl"` and `linerange=12:12` it
  would return `https://github.com/USER/REPO/blob/master/foo/bar.jl#L12`.

To avoid duplication, it is a good idea if the `fileurl` implementation(s) call the
corresponding `repourl` implementation to determine the root part of the URL.
"""
abstract type Remote end
function repourl end
fileurl(remote::Remote, ref, filename, linerange) = fileurl(remote, ref, filename)

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
repourl(remote::GitHub) = "https://github.com/$(remote.user)/$(remote.repo)"
fileurl(remote::GitHub, ref::AbstractString, filename::AbstractString) = "$(repourl(remote))/blob/$(ref)/$(filename)"
function fileurl(remote::GitHub, ref::AbstractString, filename::AbstractString, linerange::UnitRange{Int})
    url = fileurl(remote, ref, filename)
    lstart, lend = first(linerange), last(linerange)
    (lstart == lend) ? "$(url)#L$(lstart)" : "$(url)#L$(lstart)-L$(lend)"
end

"""
    repofile(remote::Remote, ref, filename, linerange=nothing)

Documenter's internal version of `fileurl`, which sanitizes the inputs before they are passed
to the potentially user-defined `fileurl` implementations.
"""
function repofile(remote::Remote, ref, filename, linerange=nothing)
    # sanitize the file name
    filename = replace(filename, '\\' => '/') # remove backslashes on Windows
    filename = lstrip(filename, '/') # remove leading spaces
    if linerange === nothing
        fileurl(remote, ref, filename)
    else
        fileurl(remote, ref, filename, Int(first(linerange)):Int(last(linerange)))
    end
end

"""
A [`Remote`](@ref) corresponding to the main Julia language repository.
"""
const julia = GitHub("JuliaLang", "julia")

############################################################################
# Handling of URL string templates (deprecated, for backwards compatibility)
#
"""
    struct URL <: Remote

A [`Remote`](@ref) type used internally in Documenter when the user passes a URL template
string as the `repo` argument.

Can contain the following template sections that Documenter will replace:

* `{commit}`: replaced by the commit SHA, branch or tag name
* `{path}`: replaced by the path of the file, relative to the repository root
* `{line}`: replaced by the line (or line range) reference

For example, the template URLs might look something like:

* GitLab:
  ```
  https://gitlab.com/user/project/blob/{commit}{path}#{line}
  ```
* Azure DevOps:
  ```
  https://dev.azure.com/org/project/_git/repo?path={path}&version={commit}{line}&lineStartColumn=1&lineEndColumn=1
  ```
* BitBucket:
  ```
  https://bitbucket.org/user/project/src/{commit}/{path}#lines-{line}
  ```

However, an explicit [`Remote`](@ref) object is preferred over using a template string when
configuring Documenter.
"""
struct URL <: Remote
    urltemplate :: String
    repourl :: Union{String, Nothing}
    URL(urltemplate, repourl=nothing) = new(urltemplate, repourl)
end
repourl(remote::URL) = remote.repourl
function fileurl(remote::URL, ref, filename, linerange=nothing)
    hosttype = repo_host_from_url(remote.urltemplate)
    lines = (linerange === nothing) ? "" : format_line(linerange, LineRangeFormatting(hosttype))
    ref = format_commit(hosttype, ref)
    # lines = if linerange !== nothing
    # end
    s = replace(remote.urltemplate, "{commit}" => ref)
    s = replace(s, "{path}" => filename)
    replace(s, "{line}" => lines)
end

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
repo_host_from_url(remote::Remotes.Remote) = (remote isa Remotes.GitHub) ? RepoGithub : Remotes.repourl(remote)

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

end
