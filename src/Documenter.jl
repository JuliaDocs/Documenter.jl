"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`](@ref). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`](@ref). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

$(EXPORTS)

"""
module Documenter

using DocStringExtensions
import Base64: base64decode
import Pkg

# Submodules
# ----------

include("Utilities/Utilities.jl")
include("DocSystem.jl")
include("Formats.jl")
include("Anchors.jl")
include("Documents.jl")
include("Builder.jl")
include("Expanders.jl")
include("CrossReferences.jl")
include("DocTests.jl")
include("DocChecks.jl")
include("Writers/Writers.jl")
include("Deps.jl")

import .Utilities: Selectors


# User Interface.
# ---------------

export Deps, makedocs, deploydocs, hide

"""
    makedocs(
        root    = "<current-directory>",
        source  = "src",
        build   = "build",
        clean   = true,
        doctest = true,
        modules = Module[],
        repo    = "",
    )

Combines markdown files and inline docstrings into an interlinked document.
In most cases [`makedocs`](@ref) should be run from a `make.jl` file:

```julia
using Documenter
makedocs(
    # keywords...
)
```

which is then run from the command line with:

```sh
\$ julia make.jl
```

The folder structure that [`makedocs`](@ref) expects looks like:

    docs/
        build/
        src/
        make.jl

# Keywords

**`root`** is the directory from which `makedocs` should run. When run from a `make.jl` file
this keyword does not need to be set. It is, for the most part, needed when repeatedly
running `makedocs` from the Julia REPL like so:

    julia> makedocs(root = Pkg.dir("MyPackage", "docs"))

**`source`** is the directory, relative to `root`, where the markdown source files are read
from. By convention this folder is called `src`. Note that any non-markdown files stored
in `source` are copied over to the build directory when [`makedocs`](@ref) is run.

**`build`** is the directory, relative to `root`, into which generated files and folders are
written when [`makedocs`](@ref) is run. The name of the build directory is, by convention,
called `build`, though, like with `source`, users are free to change this to anything else
to better suit their project needs.

**`clean`** tells [`makedocs`](@ref) whether to remove all the content from the `build`
folder prior to generating new content from `source`. By default this is set to `true`.

**`doctest`** instructs [`makedocs`](@ref) on whether to try to test Julia code blocks
that are encountered in the generated document. By default this keyword is set to `true`.
Doctesting should only ever be disabled when initially setting up a newly developed package
where the developer is just trying to get their package and documentation structure correct.
After that, it's encouraged to always make sure that documentation examples are runnable and
produce the expected results. See the [Doctests](@ref) manual section for details about
running doctests.

**`modules`** specifies a vector of modules that should be documented in `source`. If any
inline docstrings from those modules are seen to be missing from the generated content then
a warning will be printed during execution of [`makedocs`](@ref). By default no modules are
passed to `modules` and so no warnings will appear. This setting can be used as an indicator
of the "coverage" of the generated documentation.
For example Documenter's `make.jl` file contains:

```julia
makedocs(
    modules = [Documenter],
    # ...
)
```

and so any docstring from the module `Documenter` that is not spliced into the generated
documentation in `build` will raise a warning.

**`repo`** specifies a template for the "link to source" feature. If you are
using GitHub, this is automatically generated from the remote. If you are using
a different host, you can use this option to tell Documenter how URLs should be
generated. The following placeholders will be replaced with the respective
value of the generated link:

  - `{commit}` Git branch or tag name, or commit hash
  - `{path}` Path to the file in the repository
  - `{line}` Line (or range of lines) in the source file

For example if you are using GitLab.com, you could use

```julia
makedocs(repo = \"https://gitlab.com/user/project/blob/{commit}{path}#{line}\")
```

# Experimental keywords

In addition to standard arguments there is a set of non-finalized experimental keyword
arguments. The behaviour of these may change or they may be removed without deprecation
when a minor version changes (i.e. except in patch releases).

**`checkdocs`** instructs [`makedocs`](@ref) to check whether all names within the modules
defined in the `modules` keyword that have a docstring attached have the docstring also
listed in the manual (e.g. there's a `@docs` blocks with that docstring). Possible values
are `:all` (check all names) and `:exports` (check only exported names). The default value
is `:none`, in which case no checks are performed. If `strict` is also enabled then the
build will fail if any missing docstrings are encountered.

**`linkcheck`** -- if set to `true` [`makedocs`](@ref) uses `curl` to check the status codes
of external-pointing links, to make sure that they are up-to-date. The links and their
status codes are printed to the standard output. If `strict` is also enabled then the build
will fail if there are any broken (400+ status code) links. Default: `false`.

**`linkcheck_ignore`** allows certain URLs to be ignored in `linkcheck`. The values should
be a list of strings (which get matched exactly) or `Regex` objects. By default nothing is
ignored.

**`strict`** -- [`makedocs`](@ref) fails the build right before rendering if it encountered
any errors with the document in the previous build phases.

## Output formats

**`format`** allows the output format to be specified. Possible values are `:html` (default),
`:latex` and `:markdown`.

Documenter is designed to support multiple output formats. By default it is creates a set of
HTML files, but the output format can be controlled with the `format` keyword. The different
output formats may require additional keywords to be specified. The keywords for the default
HTML output are documented at the [`Writers.HTMLWriter`](@ref) module.

Documenter also has (experimental) support for Markdown and LaTeX / PDF outputs. See the
[Other outputs](@ref) for more information.

!!! warning

    The Markdown and LaTeX output formats will be moved to a separate package in future
    versions of Documenter. Automatic documentation deployments should not rely on it unless
    they fix Documenter to a minor version.

# See Also

A guide detailing how to document a package using Documenter's [`makedocs`](@ref) is provided
in the [Usage](@ref) section of the manual.
"""
function makedocs(; debug = false, args...)
    document = Documents.Document(; args...)
    cd(document.user.root) do
        Selectors.dispatch(Builder.DocumentPipeline, document)
    end
    debug ? document : nothing
end

"""
$(SIGNATURES)

Allows a page to be hidden in the navigation menu. It will only show up if it happens to be
the current page. The hidden page will still be present in the linear page list that can be
accessed via the previous and next page links. The title of the hidden page can be overriden
using the `=>` operator as usual.

# Usage

```julia
makedocs(
    ...,
    pages = [
        ...,
        hide("page1.md"),
        hide("Title" => "page2.md")
    ]
)
```
"""
hide(page::Pair) = (false, page.first, page.second, [])
hide(page::AbstractString) = (false, nothing, page, [])

"""
$(SIGNATURES)

Allows a subsection of pages to be hidden from the navigation menu. `root` will be linked
to in the navigation menu, with the title determined as usual. `children` should be a list
of pages (note that it **can not** be hierarchical).

# Usage

```julia
makedocs(
    ...,
    pages = [
        ...,
        hide("Hidden section" => "hidden_index.md", [
            "hidden1.md",
            "Hidden 2" => "hidden2.md"
        ]),
        hide("hidden_index.md", [...])
    ]
)
```
"""
hide(root::Pair, children) = (true, root.first, root.second, map(hide, children))
hide(root::AbstractString, children) = (true, nothing, root, map(hide, children))

"""
    deploydocs(
        root   = "<current-directory>",
        target = "build",
        repo   = "<required>",
        branch = "gh-pages",
        deps   = nothing | <Function>,
        make   = nothing | <Function>,
        devbranch = "master",
        devurl = "dev",
        versions = ["stable" => "v^", "v#.#", devurl => devurl]
    )

Converts markdown files generated by [`makedocs`](@ref) to HTML and pushes them to `repo`.
This function should be called from within a package's `docs/make.jl` file after the call to
[`makedocs`](@ref), like so

```julia
using Documenter, PACKAGE_NAME
makedocs(
    # options...
)
deploydocs(
    repo = "github.com/..."
)
```

When building the docs for a tag (i.e. a release) the documentation is deployed to
a directory with the tag name (i.e. `vX.Y.Z`) and to the `stable` directory.
Otherwise the docs are deployed to the directory determined by the `devurl` argument.

# Required keyword arguments

**`repo`** is the remote repository where generated HTML content should be pushed to. Do not
specify any protocol - "https://" or "git@" should not be present. This keyword *must*
be set and will throw an error when left undefined. For example this package uses the
following `repo` value:

```julia
repo = "github.com/JuliaDocs/Documenter.jl.git"
```

# Optional keyword arguments

**`root`** has the same purpose as the `root` keyword for [`makedocs`](@ref).

**`target`** is the directory, relative to `root`, where generated content that should be
deployed to `gh-pages` is written to. written to. It should generally be the same as
[`makedocs`](@ref)'s `build` and defaults to `"build"`.

**`branch`** is the branch where the generated documentation is pushed. If the branch does
not exist, a new orphaned branch is created automatically. It defaults to `"gh-pages"`.

**`deps`** is the function used to install any additional dependencies needed to build the
documentation. By default nothing is installed.

It can be used e.g. for a Markdown build. The following example installed the `pygments` and
`mkdocs` Python packages using the [`Deps.pip`](@ref) function:

```julia
deps = Deps.pip("pygments", "mkdocs")
```

**`make`** is the function used to specify an additonal build phase. By default, nothing gets
executed.

**`devbranch`** is the branch that "tracks" the in-development version of the  generated
documentation. By default this value is set to `"master"`.

**`devurl`** the folder that in-development version of the docs will be deployed.
Defaults to `"dev"`.

**`versions`** determines content and order of the resulting version selector in
the generated html. The following entries are valied in the `versions` vector:
 - `"v#"`: includes links to the latest documentation for each major release cycle
   (i.e. `v2.0`, `v1.1`).
 - `"v#.#"`: includes links to the latest documentation for each minor release cycle
   (i.e. `v2.0`, `v1.1`, `v1.0`, `v0.1`).
 - `"v#.#.#"`: includes links to all released versions.
 - `"v^"`: includes a link to the docs for the maximum version
   (i.e. a link `vX.Y` pointing to `vX.Y.Z` for highest `X`, `Y`, `Z`, respectively).
 - A pair, e.g. `"first" => "second"`, which will put `"first"` in the selector,
   and generate a url from which `"second"` can be accessed.
   The second argument can be `"v^"`, to point to the maximum version docs
   (as in e.g. `"stable" => "v^"`).

# See Also

The [Hosting Documentation](@ref) section of the manual provides a step-by-step guide to
using the [`deploydocs`](@ref) function to automatically generate docs and push them to
GitHub.
"""
function deploydocs(;
        root   = Utilities.currentdir(),
        target = "build",
        dirname = "",

        repo   = error("no 'repo' keyword provided."),
        branch = "gh-pages",
        latest::Union{String,Nothing} = nothing, # deprecated

        osname::Union{String,Nothing} = nothing, # deprecated
        julia::Union{String,Nothing} = nothing, # deprecated

        deps   = nothing,
        make   = nothing,

        devbranch = "master",
        devurl = "dev",
        versions = ["stable" => "v^", "v#.#", devurl => devurl]
    )
    # deprecation of latest kwarg (renamed to devbranch)
    if latest !== nothing
        Base.depwarn("The `latest` keyword argument has been renamed to `devbranch`.")
        devbranch = latest
        @info("setting `devbranch` to `$(devbranch)`.")
    end
    # deprecation/removal of `julia` and `osname` kwargs
    if julia !== nothing
        Base.depwarn("the `julia` keyword argument to `Documenter.deploydocs` is " *
            "removed. Use Travis Build Stages for determining from where to deploy instead. " *
            "See the section about Hosting in the Documenter manual for more details.", :deploydocs)
        @info("skipping docs deployment.")
        return
    end
    if osname !== nothing
        Base.depwarn("the `osname` keyword argument to `Documenter.deploydocs` is " *
            "removed. Use Travis Build Stages for determining from where to deploy instead. " *
            "See the section about Hosting in the Documenter manual for more details.", :deploydocs)
        @info("skipping docs deployment.")
        return
    end

    # Get environment variables.
    documenter_key      = get(ENV, "DOCUMENTER_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")


    # Other variables.
    sha = cd(root) do
        # We'll make sure we run the git commands in the source directory (root), in case
        # the working directory has been changed (e.g. if the makedocs' build argument is
        # outside root).
        try
            readchomp(`git rev-parse --short HEAD`)
        catch
            # git rev-parse will throw an error and return code 128 if it is not being
            # run in a git repository, which will make run/readchomp throw an exception.
            # We'll assume that if readchomp fails it is due to this and set the sha
            # variable accordingly.
            "(not-git-repo)"
        end
    end

    # Sanity checks
    if !isempty(travis_repo_slug) && !occursin(travis_repo_slug, repo)
        @warn("repo $repo does not match $travis_repo_slug")
    end

    # When should a deploy be attempted?
    should_deploy =
        occursin(travis_repo_slug, repo) &&
        travis_pull_request == "false"   &&
        (
            travis_branch == devbranch ||
            travis_tag    != ""
        )

    # check that the tag is valid
    if should_deploy && !isempty(travis_tag) && !occursin(Base.VERSION_REGEX, travis_tag)
        @warn("tag `$(travis_tag)` is not a valid VersionNumber")
        should_deploy = false
    end

    # check DOCUMENTER_KEY only if the branch, Julia version etc. check out
    if should_deploy && isempty(documenter_key)
        @warn("""
            DOCUMENTER_KEY environment variable missing, unable to deploy.
              Note that in Documenter v0.9.0 old deprecated authentication methods were removed.
              DOCUMENTER_KEY is now the only option. See the documentation for more information.""")
        should_deploy = false
    end

    if get(ENV, "DOCUMENTER_DEBUG", "") == "true"
        Utilities.debug("TRAVIS_REPO_SLUG       = \"$travis_repo_slug\"")
        Utilities.debug("  should match \"$repo\" (kwarg: repo)")
        Utilities.debug("TRAVIS_PULL_REQUEST    = \"$travis_pull_request\"")
        Utilities.debug("  deploying if equal to \"false\"")
        Utilities.debug("TRAVIS_BRANCH          = \"$travis_branch\"")
        Utilities.debug("TRAVIS_TAG             = \"$travis_tag\"")
        Utilities.debug("  deploying if branch equal to \"$devbranch\" (kwarg: devbranch) or tag is set")
        Utilities.debug("git commit SHA         = $sha")
        Utilities.debug("DOCUMENTER_KEY exists  = $(!isempty(documenter_key))")
        Utilities.debug("should_deploy          = $should_deploy")
    end

    if should_deploy
        # Add local bin path if needed.
        Deps.updatepath!()
        # Install dependencies when applicable.
        if deps !== nothing
            Utilities.log("installing dependencies.")
            deps()
        end
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            Utilities.log("setting up target directory.")
            isdir(target) || mkpath(target)
            # Run extra build steps defined in `make` if required.
            if make !== nothing
                Utilities.log("running extra build steps.")
                make()
            end
            Utilities.log("pushing new documentation to remote: $repo:$branch.")
            mktempdir() do temp
                git_push(
                    root, temp, repo;
                    branch=branch, dirname=dirname, target=target,
                    tag=travis_tag, key=documenter_key, sha=sha,
                    devurl = devurl, versions = versions,
                )
            end
        end
    else
        Utilities.log("""
            skipping docs deployment.
              You can set DOCUMENTER_DEBUG to "true" in Travis to see more information.""")
    end
end

"""
    git_push(
        root, tmp, repo;
        branch="gh-pages", dirname="", target="site", tag="", key="", sha="", devurl="dev"
    )

Handles pushing changes to the remote documentation branch.
When `tag` is empty the docs are deployed to the `devurl` directory,
and when building docs for a tag they are deployed to a `vX.Y.Z` directory.
"""
function git_push(
        root, temp, repo;
        branch="gh-pages", dirname="", target="site", tag="", key="", sha="", devurl="dev",
        versions
    )
    dirname = isempty(dirname) ? temp : joinpath(temp, dirname)
    isdir(dirname) || mkpath(dirname)

    keyfile = abspath(joinpath(root, ".documenter"))
    target_dir = abspath(target)

    # The upstream URL to which we push new content and the ssh decryption commands.
    upstream = "git@$(replace(repo, "github.com/" => "github.com:"))"

    write(keyfile, String(base64decode(key)))
    chmod(keyfile, 0o600)

    try
        # Use a custom SSH config file to avoid overwriting the default user config.
        withfile(joinpath(homedir(), ".ssh", "config"),
            """
            Host github.com
                StrictHostKeyChecking no
                HostName github.com
                IdentityFile $keyfile
            """
        ) do
            cd(temp) do
                # Setup git.
                run(`git init`)
                run(`git config user.name "autodocs"`)
                run(`git config user.email "autodocs"`)

                # Fetch from remote and checkout the branch.
                run(`git remote add upstream $upstream`)
                run(`git fetch upstream`)

                try
                    run(`git checkout -b $branch upstream/$branch`)
                catch e
                    Utilities.log("Checking out $branch failed with error: $e")
                    Utilities.log("Creating a new local $branch branch.")
                    run(`git checkout --orphan $branch`)
                    run(`git commit --allow-empty -m "Initial empty commit for docs"`)
                end

                # Copy docs to `devurl`, or `stable`, `<release>`, and `<version>` directories.
                if isempty(tag)
                    devurl_dir = joinpath(dirname, devurl)
                    gitrm_copy(target_dir, devurl_dir)
                    Writers.HTMLWriter.generate_siteinfo_file(devurl_dir, devurl)
                    # symlink "latest" to devurl to preserve links (remove in some future release)
                    if devurl != "latest"
                        rm(joinpath(dirname, "latest"); recursive = true, force = true)
                        @warn(string("creating symlink from `latest` to `$(devurl)` for backwards ",
                            "compatibility with old links. In future Documenter versions this symlink ",
                            "will not be created. Please update any links that point to `latest`."))
                        cd(dirname) do; rm_and_add_symlink(devurl, "latest"); end
                    end
                else
                    tagged_dir = joinpath(dirname, tag)
                    gitrm_copy(target_dir, tagged_dir)
                    Writers.HTMLWriter.generate_siteinfo_file(tagged_dir, tag)
                end

                # Expand the users `versions` vector
                entries, symlinks = Writers.HTMLWriter.expand_versions(dirname, versions)

                # Create the versions.js file containing a list of `entries`.
                # This must always happen after the folder copying.
                Writers.HTMLWriter.generate_version_file(joinpath(dirname, "versions.js"), entries)

                # generate the symlinks, make sure we don't overwrite devurl
                cd(dirname) do
                    for kv in symlinks
                        i = findfirst(x -> x.first == devurl, symlinks)
                        if i === nothing
                            rm_and_add_symlink(kv.second, kv.first)
                        else
                            throw(ArgumentError(string("link `$(kv)` cannot overwrite ",
                                "`devurl = $(devurl)` with the same name.")))
                        end
                    end
                end

                # Add, commit, and push the docs to the remote.
                run(`git add -A .`)
                if !success(`git diff --cached --exit-code`)
                    run(`git commit -m "build based on $sha"`)
                    run(`git push -q upstream HEAD:$branch`)
                else
                    Utilities.log("New docs identical to the old -- not committing nor pushing.")
                end
            end
        end
    finally
        # Remove the unencrypted private key.
        isfile(keyfile) && rm(keyfile)
    end
end

function rm_and_add_symlink(target, link)
    if ispath(link)
        @warn "removing `$(link)` and linking `$(link)` to `$(target)`."
        rm(link; force = true, recursive = true)
    end
    symlink(target, link)
end

"""
    gitrm_copy(src, dst)

Uses `git rm -r` to remove `dst` and then copies `src` to `dst`. Assumes that the working
directory is within the git repository of `dst` is when the function is called.

This is to get around [#507](https://github.com/JuliaDocs/Documenter.jl/issues/507) on
filesystems that are case-insensitive (e.g. on OS X, Windows). Without doing a `git rm`
first, `git add -A` will not detect case changes in filenames.
"""
function gitrm_copy(src, dst)
    # --ignore-unmatch so that we wouldn't get errors if dst does not exist
    run(`git rm -rf --ignore-unmatch $(dst)`)
    cp(src, dst; force=true)
end

function withfile(func, file::AbstractString, contents::AbstractString)
    hasfile = isfile(file)
    original = hasfile ? read(file, String) : ""
    open(file, "w") do stream
        print(stream, contents)
        flush(stream) # Make sure file is written before continuing.
    end
    try
        func()
    finally
        if hasfile
            open(file, "w") do stream
                print(stream, original)
            end
        else
            rm(file)
        end
    end
end

function getenv(regex::Regex)
    for (key, value) in ENV
        occursin(regex, key) && return value
    end
    error("could not find key/iv pair.")
end

end # module
