__precompile__(true)

"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`](@ref). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`](@ref). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

Additionally it provides the unexported [`Documenter.generate`](@ref), which can be used to
generate documentation stubs for new packages.

"""
module Documenter

using Compat

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

export Deps, makedocs, deploydocs

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

    \$ julia make.jl

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
$(strip(readstring(joinpath(dirname(@__FILE__), "..", "docs", "make.jl"))))
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
makedocs(repo = "https://gitlab.com/user/project/blob/{commit}{path}#L{line}")
```

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

**`repo`** is the remote repository where generated HTML content should be pushed to. This
keyword *must* be set and will throw an error when left undefined. For example this package
uses the following `repo` value:

    repo = "github.com/JuliaDocs/Documenter.jl.git"

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

**`deps`** is the function used to install any dependancies needed to build the
documentation. By default this function installs `pygments` and `mkdocs` using the
[`Deps.pip`](@ref) function:

    deps = Deps.pip("pygments", "mkdocs")

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

        repo   = error("no 'repo' keyword provided."),
        branch = "gh-pages",
        latest = "master",

        osname = "linux",
        julia  = "nightly",

        deps   = Deps.pip("pygments", "mkdocs"),
        make   = () -> run(`mkdocs build`),
    )
    # Get environment variables.
    github_api_key      = get(ENV, "GITHUB_API_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_osname       = get(ENV, "TRAVIS_OS_NAME",       "")
    travis_julia        = get(ENV, "TRAVIS_JULIA_VERSION", "")

    # Other variables.
    sha          = readchomp(`git rev-parse --short HEAD`)
    ssh_key_file = abspath(joinpath(root, ".documenter.enc"))
    has_ssh_key  = isfile(ssh_key_file)

    # When should a deploy be attempted?
    should_deploy =
        contains(repo, travis_repo_slug) &&
        travis_pull_request == "false"   &&
        (
            # Support token and ssh key deployments.
            github_api_key != "" ||
            has_ssh_key
        ) &&
        travis_osname == osname &&
        travis_julia  == julia  &&
        (
            travis_branch == latest ||
            travis_tag    != ""
        )

    if get(ENV, "DOCUMENTER_DEBUG", "") == "true"
        Utilities.debug("TRAVIS_REPO_SLUG       = \"$travis_repo_slug\"")
        Utilities.debug("TRAVIS_PULL_REQUEST    = \"$travis_pull_request\"")
        Utilities.debug("TRAVIS_OS_NAME         = \"$travis_osname\"")
        Utilities.debug("TRAVIS_JULIA_VERSION   = \"$travis_julia\"")
        Utilities.debug("TRAVIS_BRANCH          = \"$travis_branch\"")
        Utilities.debug("TRAVIS_TAG             = \"$travis_tag\"")
        Utilities.debug("git commit SHA         = $sha")
        Utilities.debug("GITHUB_API_KEY exists  = $(github_api_key != "")")
        Utilities.debug(".documenter.enc path   = $(ssh_key_file)")
        Utilities.debug(".documenter.enc exists = $(has_ssh_key)")
        Utilities.debug("should_deploy          = $should_deploy")
    end

    if should_deploy
        # Add local bin path if needed.
        Deps.updatepath!()
        # Install dependancies.
        Utilities.log("installing dependancies.")
        deps()
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            Utilities.log("setting up target directory.")
            Utilities.cleandir(target)
            Utilities.log("building documentation.")
            make()
            Utilities.log("pushing new documentation to remote: $repo:$branch.")
            mktempdir() do temp
                # Versioned docs directories.
                latest_dir = joinpath(temp, "latest")
                stable_dir = joinpath(temp, "stable")
                tagged_dir = joinpath(temp, travis_tag)

                keyfile, _ = splitext(ssh_key_file)
                target_dir = abspath(target)

                # The upstream URL to which we push new content and the ssh decryption commands.
                upstream, ssh_script =
                    if has_ssh_key
                        key = getenv(r"encrypted_(.+)_key")
                        iv  = getenv(r"encrypted_(.+)_iv")
                        "git@$(replace(repo, "github.com/", "github.com:"))",
                        """
                        openssl aes-256-cbc -K $key -iv $iv -in $keyfile.enc -out $keyfile -d
                        chmod 600 $keyfile
                        eval `ssh-agent -s`
                        ssh-add $keyfile
                        """
                    else
                        "https://$github_api_key@$repo", ""
                    end

                # On non-tagged builds we just build `latest`,
                # otherwise build the `stable` and `version` builds.
                copy_script =
                    if travis_tag == ""
                        """
                        rm -rf $latest_dir
                        cp -r  $target_dir $latest_dir
                        """
                    else
                        """
                        rm -rf $stable_dir
                        cp -r  $target_dir $stable_dir
                        rm -rf $tagged_dir
                        cp -r  $target_dir $tagged_dir
                        """
                    end

                # Auto authorise SSH authentication requests for github.com.
                open(joinpath(homedir(), ".ssh", "config"), "a") do io
                    println(io,
                        """
                        Host github.com
                            StrictHostKeyChecking no
                        """
                    )
                end

                # Write, run, and delete the deploy script.
                mktemp() do path, io
                    script = buildscript(
                        temp,
                        upstream,
                        branch,
                        ssh_script,
                        copy_script,
                        sha,
                    )
                    println(io, script); flush(io) # `flush`, otherwise `path` is empty.
                    run(`sh $path`)
                    # Remove the unencrypted private key.
                    isfile(keyfile) && rm(keyfile)
                end
            end
        end
    else
        Utilities.log("skipping docs deployment.")
    end
end

buildscript(dir, upstream, branch, ssh_script, copy_script, sha) =
    """
    $ssh_script

    cd $dir

    git init

    git config user.name  "autodocs"
    git config user.email "autodocs"

    git remote add upstream "$upstream"

    git fetch upstream

    git checkout -b $branch upstream/$branch

    $copy_script

    git add -A .
    git commit -m "build based on $sha"

    git push -q upstream HEAD:$branch
    """

function getenv(k::Regex)
    found = collect(filter(s -> ismatch(k, s), keys(ENV)))
    length(found) === 1 ? ENV[found[1]] : error("no keys found in ENV 'key/iv' pair.")
end

export Travis

"""
Package functions for interacting with Travis.
"""
module Travis

using Compat

export genkeys

"""
Generate ssh keys for automatic deployment of docs from Travis to GitHub pages. Requires the
following command lines programs to be installed:

- `which`
- `git`
- `travis`
- `ssh-keygen`

# Examples

    julia> using Documenter

    julia> Travis.genkeys("MyPackageName")
    [ ... output ... ]

"""
function genkeys(package)
    # Error checking. Do the required programs exist?
    isdir(Pkg.dir(package))     || error("'$package' could not be found in '$(Pkg.dir())'.")
    success(`which which`)      || error("'which' not found.")
    success(`which git`)        || error("'git' not found.")
    success(`which travis`)     || error("'travis' not found.")
    success(`which ssh-keygen`) || error("'ssh-keygen' not found.")

    directory = "docs"
    filename  = ".documenter"

    cd(Pkg.dir(package, directory)) do

        run(`ssh-keygen -N "" -f $filename`)
        run(`travis login --auto`)
        run(`travis encrypt-file $filename`)

        warn("removing private key.")
        rm(filename)

        # Get remote details.
        user, repo =
            let r = readchomp(`git config --get remote.origin.url`)
                m = match(isdefined(Base, :LibGit2) ?
                    Base.LibGit2.GITHUB_REGEX :
                    Pkg.Git.GITHUB_REGEX, r)
                m === nothing && error("no remote repo named 'origin' found.")
                m[2], m[3]
            end
        println(
            """

            Add the following public deploy key to '$user/$repo' with write access

            $(strip(readstring("$filename.pub")))

            on the following page:

                https://github.com/$user/$repo/settings/keys

            Then commit the '$filename.enc' file. Do not edit '.travis.yml'.
            """
        )
        warn("removing public key.")
        rm("$filename.pub")
    end
end

end

"""
    generate(
        pkgname;
        dir = "<package directory>/docs"
    )

Creates a documentation stub for a package called `pkgname`. The location of
the documentation is assumed to be `<package directory>/docs`, but this can
be overriden with keyword arguments.

It creates the following files

    docs/
        .gitignore
        src/index.md
        make.jl
        mkdocs.yml

# Positionals

**`pkgname`** is the name of the package (without `.jl`). It is used to
determine the location of the documentation if `dir` is not provided.

# Keywords

**`dir`** defines the directory where the documentation will be generated.
It defaults to `<package directory>/docs`. The directory must not exist.

# Examples

    julia> using Documenter

    julia> Documenter.generate("MyPackageName")
    [ ... output ... ]

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
