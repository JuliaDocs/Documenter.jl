__precompile__(true)

"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`](@ref). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`](@ref). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

Additionally it provides the unexported [`Documenter.generate`](@ref), which can be used to
generate documentation stubs for new packages.

$(EXPORTS)

"""
module Documenter

using Compat, DocStringExtensions

#
# Submodules
#
# All submodules of this package are declared in the following loop.
#
# They can either be a single file in the "modules" folder or a subfolder of
# "modules" containing a file with the same name. Large submodules should be
# split into several files in a subfolder.
#
for mod in [
    "Utilities",
    "DocSystem",
    "Selectors",
    "Formats",
    "Anchors",
    "Documents",
    "Builder",
    "Expanders",
    "Walkers",
    "CrossReferences",
    "DocChecks",
    "Writers",
    "Deps",
    "Generator",
]
    dir = dirname(@__FILE__)
    file = joinpath(dir, mod * ".jl")
    isfile(file) ? include(file) : include(joinpath(dir, mod, mod * ".jl"))
end


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

  - `{commit}` Git commit id
  - `{path}` Path to the file in the repository
  - `{line}` Line (or range of lines) in the source file

For example if you are using GitLab.com, you could use

```julia
makedocs(repo = \"https://gitlab.com/user/project/blob/{commit}{path}#L{line}\")
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

## Non-MkDocs builds

Documenter also has (experimental) support for native HTML and LaTeX builds.
These can be enabled using the `format` keyword and they generally require additional
keywords be defined, depending on the format. These keywords are also currently considered
experimental.

**`format`** allows the output format to be specified. Possible values are `:html`, `:latex`
and `:markdown` (default).

Other keywords related to non-MkDocs builds (**`assets`**, **`sitename`**, **`analytics`**,
**`authors`**, **`pages`**, **`version`**) should be documented at the respective `*Writer`
modules ([`Writers.HTMLWriter`](@ref), [`Writers.LaTeXWriter`](@ref)).

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
        target = "site",
        repo   = "<required>",
        branch = "gh-pages",
        latest = "master",
        osname = "linux",
        julia  = "nightly",
        deps   = <Function>,
        make   = <Function>,
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

# Keywords

**`root`** has the same purpose as the `root` keyword for [`makedocs`](@ref).

**`target`** is the directory, relative to `root`, where generated HTML content should be
written to. This directory **must** be added to the repository's `.gitignore` file. The
default value is `"site"`.

**`repo`** is the remote repository where generated HTML content should be pushed to. Do not
specify any protocol - "https://" or "git@" should not be present. This keyword *must*
be set and will throw an error when left undefined. For example this package uses the
following `repo` value:

```julia
repo = "github.com/JuliaDocs/Documenter.jl.git"
```

**`branch`** is the branch where the generated documentation is pushed. By default this
value is set to `"gh-pages"`.

**`latest`** is the branch that "tracks" the latest generated documentation. By default this
value is set to `"master"`.

**`osname`** is the operating system which will be used to deploy generated documentation.
This defaults to `"linux"`. This value must be one of those specified in the `os:` section
of the `.travis.yml` configuration file.

**`julia`** is the version of Julia that will be used to deploy generated documentation.
This defaults to `"nightly"`. This value must be one of those specified in the `julia:`
section of the `.travis.yml` configuration file.

**`deps`** is the function used to install any dependencies needed to build the
documentation. By default this function installs `pygments` and `mkdocs` using the
[`Deps.pip`](@ref) function:

```julia
deps = Deps.pip("pygments", "mkdocs")
```

**`make`** is the function used to convert the markdown files to HTML. By default this just
runs `mkdocs build` which populates the `target` directory.

# See Also

The [Hosting Documentation](@ref) section of the manual provides a step-by-step guide to
using the [`deploydocs`](@ref) function to automatically generate docs and push then to
GitHub.
"""
function deploydocs(;
        root   = Utilities.currentdir(),
        target = "site",
        dirname = "",

        repo   = error("no 'repo' keyword provided."),
        branch = "gh-pages",
        latest = "master",

        osname = "linux",
        julia  = "nightly",

        deps   = Deps.pip("pygments", "mkdocs"),
        make   = () -> run(`mkdocs build`),
    )
    # Get environment variables.
    documenter_key      = get(ENV, "DOCUMENTER_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_osname       = get(ENV, "TRAVIS_OS_NAME",       "")
    travis_julia        = get(ENV, "TRAVIS_JULIA_VERSION", "")

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
    if !isa(julia, AbstractString)
        error("julia must be a string, got $julia ($(typeof(julia)))")
    end
    if !isempty(travis_repo_slug) && !contains(repo, travis_repo_slug)
        warn("repo $repo does not match $travis_repo_slug")
    end

    # When should a deploy be attempted?
    should_deploy =
        contains(repo, travis_repo_slug) &&
        travis_pull_request == "false"   &&
        travis_osname == osname &&
        travis_julia  == julia  &&
        (
            travis_branch == latest ||
            travis_tag    != ""
        )

    # check DOCUMENTER_KEY only if the branch, Julia version etc. check out
    if should_deploy && isempty(documenter_key)
        warn("""
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
        Utilities.debug("TRAVIS_OS_NAME         = \"$travis_osname\"")
        Utilities.debug("  deploying if equal to \"$osname\" (kwarg: osname)")
        Utilities.debug("TRAVIS_JULIA_VERSION   = \"$travis_julia\"")
        Utilities.debug("  deploying if equal to \"$julia\" (kwarg: julia)")
        Utilities.debug("TRAVIS_BRANCH          = \"$travis_branch\"")
        Utilities.debug("TRAVIS_TAG             = \"$travis_tag\"")
        Utilities.debug("  deploying if branch equal to \"$latest\" (kwarg: latest) or tag is set")
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
                dirname = isempty(dirname) ? temp : joinpath(temp, dirname)
                isdir(dirname) || mkpath(dirname)
                # Versioned docs directories.
                latest_dir = joinpath(dirname, "latest")
                stable_dir = joinpath(dirname, "stable")
                tagged_dir = joinpath(dirname, travis_tag)

                keyfile = abspath(joinpath(root, ".documenter"))
                target_dir = abspath(target)

                # The upstream URL to which we push new content and the ssh decryption commands.
                write(keyfile, Compat.String(base64decode(documenter_key)))
                chmod(keyfile, 0o600)
                upstream = "git@$(replace(repo, "github.com/", "github.com:"))"

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
                        success(`git remote add upstream $upstream`) ||
                            error("could not add new remote repo.")

                        success(`git fetch upstream`) ||
                            error("could not fetch from remote.")

                        branch_exists = success(`git checkout -b $branch upstream/$branch`)

                        if !branch_exists
                            Utilities.log("assuming $branch doesn't exist yet; creating a new one.")
                            success(`git checkout --orphan $branch`) ||
                                error("could not create new empty branch.")
                            success(`git commit --allow-empty -m "Initial empty commit for docs"`) ||
                                error("could not commit to new branch $branch")
                        end

                        # Copy docs to `latest`, or `stable`, `<release>`, and `<version>` directories.
                        if isempty(travis_tag)
                            cp(target_dir, latest_dir; remove_destination = true)
                            Writers.HTMLWriter.generate_siteinfo_file(latest_dir, "latest")
                        else
                            cp(target_dir, stable_dir; remove_destination = true)
                            Writers.HTMLWriter.generate_siteinfo_file(stable_dir, "stable")
                            cp(target_dir, tagged_dir; remove_destination = true)
                            Writers.HTMLWriter.generate_siteinfo_file(tagged_dir, travis_tag)
                            # Build a `release-*.*` folder as well when the travis tag is
                            # valid, which it *should* always be anyway.
                            if ismatch(Base.VERSION_REGEX, travis_tag)
                                local version = VersionNumber(travis_tag)
                                local release = "release-$(version.major).$(version.minor)"
                                cp(target_dir, joinpath(dirname, release); remove_destination = true)
                                Writers.HTMLWriter.generate_siteinfo_file(joinpath(dirname, release), release)
                            end
                        end

                        # Create the versions.js file containing a list of all docs
                        # versions. This must always happen after the folder copying.
                        Writers.HTMLWriter.generate_version_file(dirname)

                        # Add, commit, and push the docs to the remote.
                        run(`git add -A .`)
                        try run(`git commit -m "build based on $sha"`) end

                        success(`git push -q upstream HEAD:$branch`) ||
                            error("could not push to remote repo.")

                        # Remove the unencrypted private key.
                        isfile(keyfile) && rm(keyfile)
                    end
                end
            end
        end
    else
        Utilities.log("""
            skipping docs deployment.
              You can set DOCUMENTER_DEBUG to "true" in Travis to see more information.""")
    end
end

function withfile(func, file::AbstractString, contents::AbstractString)
    local hasfile = isfile(file)
    local original = hasfile ? readstring(file) : ""
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
        ismatch(regex, key) && return value
    end
    error("could not find key/iv pair.")
end

export Travis

"""
Package functions for interacting with Travis.

$(EXPORTS)
"""
module Travis

using Compat, DocStringExtensions

export genkeys


const GITHUB_REGEX = isdefined(Base, :LibGit2) ?
    Base.LibGit2.GITHUB_REGEX : Base.Pkg.Git.GITHUB_REGEX


"""
$(SIGNATURES)

Generate ssh keys for package `package` to automatically deploy docs from Travis to GitHub
pages. `package` can be either the name of a package or a path. Providing a path allows keys
to be generated for non-packages or packages that are not found in the Julia `LOAD_PATH`.
Use the `remote` keyword to specify the user and repository values.

This function requires the following command lines programs to be installed:

- `which`
- `git`
- `travis`
- `ssh-keygen`

# Examples

```jlcon
julia> using Documenter

julia> Travis.genkeys("MyPackageName")
[ ... output ... ]

julia> Travis.genkeys("MyPackageName", remote="organization")
[ ... output ... ]

julia> Travis.genkeys("/path/to/target/directory")
[ ... output ... ]
```
"""
function genkeys(package; remote="origin")
    # Error checking. Do the required programs exist?
    success(`which which`)      || error("'which' not found.")
    success(`which git`)        || error("'git' not found.")
    success(`which ssh-keygen`) || error("'ssh-keygen' not found.")

    directory = "docs"
    filename  = ".documenter"

    local path = isdir(package) ? package : Pkg.dir(package, directory)
    isdir(path) || error("`$path` not found. Provide a package name or directory.")

    cd(path) do
        # Check for old '$filename.enc' and terminate.
        isfile("$filename.enc") &&
            error("$package already has an ssh key. Remove it and try again.")

        # Are we in a git repo?
        success(`git status`) || error("'Travis.genkey' only works with git repositories.")

        # Find the GitHub repo org and name.
        user, repo =
            let r = readchomp(`git config --get remote.$remote.url`)
                m = match(GITHUB_REGEX, r)
                m === nothing && error("no remote repo named '$remote' found.")
                m[2], m[3]
            end

        # Generate the ssh key pair.
        success(`ssh-keygen -N "" -f $filename`) || error("failed to generated ssh key pair.")

        # Prompt user to add public key to github then remove the public key.
        let url = "https://github.com/$user/$repo/settings/keys"
            info("add the public key below to $url with read/write access:")
            println("\n", readstring("$filename.pub"))
            rm("$filename.pub")
        end

        # Base64 encode the private key and prompt user to add it to travis. The key is
        # *not* encoded for the sake of security, but instead to make it easier to
        # copy/paste it over to travis without having to worry about whitespace.
        let url = "https://travis-ci.org/$user/$repo/settings"
            info("add a secure environment variable named 'DOCUMENTER_KEY' to $url with value:")
            println("\n", base64encode(readstring(".documenter")), "\n")
            rm(filename)
        end
    end
end

end

"""
$(SIGNATURES)

Creates a documentation stub for a package called `pkgname`. The location of
the documentation is assumed to be `<package directory>/docs`, but this can
be overriden with the keyword argument `dir`.

It creates the following files

```
docs/
    .gitignore
    src/index.md
    make.jl
    mkdocs.yml
```

# Arguments

**`pkgname`** is the name of the package (without `.jl`). It is used to
determine the location of the documentation if `dir` is not provided.

# Keywords

**`dir`** defines the directory where the documentation will be generated.
It defaults to `<package directory>/docs`. The directory must not exist.

# Examples

```jlcon
julia> using Documenter

julia> Documenter.generate("MyPackageName")
[ ... output ... ]
```
"""
function generate(pkgname::AbstractString; dir=nothing)
    # TODO:
    #   - set up deployment to `gh-pages`
    #   - fetch url and username automatically (e.g from git remote.origin.url)

    # Check the validity of the package name
    if length(pkgname) == 0
        error("Package name can not be an empty string.")
    end
    # Determine the root directory where we wish to generate the docs and
    # check that it is a valid directory.
    docroot = if dir === nothing
        pkgdir = Pkg.dir(pkgname)
        if !isdir(pkgdir)
            error("Unable to find package $(pkgname).jl at $(pkgdir).")
        end
        joinpath(pkgdir, "docs")
    else
        dir
    end

    if ispath(docroot)
        error("Directory $(docroot) already exists.")
    end

    # deploy the stub
    try
        info("Deploying documentation to $(docroot)")
        mkdir(docroot)

        # create the root doc files
        Generator.savefile(docroot, ".gitignore") do io
            write(io, Generator.gitignore())
        end
        Generator.savefile(docroot, "make.jl") do io
            write(io, Generator.make(pkgname))
        end
        Generator.savefile(docroot, "mkdocs.yml") do io
            write(io, Generator.mkdocs(pkgname))
        end

        # Create the default documentation source files
        Generator.savefile(docroot, "src/index.md") do io
            write(io, Generator.index(pkgname))
        end
    catch
        rm(docroot, recursive=true)
        rethrow()
    end
    nothing
end

end
