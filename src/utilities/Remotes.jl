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

When implementing a new type `T <: Remote`, the following functions must be extended for
that type:

* [`Remotes.repourl`](@ref)
* [`Remotes.fileurl`](@ref)

Additionally, it may also extend the following functions:

* [`Remotes.issueurl`](@ref)
"""
abstract type Remote end

"""
    Remotes.repourl(remote::T) -> String

An internal Documenter function that **must** be extended when implementing a user-defined
[`Remote`](@ref). It should return a string pointing to the landing page of the remote
repository. E.g. for [`GitHub`](@ref) it returns `"https://github.com/USER/REPO/"`.
"""
function repourl end

"""
    Remotes.fileurl(remote::T, ref, filename, linerange) -> String

An internal Documenter function that **must** be extended when implementing a user-defined
[`Remote`](@ref). Should return the full remote URL to the source file `filename`,
optionally including the line numbers.

* **`ref`** is string containing the Git reference, such as a commit SHA, branch name or a tag
  name.

* **`filename`** is a string containing the full path of the file in the repository without any
  leading `/` characters.

* **`linerange`** either specifies a range of integers or is `nothing`. In the former case it
  either specifies a line number (if `first(linerange) == last(linerange)`) or a range of
  lines (`first(linerange) < last(linerange)`). The line information should be accessed only
  with the `first` and `last` functions (no other interface guarantees are made).

  If `linerange` is `nothing`, the line numbers should be omitted and the returned URL
  should refer to the full file.

  It is also acceptable for an implementation to completely ignore the value of the
  `linerange` argument, e.g. when the remote repository does not support direct links to
  particular line numbers.

E.g. for [`GitHub`](@ref), depending on the input arguments, it would return the following
strings:

| `ref`       | `filename`     | `linerange` | returned string                                                 |
| ----------- | -------------- | ----------- | :-------------------------------------------------------------- |
| `"master"`  | `"foo/bar.jl"` | `nothing`   | `"https://github.com/USER/REPO/blob/master/foo/bar.jl"`         |
| `"v1.2.3"`  | `"foo/bar.jl"` | `12:12`     | `"https://github.com/USER/REPO/blob/v1.2.3/foo/bar.jl#L12"`     |
| `"xyz/foo"` | `"README.md"`  | `10:15`     | `"https://github.com/USER/REPO/blob/xyz/foo/README.md#L10-L15"` |
"""
function fileurl end

"""
    Remotes.issueurl(remote::T, issuenumber)

An internal Documenter function that can be extended when implementing a user-defined
[`Remote`](@ref). It should return a string with the full URL to an issue referenced by
`issuenumber`, or `nothing` if it is not possible to determine such a URL.

* **`issuenumber`** is a string containing the issue number.

It is not mandatory to define this method for a custom [`Remote`](@ref). In this case it
just falls back to always returning `nothing`.

E.g. for [`GitHub`](@ref) when `issuenumber = "123"`, it would return
`"https://github.com/USER/REPO/issues/123"`.
"""
function issueurl end
# Generic fallback always returning nothing
issueurl(::Remote, ::Any) = nothing

"""
    repofile(remote::Remote, ref, filename, linerange=nothing)

Documenter's internal version of `fileurl`, which sanitizes the inputs before they are passed
to the potentially user-defined `fileurl` implementations.
"""
function repofile(remote::Remote, ref, filename, linerange = nothing)
    # sanitize the file name
    filename = replace(filename, '\\' => '/') # remove backslashes on Windows
    filename = lstrip(filename, '/') # remove leading spaces
    # Only pass UnitRanges to user code (even though we require the users to support any
    # collection supporting first/last).
    return fileurl(remote, ref, filename, isnothing(linerange) ? nothing : Int(first(linerange)):Int(last(linerange)))
end

"""
    GitHub(user :: AbstractString, repo :: AbstractString)
    GitHub(remote :: AbstractString)

Represents a remote Git repository hosted on GitHub. The repository is identified by the
names of the user (or organization) and the repository: `GitHub(user, repository)`. E.g.:

```julia
makedocs(
    repo = GitHub("JuliaDocs", "Documenter.jl")
)
```

The single-argument constructor assumes that the user and repository parts are separated by
a slash (e.g. `JuliaDocs/Documenter.jl`).
"""
struct GitHub <: Remote
    user::String
    repo::String
end
function GitHub(remote::AbstractString)
    user, repo = split(remote, '/')
    return GitHub(user, repo)
end
repourl(remote::GitHub) = "https://github.com/$(remote.user)/$(remote.repo)"
function fileurl(remote::GitHub, ref::AbstractString, filename::AbstractString, linerange)
    url = "$(repourl(remote))/blob/$(ref)/$(filename)"
    isnothing(linerange) && return url
    lstart, lend = first(linerange), last(linerange)
    return (lstart == lend) ? "$(url)#L$(lstart)" : "$(url)#L$(lstart)-L$(lend)"
end
issueurl(remote::GitHub, issuenumber) = "$(repourl(remote))/issues/$issuenumber"

"""
    GitLab(host, user, repo)
    GitLab(user, repo)
    GitLab(remote)

Represents a remote Git repository hosted on GitLab. The repository is
identified by the host, name of the user (or organization), and the
repository. For example:

```julia
makedocs(
    repo = GitLab("JuliaDocs", "Documenter.jl")
)
```

The single argument constructor assumes that the end user and
repository parts are separated by a slash (e.g.,
`JuliaDocs/Documenter.jl`).
"""
struct GitLab <: Remote
    host::String
    user::String
    repo::String
end
GitLab(user::AbstractString, repo::AbstractString) = GitLab("gitlab.com", user, repo)
function GitLab(remote::AbstractString)
    user, repo = split(remote, '/')
    return GitLab(user, repo)
end
repourl(remote::GitLab) = "https://$(remote.host)/$(remote.user)/$(remote.repo)"
function fileurl(remote::GitLab, ref::AbstractString, filename::AbstractString, linerange)
    url = "$(repourl(remote))/-/tree/$(ref)/$(filename)"
    isnothing(linerange) && return url
    lstart, lend = first(linerange), last(linerange)
    return (lstart == lend) ? "$(url)#L$(lstart)" : "$(url)#L$(lstart)-L$(lend)"
end
issueurl(remote::GitLab, issuenumber) = "$(repourl(remote))/-/issues/$issuenumber"

############################################################################
# Handling of URL string templates (deprecated, for backwards compatibility)
#
"""
    URL(urltemplate, repourl=nothing)

A [`Remote`](@ref) type used internally in Documenter when the user passes a URL template
string as the `repo` argument. Will return `nothing` from `repourl` if the optional
`repourl` argument is not passed.

Can contain the following template sections that Documenter will replace:

* `{commit}`: replaced by the commit SHA, branch or tag name
* `{path}`: replaced by the path of the file, relative to the repository root
* `{line}`: replaced by the line (or line range) reference

For example, the template URLs might look something like:

* GitLab:
  ```
  https://gitlab.com/user/project/-/tree/{commit}{path}#{line}
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
    urltemplate::String
    repourl::Union{String, Nothing}
    URL(urltemplate, repourl = nothing) = new(urltemplate, repourl)
end
repourl(remote::URL) = remote.repourl
function fileurl(remote::URL, ref, filename, linerange)
    hosttype = repo_host_from_url(remote.urltemplate)
    lines = (linerange === nothing) ? "" : format_line(linerange, LineRangeFormatting(hosttype))
    ref = format_commit(ref, hosttype)
    # lines = if linerange !== nothing
    # end
    s = replace(remote.urltemplate, "{commit}" => ref)
    # template strings assume that {path} has a leading / whereas filename does not
    s = replace(s, "{path}" => "/$(filename)")
    return replace(s, "{line}" => lines)
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
repo_host_from_url(::GitHub) = RepoGithub
repo_host_from_url(remote::Remote) = repo_host_from_url(Remotes.repourl(remote))
repo_host_from_url(::Nothing) = RepoUnknown

function format_commit(commit::AbstractString, host::RepoHost)
    if host === RepoAzureDevOps
        # if commit hash then preceded by GC, if branch name then preceded by GB
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
            return new("&line=", "&lineEnd=")
        elseif host == RepoBitbucket
            return new("", ":")
        elseif host == RepoGitlab
            return new("L", "-")
        else
            # default is github-style
            return new("L", "-L")
        end
    end
end

function format_line(range::AbstractRange, format::LineRangeFormatting)
    if length(range) <= 1
        return string(format.prefix, first(range))
    else
        return string(format.prefix, first(range), format.separator, last(range))
    end
end

end
