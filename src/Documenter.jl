"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`](@ref). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`](@ref). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

# Exports

$(EXPORTS)

"""
module Documenter

using Test: @testset, @test
using DocStringExtensions
import Base64: base64decode

"""
    abstract type Plugin end

Any plugin that needs to either solicit user input or store information in a
[`Documents.Document`](@ref) should create a subtype of `Plugin`. The
subtype, `T <: Documenter.Plugin`, must have an empty constructor `T()` that
initialized `T` with the appropriate default values.

To retrieve the values stored in `T`, the plugin can call [`Documents.getplugin`](@ref).
If `T` was passed to [`makedocs`](@ref), the passed type will be returned. Otherwise,
a new `T` object will be created.
"""
abstract type Plugin end

abstract type Writer end

# Submodules
# ----------

include("Utilities/Utilities.jl")
include("DocMeta.jl")
include("DocSystem.jl")
include("Anchors.jl")
include("Documents.jl")
include("Expanders.jl")
include("DocTests.jl")
include("Builder.jl")
include("CrossReferences.jl")
include("DocChecks.jl")
include("Writers/Writers.jl")
include("Deps.jl")

import .Utilities: Selectors
import .Writers.HTMLWriter: HTML, asset
import .Writers.HTMLWriter.JS: KaTeX, MathJax

# User Interface.
# ---------------
export Deps, makedocs, deploydocs, hide, doctest, DocMeta, KaTeX, MathJax, asset

"""
    makedocs(
        root    = "<current-directory>",
        source  = "src",
        build   = "build",
        clean   = true,
        doctest = true,
        modules = Module[],
        repo    = "",
        highlightsig = true,
        sitename = "",
        expandfirst = [],
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

    julia> makedocs(root = joinpath(dirname(pathof(MyModule)), "..", "docs"))

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

Setting `doctest` to `:only` allows for doctesting without a full build. In this mode, most
build stages are skipped and the `strict` keyword is ignore (a doctesting error will always
make `makedocs` throw an error).

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

**`highlightsig`** enables or disables automatic syntax highlighting of leading, unlabeled
code blocks in docstrings (as Julia code). For example, if your docstring begins with an
indented code block containing the function signature, then that block would be highlighted
as if it were a labeled Julia code block. No other code blocks are affected. This feature
is enabled by default.

**`sitename`** is displayed in the title bar and/or the navigation menu when applicable.

**`expandfirst`** allows some of the pages to be _expanded_ (i.e. at-blocks evaluated etc.)
before the others. Documenter normally evaluates the files in the alphabetic order of their
file paths relative to `src`, but `expandfirst` allows some pages to be prioritized.

For example, if you have `foo.md` and `bar.md`, `bar.md` would normally be evaluated before
`foo.md`. But with `expandfirst = ["foo.md"]`, you can force `foo.md` to be evaluated first.

Evaluation order among the `expandfirst` pages is according to the order they appear in the
argument.

# Experimental keywords

In addition to standard arguments there is a set of non-finalized experimental keyword
arguments. The behaviour of these may change or they may be removed without deprecation
when a minor version changes (i.e. except in patch releases).

**`checkdocs`** instructs [`makedocs`](@ref) to check whether all names within the modules
defined in the `modules` keyword that have a docstring attached have the docstring also
listed in the manual (e.g. there's a `@docs` blocks with that docstring). Possible values
are `:all` (check all names; the default), `:exports` (check only exported names) and
`:none` (no checks are performed). If `strict` is also enabled then the build will fail if
any missing docstrings are encountered.

**`linkcheck`** -- if set to `true` [`makedocs`](@ref) uses `curl` to check the status codes
of external-pointing links, to make sure that they are up-to-date. The links and their
status codes are printed to the standard output. If `strict` is also enabled then the build
will fail if there are any broken (400+ status code) links. Default: `false`.

**`linkcheck_ignore`** allows certain URLs to be ignored in `linkcheck`. The values should
be a list of strings (which get matched exactly) or `Regex` objects. By default nothing is
ignored.

**`strict`** -- [`makedocs`](@ref) fails the build right before rendering if it encountered
any errors with the document in the previous build phases.

**`workdir`** determines the working directory where `@example` and `@repl` code blocks are
executed. It can be either a path or the special value `:build` (default).

If the `workdir` is set to a path, the working directory is reset to that path for each code
block being evaluated. Relative paths are taken to be relative to `root`, but using absolute
paths is recommended (e.g. `workdir = joinpath(@__DIR__, "..")` for executing in the package
root for the usual `docs/make.jl` setup).

With the default `:build` option, the working directory is set to a subdirectory of `build`,
determined from the source file path. E.g. for `src/foo.md` it is set to `build/`, for
`src/foo/bar.md` it is set to `build/foo` etc.

Note that `workdir` does not affect doctests.

## Output formats
**`format`** allows the output format to be specified. The default format is
[`Documenter.HTML`](@ref) which creates a set of HTML files.

There are other possible formats that are enabled by using other addon-packages.
For examples, the `DocumenterMarkdown` package define the `DocumenterMarkdown.Markdown()`
format for use with e.g. MkDocs, and the `DocumenterLaTeX` package define the
`DocumenterLaTeX.LaTeX()` format for LaTeX / PDF output.
See the [Other Output Formats](@ref) for more information.

# See Also

A guide detailing how to document a package using Documenter's [`makedocs`](@ref) is provided
in the [setup guide in the manual](@ref Package-Guide).
"""
function makedocs(components...; debug = false, format = HTML(), kwargs...)
    document = Documents.Document(components; format=format, kwargs...)
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

include("deployconfig.jl")

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

**`deploy_config`** determines configuration for the deployment.
If this is not specified Documenter will try to autodetect from the
currently running environment. See the manual section about
[Deployment systems](@ref).

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

**`forcepush`** a boolean that specifies the behavior of the git-deployment.
The default (`forcepush = false`) is to push a new commit, but when
`forcepush = true` the changes will be combined with the previous commit and
force pushed, erasing the Git history on the deployment branch.

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

**`push_preview`** a boolean that specifies if preview documentation should be
deployed from pull requests or not.

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

        deps   = nothing,
        make   = nothing,

        devbranch = "master",
        devurl = "dev",
        versions = ["stable" => "v^", "v#.#", devurl => devurl],
        forcepush::Bool = false,
        deploy_config = auto_detect_deploy_system(),
        push_preview::Bool = false,
    )

    subfolder = deploy_folder(deploy_config; repo=repo, devbranch=devbranch, push_preview=push_preview, devurl=devurl)
    if subfolder !== nothing
        # Add local bin path if needed.
        Deps.updatepath!()
        # Install dependencies when applicable.
        if deps !== nothing
            @debug "installing dependencies."
            deps()
        end
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            # Find the commit sha.
            # We'll make sure we run the git commands in the source directory (root), in case
            # the working directory has been changed (e.g. if the makedocs' build argument is
            # outside root).
            sha = try
                readchomp(`git rev-parse --short HEAD`)
            catch
                # git rev-parse will throw an error and return code 128 if it is not being
                # run in a git repository, which will make run/readchomp throw an exception.
                # We'll assume that if readchomp fails it is due to this and set the sha
                # variable accordingly.
                "(not-git-repo)"
            end

            @debug "setting up target directory."
            isdir(target) || mkpath(target)
            # Run extra build steps defined in `make` if required.
            if make !== nothing
                @debug "running extra build steps."
                make()
            end
            @debug "pushing new documentation to remote: '$repo:$branch'."
            mktempdir() do temp
                git_push(
                    root, temp, repo;
                    branch=branch, dirname=dirname, target=target,
                    sha=sha, deploy_config=deploy_config, subfolder=subfolder,
                    devurl=devurl, versions=versions, forcepush=forcepush,
                )
            end
        end
    end
end

"""
    git_push(
        root, tmp, repo;
        branch="gh-pages", dirname="", target="site", sha="", devurl="dev",
        deploy_config, folder,
    )

Handles pushing changes to the remote documentation branch.
The documentation are placed in the folder specified by `subfolder`.
"""
function git_push(
        root, temp, repo;
        branch="gh-pages", dirname="", target="site", sha="", devurl="dev",
        versions, forcepush=false, deploy_config, subfolder,
    )
    dirname = isempty(dirname) ? temp : joinpath(temp, dirname)
    isdir(dirname) || mkpath(dirname)

    target_dir = abspath(target)

    # Generate a closure with common commands for ssh and https
    function git_commands()
        # Setup git.
        run(`git init`)
        run(`git config user.name "zeptodoctor"`)
        run(`git config user.email "44736852+zeptodoctor@users.noreply.github.com"`)

        # Fetch from remote and checkout the branch.
        run(`git remote add upstream $upstream`)
        try
            run(`git fetch upstream`)
        catch e
            @error """
            Git failed to fetch $upstream
            This can be caused by a DOCUMENTER_KEY variable that is not correctly set up.
            Make sure that the environment variable is properly set up as a Base64-encoded string
            of the SSH private key. You may need to re-generate the keys with DocumenterTools.
            """
            rethrow(e)
        end

        try
            run(`git checkout -b $branch upstream/$branch`)
        catch e
            @debug "checking out $branch failed with error: $e"
            @debug "creating a new local $branch branch."
            run(`git checkout --orphan $branch`)
            run(`git commit --allow-empty -m "Initial empty commit for docs"`)
        end

        # Copy docs to `subfolder` directory.
        deploy_dir = joinpath(dirname, subfolder)
        gitrm_copy(target_dir, deploy_dir)
        Writers.HTMLWriter.generate_siteinfo_file(deploy_dir, subfolder)

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
            if forcepush
                run(`git commit --amend --date=now -m "build based on $sha"`)
                run(`git push -fq upstream HEAD:$branch`)
            else
                run(`git commit -m "build based on $sha"`)
                run(`git push -q upstream HEAD:$branch`)
            end
        else
            @debug "new docs identical to the old -- not committing nor pushing."
        end
    end

    if authentication_method(deploy_config) === SSH
        # Extract host from repo as everything up to first ':' or '/' character
        host = match(r"(.*?)[:\/]", repo)[1]

        # The upstream URL to which we push new content and the ssh decryption commands.
        upstream = "git@$(replace(repo, "$host/" => "$host:"))"

        keyfile = abspath(joinpath(root, ".documenter"))
        try
            write(keyfile, base64decode(documenter_key(deploy_config)))
        catch e
            @error """
            Documenter failed to decode the DOCUMENTER_KEY environment variable.
            Make sure that the environment variable is properly set up as a Base64-encoded string
            of the SSH private key. You may need to re-generate the keys with DocumenterTools.
            """
            rm(keyfile; force=true)
            rethrow(e)
        end
        chmod(keyfile, 0o600)

        try
            # Use a custom SSH config file to avoid overwriting the default user config.
            withfile(joinpath(homedir(), ".ssh", "config"),
                """
                Host $host
                    StrictHostKeyChecking no
                    User git
                    HostName $host
                    IdentityFile "$keyfile"
                    IdentitiesOnly yes
                    BatchMode yes
                """
            ) do
                cd(git_commands, temp)
            end
            post_status(deploy_config; repo=repo, type="success", subfolder=subfolder)
        catch e
            @error "Failed to push:" exception=(e, catch_backtrace())
            post_status(deploy_config; repo=repo, type="error")
        finally
            # Remove the unencrypted private key.
            isfile(keyfile) && rm(keyfile)
        end
    else # authentication_method(deploy_config) === HTTPS
        # The upstream URL to which we push new content authenticated with token
        upstream = authenticated_repo_url(deploy_config)
        try
            cd(git_commands, temp)
            post_status(deploy_config; repo=repo, type="success", subfolder=subfolder)
        catch e
            @error "Failed to push:" exception=(e, catch_backtrace())
            post_status(deploy_config; repo=repo, type="error")
        end
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
    # git rm also removed parent directories
    # if they are empty so need to mkpath after
    mkpath(dst)
    cp(src, dst; force=true)
end

function withfile(func, file::AbstractString, contents::AbstractString)
    dir = dirname(file)
    hasdir = isdir(dir)
    hasdir || mkpath(dir)

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

        if !hasdir
            # dir should be empty now as the only file inside was deleted
            rm(dir, recursive=true)
        end
    end
end

function getenv(regex::Regex)
    for (key, value) in ENV
        occursin(regex, key) && return value
    end
    error("could not find key/iv pair.")
end

"""
    doctest(package::Module; kwargs...)

Convenience method that runs and checks all the doctests for a given Julia package.
`package` must be the `Module` object corresponding to the top-level module of the package.
Behaves like an `@testset` call, returning a testset if all the doctests are successful or
throwing a `TestSetException` if there are any failures. Can be included in other testsets.

# Keywords

**`manual`** controls how manual pages are handled. By default (`manual = true`), `doctest`
assumes that manual pages are located under `docs/src`. If that is not the case, the
`manual` keyword argument can be passed to specify the directory. Setting `manual = false`
will skip doctesting of manual pages altogether.

Additional keywords are passed on to the main [`doctest`](@ref) method.
"""
function doctest(package::Module; manual=true, testset=nothing, kwargs...)
    if pathof(package) === nothing
        throw(ArgumentError("$(package) is not a top-level package module."))
    end
    source = nothing
    if manual === true
         source = normpath(joinpath(dirname(pathof(package)), "..", "docs", "src"))
         isdir(source) || throw(ArgumentError("""
         Package $(package) does not have a documentation source directory at standard location.
         Searched at: $(source)
         If ...
         """))
    end
    testset = (testset === nothing) ? "Doctests: $(package)" : testset
    doctest(source, [package]; testset=testset, kwargs...)
end

"""
    doctest(source, modules; kwargs...)

Runs all the doctests in the given modules and on manual pages under the `source` directory.
Behaves like an `@testset` call, returning a testset if all the doctests are successful or
throwing a `TestSetException` if there are any failures. Can be included in other testsets.

The manual pages are searched recursively in subdirectories of `source` too. Doctesting of
manual pages can be disabled if `source` is set to `nothing`.

# Keywords

**`testset`** specifies the name of test testset (default `Doctests`).

**`fix`**, if set to `true`, updates all the doctests that fail with the correct output
(default `false`).

!!! warning
    When running `doctest(...; fix=true)`, Documenter will modify the Markdown and Julia
    source files. It is strongly recommended that you only run it on packages in Pkg's
    develop mode and commit any staged changes. You should also review all the changes made
    by `doctest` before committing them, as there may be edge cases when the automatic
    fixing fails.
"""
function doctest(
        source::Union{AbstractString,Nothing},
        modules::AbstractVector{Module};
        fix = false,
        testset = "Doctests",
    )
    function all_doctests()
        dir = mktempdir()
        try
            @debug "Doctesting in temporary directory: $(dir)" modules
            if source === nothing
                source = joinpath(dir, "src")
                mkdir(source)
            end
            makedocs(
                root = dir,
                source = source,
                sitename = "",
                doctest = fix ? :fix : :only,
                modules = modules,
            )
            true
        catch err
            @error "Doctesting failed" exception=(err, catch_backtrace())
            false
        finally
            rm(dir; recursive=true)
        end
    end
    @testset "$testset" begin
        @test all_doctests()
    end
end

end # module
