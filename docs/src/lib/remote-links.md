# Remote repository links

Documenter, if set up appropriately, can automatically generate links to publicly hosted Git repositories (such as source and edit links to e.g. repositories hosted on GitHub).
Usually this is for linking back to the main package repository or the project source code.

The [`Remotes` API](@ref remotes-api) is used to specify remote repositories and generate the URLs.
It is also designed to be extended, to support additional Git repository hosting services.

## Remote link types

There are two categories of remote repositories that (may) need to be configured for Documenter to be able to determine remote URLs:

1. **Project repository remote**, specified with the `repo` keyword to [`makedocs`](@ref).
   This refers to the project as a whole (rather than specific files), and is used for the repository landing page link, issue references etc.

2. **File link remotes**, specified by the `remotes` keyword to [`makedocs`](@ref).
   These are used to link a file system file to the corresponding file in the remote repository.
   In particular, these are used to generate the edit links for manual pages, and Julia source file links for docstrings.

For the most common case -- a repository of a simple Julia package -- there is usually only one remote repository that one links to, and the distinction between file links and repository links is not relevant.
However, in more complex setups it may be necessary to distinguish between the two cases.
The defaults to the two keywords try to cater for the most common use case, and [as is explained below](@ref repo-remote-interaction), this means that there has to be some interaction between these two arguments.

## [Remotes for files](@id remotes-for-files)

When Documenter has to determine the URL of a file in the hosted repository, it gets a local filesystem absolute path as an input.[^1]
In the case of Markdown files, those local paths are determined by [`makedocs`](@ref) when it reads them.
The links to Julia files are determined from the docsystem, and point to where the code was loaded from (e.g. for a development dependency of the environment, they come from the `Pkg.develop`ed path; but for normal `Pkg.add` dependencies the source files are usually in `~/.julia/packages`).

In most cases, for both Markdown and Julia files, the files Documenter is concerned about are located in the currently checked out Git repository that contains the Documenter `make.jl` script (e.g. the locally checked out package repository).
However, sometimes they may also be in a different repository (either in a subdirectory of or outside of the primary repository), or even in a non-Git directory outside of the primary repository (e.g. if you're trying to build the documentation of a release tarball).

To handle those cases, the `remotes` keyword to [`makedocs`](@ref) can be used to set up a `local directory => remote repository` mapping for local file system paths.
The local directory is assumed to correspond to the root of the Git repository, and any subpath within that directory is then resolved to the corresponding path in the remote repository.
If there are nested `remotes` configured, Documenter will use the one that matches first as it walks up the directory tree from the original path.

As the common cases are a locally checked out Git repository (added with `Pkg.develop` to the docs environment), or a released package which is hosted on GitHub (`Pkg.add`ed to the environment), Documenter will also try to determine such remotes automatically.

* When Documenter walks up the directory tree, it checks whether the directory is a root of a Git repository (by looking for the presence of a `.git` directory or file).
  Once it finds a valid local repository root, it tries to read its [`origin` remote URL](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes).
  - If that matches a GitHub repository[^2], Documenter automatically sets up a mapping from that directory, and then uses that to determine the remote URLs.
  - If Documenter is unable to determine the remote from the repository's `origin` (e.g. `origin` is not set up, or it is hosted somewhere else), it will error, as it will not be able to determine the remote URLs.
    In this case, the remote should be configured explicitly with `remotes`.

You can think of it as Documenter automatically populating `remotes` with any cloned GitHub repositories it finds.[^3]

For released packages (those added using `Pkg.add(...)` rather than `Pkg.develop(...)`), the version and repository can be determined from the package metadata, but a commit hash is not readily available.
In this case, Documenter will guess that a tag `v$VERSION` exists in the repository on GitHub.
Note that these tags are created automatically by the widely used JuliaRegistries/TagBot action.
Since this is sometimes not the case, and could cause dead or incorrect links, setting the `linkcheck` keyword to `true` to [`makedocs`](@ref) will check these guessed links have an existing target and that the existing target matches the published package.
(Note this will also all other external links from your documentation.)
Note that enabling this option can cause documentation builds to fail due to network errors or intermittent downtime of external services.

!!! note

    The [`Remotes` API](@ref remotes-api) can be used to implement the methods to compute the remote URLs (for now, Documenter only supports [GitHub](@ref Remotes.GitHub) and [GitLab](@ref Remotes.GitLab) natively).

[^1]: There is an exception to this: links to Julia `Base` module source files.
      But Documenter already known how to handle those correctly, and they are really only relevant to the Julia main manual build.
[^2]: GitHub is the most common case, but this could be extended to cover other Git hosting services in the future (as long as the remote can reliably determined from the `origin` URL).
[^3]: One thing to be aware here is that Documenter builds up a cache of the Git repositories it finds on every `makedocs` call.
      This is for performance reasons, to reduce the number of file system accesses and, in particular, `git` calls, which are relatively slow.

## [`repo` & `remotes` interaction](@id repo-remote-interaction)

Since Documenter is primarily used to generate documentation for Julia packages, there is some interaction between the `repo` and `remotes` keyword arguments, to automagically determine their defaults.
This means that usually it is not necessary to specify either explicitly in the `make.jl` script.

The rules are as follows:

* If `repo` _is not_ specified, it is essentially [determined like any other remote link](@ref remotes-for-files), by trying to figure out the repository that contains the `root` path argument of [`makedocs`](@ref) (defaulting to the directory of the `make.jl` script; usually the `docs/` directory).
  The [`Remote`](@ref Remotes.Remote) object will one of the `remotes`, which in turn may have been determined automatically via the `origin` URL of the containing Git repository.

* If `repo` _is_ specified, but the `remotes` for the repository root is not, `repo` will function as a `remotes` entry for the repository root.
  This is so that it would not be necessary to specify the same argument twice (i.e. once for general repository links, once for file links).

* If both `repo` and a `remotes` for the repository root are configured, Documenter will throw an error, as it does not really make sense for them to point to two different remotes.[^4]

[^4]: If there is a use case for this, this limitation could be relaxed in the future.

## [Remotes API](@id remotes-api)

```@docs
Documenter.Remotes
Documenter.Remotes.GitHub
Documenter.Remotes.GitLab
```

The following types and functions and relevant when creating custom
[`Remote`](@ref Documenter.Remotes.Remote) types:

```@docs
Documenter.Remotes.Remote
Documenter.Remotes.repourl
Documenter.Remotes.fileurl
Documenter.Remotes.issueurl
```
