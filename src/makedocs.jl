# Implements the makedocs() and functions directly related to it.

"""
    makedocs(;
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
        draft = false,
        others...
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
build stages are skipped and the `warnonly` keyword is ignored (a doctesting error will always
make `makedocs` throw an error in this mode).

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

**`repo`** specifies the remote hosted Git repository (e.g. on `github.com`) related to the
documentation build. It should be passed an object that subtypes and implements the
[`Remotes.Remote`](@ref) interface (e.g. [`Remotes.GitHub`](@ref)). A template string can
also be passed (interpreted according to the rules described in [`Remotes.URL`](@ref)), but
the use of the template strings is discouraged, in favor of concrete
[`Remotes.Remote`](@ref) objects.

**`remotes`** can be used to declare a list additional
`path::AbstractString => remote` pairs that are used to determine the remote
repository URLs for local filesystem files, such as the edit links for manual Markdown
pages, or docstring source links. `path` should be an absolute local filesystem path to a
directory, and will be interpreted as the root of the remote repository specified with
`remote`. `remote` would normally be [`Remote`](@ref Remotes.Remote) object, but can also be
a `(remote::Remote, commit::AbstractString)` tuple, where the second argument specifies the
commit within the repository. This is necessary when `path` is not pointing to a proper Git
repository, and so determining the commit automatically is not possible.

If `repo` is not passed, `makedocs` will try to determine it automatically, either by
inspecting the locally checked out Git repository, or via the `remotes` keyword. See the
manual section on [Remote repository links](@ref) for more information on how the remote
repository links are handled.

If `remotes` is set to `nothing`, all remote repository links (repository links, source links,
edit links, issue links etc.) will be completely disabled. This can be useful when publicly
deploying documentation for private packages.

**`highlightsig`** enables or disables automatic syntax highlighting of leading, unlabeled
code blocks in docstrings (as Julia code). For example, if your docstring begins with an
indented code block containing the function signature, then that block would be highlighted
as if it were a labeled Julia code block. No other code blocks are affected. This feature
is enabled by default.

**`sitename`** is displayed in the title bar and/or the navigation menu when applicable.

**`pages`** can be used to specify a hierarchical page structure, and the order in which
the pages appear in the navigation of the rendered output. If omitted, Documenter will
automatically generate a flat list of pages based on the files present in the source
directory.

```julia
pages = [
    "Overview" => "index.md",
    "tutorial.md",
    "Tutorial" => [
        "tutorial/introduction.md",
        "Advanced" => "tutorial/features.md",
    ],
    "apireference.md",
]
```

The `pages` keyword must be a list where each element must be one of the following:

1. A string containing the full path of a Markdown file _within_ the source directory (i.e. relative to the `docs/src/` root in standard deployments).
2. A `"Page title" => "path/to/page.md"` pair, where `Page title` overrides the page title in the navigation menu (but not on the page itself).
3. A `"Subsection title" => [...]` pair, indicating a subsection of pages with the given title in the navigation menu. The list of pages for the subsection follow the same rules as the top-level `pages` keyword.

See also [`hide`](@ref), which can be used to hide certain pages in the navigation menu.

Note that, by default, regardless of what is specified in `pages`, Documenter will run and
render _all_ Markdown files it finds, even if they are not present in `pages`. The
`pagesonly` keyword can be used to change this behaviour.

**`pagesonly`** can be set to `true` (default: `false`) to make Documenter process only the
pages listed in with the `pages` keyword. In that case, the Markdown files not present in
`pages` are ignored, i.e. code blocks do not run, docstrings do not get included, and the
pages are not rendered in the output in any way.

**`expandfirst`** allows some of the pages to be _expanded_ (i.e. at-blocks evaluated etc.)
before the others. Documenter normally evaluates the files in the alphabetic order of their
file paths relative to `src`, but `expandfirst` allows some pages to be prioritized.

For example, if you have `foo.md` and `bar.md`, `bar.md` would normally be evaluated before
`foo.md`. But with `expandfirst = ["foo.md"]`, you can force `foo.md` to be evaluated first.

Evaluation order among the `expandfirst` pages is according to the order they appear in the
argument.

**`draft`** can be set to `true` to build a draft version of the document. In draft mode
some potentially time-consuming steps are skipped (e.g. running `@example` blocks), which is
useful when iterating on the documentation. This setting can also be configured per-page
by setting `Draft = true` in an `@meta` block.

**`checkdocs`** instructs [`makedocs`](@ref) to check whether all names within the modules
defined in the `modules` keyword that have a docstring attached have the docstring also
listed in the manual (e.g. there's a `@docs` block with that docstring). Possible values
are `:all` (check all names; the default), `:exports` (check only exported names),
`:public` (check exported names and those marked with the `public` keyword in Julia ≥ 1.11),
and `:none` (no checks are performed).

By default, if the document check detect any errors, it will fail the documentation build.
This behavior can be relaxed with the `warnonly` or `checkdocs_ignored_modules` keywords.

**`checkdocs_ignored_modules`** prevents `checkdocs` from checking modules supplied as a list
of module objects. It will also cause all submodules of these module to be ignored. It can be
useful for completely private modules including modules which have been vendored from
elsewhere.

Note that `checkdocs_ignored_modules` does not conversely verify that these docstrings are *not*
included in the documentation.

**`linkcheck`** -- if set to `true` [`makedocs`](@ref) uses `curl` to check the status codes
of external-pointing links, to make sure that they are up-to-date. The links and their
status codes are printed to the standard output. When enabled, any detected errors will fail
the build, but this can be overridden by passing `:linkcheck` to `warnonly`. Default: `false`.

**`linkcheck_ignore`** allows certain URLs to be ignored in `linkcheck`. The values should
be a list of strings (which get matched exactly) or `Regex` objects. By default nothing is
ignored.

**`linkcheck_timeout`** configures how long `curl` waits (in seconds) for a link request to
return a response before giving up. The default is 10 seconds.

**`linkcheck_useragent`** can be used to override the user agent string used by the HTTP and
HTTPS requests made when checking for broken links. If set to `nothing`, it uses the default
user agent string of the library/tool used to actually perform the requests (currently, the
system's `curl` binary).

If unset, Documenter uses the following user agent string:

```
$(_LINKCHECK_DEFAULT_USERAGENT)
```

This is set to mimic a realistic web browser. However, the exact user agent string is subject
to change. As such, it is possible that breakages can occur when Documenter's version changes,
but the goal is to set the user agent such that it would be accepted by as many web servers as
possible.

**`warnonly`** can be used to control whether the `makedocs` build fails with an error, or
simply prints a warning if it detects any issues with the document. Additionally, a `Symbol`
or a `Vector` of `Symbol`s can be passed to make Documenter warn for only those specified
error classes (see also: [`Documenter.except`](@ref)). If set to `true`, the build should
never fail due to document checks. The keyword defaults to `false`.

Note that setting `warnonly = true` in general is not recommended, since it will make it very
easy to miss Documentation build issues, and will lead to the deployment of broken manuals.
The only case where you may want to consider passing `true` is when you are automatically
deploying the documentation for a package release. In that case, `warnonly` should be set
dynamically by checking the relevant environment variables set by the CI system.

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

**`plugins`** is a list of [`Documenter.Plugin`](@ref) objects. Use as directed by the
documentation of a third-party plugin. For any subtype `T <: Plugin`, the
`plugins` list may contain at most a single object of type `T`.

## Output formats

**`format`** allows the output format to be specified. The default format is
[`Documenter.HTML`](@ref) which creates a set of HTML files, but Documenter also provides
PDF output via the [`Documenter.LaTeX`](@ref) writer.

Other formats can be enabled by using other addon-packages. For example, the
[DocumenterMarkdown](https://github.com/JuliaDocs/DocumenterMarkdown.jl) package provides
the original Markdown -> Markdown output. See the [Other Output Formats](@ref) for more
information.

# See Also

A guide detailing how to document a package using Documenter's [`makedocs`](@ref) is provided
in the [setup guide in the manual](@ref Package-Guide).
"""
function makedocs(; debug = false, format = HTML(), kwargs...)
    document = Documenter.Document(; format = format, kwargs...)
    # Before starting the build pipeline, we empty out the subtype cache used by
    # Selectors.dispatch. This is to make sure that we pick up any new selector stages that
    # may have been added to the selector pipelines between makedocs calls.
    empty!(Selectors.selector_subtypes)
    original_pwd[] = pwd()
    cd(document.user.root) do
        withenv(NO_KEY_ENV...) do
            Selectors.dispatch(Builder.DocumentPipeline, document)
        end
    end
    return debug ? document : nothing
end

"""
    Documenter.except(errors...)

Returns the list of all valid error classes that can be passed as the `warnonly` argument of
[`makedocs`](@ref), except for the ones specified in the `errors` argument. Each error class
must be a `Symbol` and passed as a separate argument.

This can be used to enable strict error checking for only the listed error classes, while having
other error types simply print a warning. E.g. to make Documenter fail the build only for
footnote and linkcheck errors, one can set `warnonly` as

```julia
makedocs(...,
    warnonly = Documenter.except(:linkcheck, :footnote),
)
```

The possible `Symbol` values that can be passed to the function are:
$(join(Ref("`:") .* string.(ERROR_NAMES) .* Ref("`"), ", ", ", and ")).
"""
function except(errors::Symbol...)
    invalid_errors = setdiff(errors, ERROR_NAMES)
    if !isempty(invalid_errors)
        throw(
            DomainError(
                tuple(invalid_errors...),
                "Invalid error classes passed to Documenter.except. Valid error classes are: $(ERROR_NAMES)"
            )
        )
    end
    return setdiff(ERROR_NAMES, errors)
end

"""
$(SIGNATURES)

Allows a page to be hidden in the navigation menu. It will only show up if it happens to be
the current page. The hidden page will still be present in the linear page list that can be
accessed via the previous and next page links. The title of the hidden page can be overridden
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
    struct MissingRemoteError <: Exception

This error is thrown by [`makedocs`](@ref) when it is unable to determine the remote repository link
for a Markdown file or a docstring.

See the [Remote repository links](@ref) section in the manual for more information.
"""
struct MissingRemoteError <: Exception
    path::String
    linerange::Any
    mod::Union{Module, Nothing}

    function MissingRemoteError(;
            path::AbstractString,
            linerange = nothing,
            mod::Union{Module, Nothing} = nothing
        )
        return new(path, linerange, mod)
    end
end

function Base.showerror(io::IO, e::MissingRemoteError)
    print(io, "MissingRemoteError: unable to generate source url\n  path: $(e.path)")
    isnothing(e.linerange) || print(io, ':', e.linerange)
    println(io)
    isnothing(e.mod) || println(io, "  module: ", e.mod)
    return print(
        io, """
        Documenter was unable to automatically determine the remote repository for this file.
        This can happen if you are including docstrings or pages from secondary packages. Those packages
        must be cloned as Git repositories (i.e. Pkg.develop instead Pkg.add), or the `remotes` keyword
        must be configured appropriately. See the 'Remote repository links' section in the manual for
        more information."""
    )
end
