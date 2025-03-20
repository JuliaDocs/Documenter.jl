# Package Guide

Documenter is designed to do one thing -- combine markdown files and inline docstrings from
Julia's docsystem into a single inter-linked document. What follows is a step-by-step guide
to creating a simple document.


## Installation

Documenter can be installed using the Julia package manager.
From the Julia REPL, type `]` to enter the Pkg REPL mode and run

```
pkg> add Documenter
```

For package documentation, the standard approach is to install Documenter into a documentation-specific project stored in the `docs/` subdirectory of your package.
To do this, navigate to your package's root folder and do

```
pkg> activate docs/

(docs) pkg> add Documenter
```

This will create `Project.toml` and `Manifest.toml` files in the `docs/` subdirectory. 

Note that for packages, you also likely need to have your package that you are documenting as a  ["dev dependency"](https://pkgdocs.julialang.org/v1/managing-packages/#developing) of the `docs/` environment.

See also [the Pkg.jl documentation on working with project environments](https://pkgdocs.julialang.org/v1/environments/).

## Setting up the Folder Structure

!!! note
    The function [`DocumenterTools.generate`](@ref) from the `DocumenterTools` package
    can generate the basic structure that Documenter expects.

Firstly, we need a Julia module to document. This could be a package generated via
`PkgDev.generate` or a single `.jl` script accessible via Julia's `LOAD_PATH`. For this
guide we'll be using a package called `Example.jl` that has the following directory layout:

```
Example/
├── src/
│   └── Example.jl
...
```

Note that the `...` just represent unimportant files and folders.

We must decide on a location where we'd like to store the documentation for this package.
It's recommended to use a folder named `docs/` in the toplevel of the package, like so

```
Example/
├── docs/
│   └── ...
├── src/
│   └── Example.jl
...
```

Inside the `docs/` folder we need to add two things. A source folder which will contain the
markdown files that will be used to build the finished document and a Julia script that will
be used to control the build process. The following names are recommended

```
docs/
├── src/
└── make.jl
```


## Building an Empty Document

With our `docs/` directory now setup we're going to build our first document. It'll just be
a single empty file at the moment, but we'll be adding to it later on.

Add the following to your `make.jl` file

```julia
using Documenter, Example

makedocs(sitename="My Documentation")
```

This assumes you've installed Documenter as discussed in [Installation](@ref) and that your
`Example.jl` package can be found by Julia. If your package has been added as a dev
dependency using its local path rather than a remote git repository, you need to add the
keyword argument `remotes = nothing` to the function `makedocs`.

!!! note

    If your source directory is not accessible through Julia's LOAD_PATH, you might wish to
    add the following line at the top of make.jl

    ```julia
    push!(LOAD_PATH,"../src/")
    ```

Now add an `index.md` file to the `src/` directory.

!!! note
    If you use Documenter's default HTML output the name `index.md` is mandatory.
    This file will be the main page of the rendered HTML documentation.

Leave the newly added file empty and then run the following command from the `docs/` directory

```sh
$ julia --project make.jl
```

Note that `$` just represents the prompt character. You don't need to type that.

If you'd like to see the output from this command in color use

```sh
$ julia --color=yes --project make.jl
```

When you run that you should see the following output

```
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```

The `docs/` folder should contain a new directory -- called `build/`. Its structure should
look like the following

```
build/
├── assets
│   ├── documenter.js
│   ├── themes
│   │   ├── documenter-dark.css
│   │   └── documenter-light.css
│   ├── themeswap.js
│   └── warner.js
├── index.html
├── search
│   └── index.html
└── search_index.js
```

!!! note

    By default, Documenter has pretty URLs enabled, which means that `src/foo.md` is turned
    into `src/foo/index.html`, instead of simply `src/foo.html`, which is the preferred way
    when creating a set of HTML to be hosted on a web server.

    However, this can be a hindrance when browsing the documentation locally as browsers
    do not resolve directory URLs like `foo/` to `foo/index.html` for local files. To view
    the documentation locally, it is recommended that you run a local web server out of
    the `docs/build` directory. One way to accomplish this is to install the
    [LiveServer](https://github.com/JuliaDocs/LiveServer.jl) Julia package. You can then
    start the server with `julia -e 'using LiveServer; serve(dir="docs/build")'`.
    Alternatively, if you have Python installed, you can start one with
    `python3 -m http.server --bind localhost`.


!!! warning

    You may see setups using

    ```julia
    makedocs(...,
        format = Documenter.HTML(
            prettyurls = get(ENV, "CI", nothing) == "true"
        )
    )
    ```

    The intent behind this is to use `prettyurls=false` when building the documentation
    locally, for easy browsing, and `prettyurls=true` when deploying the documentation
    online from GitHub Actions.

    However, this is not recommended. For example, if a
    [`@raw` block](@ref @raw-format-block) references a local image, the correct relative
    path of that image would depend on the `prettyurls` setting ([#921](@ref)). Consequently, the
    documentation might build correctly locally and be broken on Github Actions, or vice
    versa. It is recommended to always use `prettyurls=true` and run a local web server
    to view the documentation.

!!! warning

    **Never** `git commit` the contents of `build` (or any other content generated by
    Documenter) to your repository's `master` branch. Always commit generated files to the
    `gh-pages` branch of your repository. This helps to avoid including unnecessary changes
    for anyone reviewing commits that happen to include documentation changes.

    See the [Hosting Documentation](@ref) section for details regarding how you should go
    about setting this up correctly.

At this point `build/index.html` should be an empty page since `src/index.md` is empty. You
can try adding some text to `src/index.md` and re-running the `make.jl` file to see the
changes.


## Adding Some Docstrings

Next we'll splice a docstring defined in the `Example` module into the `index.md` file. To
do this first document a function in that module:

```julia
module Example

export func

"""
    func(x)

Return double the number `x` plus `1`.
"""
func(x) = 2x + 1

end
```

Then in the `src/index.md` file add the following

````markdown
# Example.jl Documentation

```@docs
func(x)
```
````

When we next run `make.jl` the docstring for `Example.func(x)` should appear in place of
the `@docs` block in `build/index.md`. Note that *more than one* object can be referenced
inside a `@docs` block -- just place each one on a separate line.

Note that a `@docs` block is evaluated in the `Main` module. This means that each object
listed in the block must be visible there. The module can be changed to something else on
a per-page basis with a `@meta` block as in the following

````markdown
# Example.jl Documentation

```@meta
CurrentModule = Example
```

```@docs
func(x)
```
````

### Filtering included docstrings

In some cases you may want to include a docstring for a `Method` that extends a
`Function` from a different module -- such as `Base`. In the following example we extend
`Base.length` with a new definition for the struct `T` and also add a docstring:

```julia
struct T
    # ...
end

"""
Custom `length` docs for `T`.
"""
Base.length(::T) = 1
```

When trying to include this docstring with

````markdown
```@docs
length
```
````

all the docs for `length` will be included -- even those from other modules. There are two
ways to solve this problem. Either include the type in the signature with

````markdown
```@docs
length(::T)
```
````

or declare the specific modules that [`makedocs`](@ref) should include with

```julia
makedocs(
    # options
    modules = [MyModule]
)
```


## Cross Referencing

It may be necessary to refer to a particular docstring or section of your document from
elsewhere in the document. To do this we can make use of Documenter's cross-referencing
syntax which looks pretty similar to normal markdown link syntax. Replace the contents of
`src/index.md` with the following

````markdown
# Example.jl Documentation

```@docs
func(x)
```

- link to [Example.jl Documentation](@ref)
- link to [`func(x)`](@ref)
````

So we just have to replace each link's url with `@ref` and write the name of the thing we'd
link to cross-reference. For document headers it's just plain text that matches the name of
the header and for docstrings enclose the object in backticks.

This also works across different pages in the same way. Note that these sections and
docstrings must be unique within a document.


## External Cross-References

Any project building its documentation with the most recent release of Documenter will
generate an [`objects.inv` inventory](https://juliadocs.org/DocInventories.jl/stable/formats/#Sphinx-Inventory-Format)
that can be found in the root of the [deployed documentation](@ref Hosting-Documentation).
The [`DocumenterInterLinks` plugin](https://github.com/JuliaDocs/DocumenterInterLinks.jl#readme)
allows to define a mapping in your `make.jl` file between an external project name
and its inventory file, e.g.,

```julia
using DocumenterInterLinks

links = InterLinks(
    "Documenter" => "https://documenter.juliadocs.org/stable/objects.inv"
)
```

That `InterLinks` object should then be passed to [`makedocs`](@ref) as an element of
`plugins`. This enables the ability to cross-reference into the external documentation,
e.g.,  of the `Documenter` package, using an [`@extref` link](@ref) with a syntax similar
to the above [`@ref`](@ref Cross-Referencing), e.g.,

```markdown
See the [`Documenter.makedocs`](@extref) function.
```

See the [documentation of the `DocumenterInterLinks` package](http://juliadocs.org/DocumenterInterLinks.jl/stable/)
for more details.


## Navigation

Documenter can auto-generate tables of contents and docstring indexes for your document with
the following syntax. We'll illustrate these features using our `index.md` file from the
previous sections. Add the following to that file

````markdown
# Example.jl Documentation

```@contents
```

## Functions

```@docs
func(x)
```

## Index

```@index
```
````

The `@contents` block will generate a nested list of links to all the section headers in
the document. By default it will gather all the level 1 and 2 headers from every page in the
document, but this can be adjusted using `Pages` and `Depth` settings as in the following

````markdown
```@contents
Pages = ["foo.md", "bar.md"]
Depth = 3
```
````

The `@index` block will generate a flat list of links to all the docs that that have been
spliced into the document using `@docs` blocks. As with the `@contents` block the pages to
be included can be set with a `Pages = [...]` line. Since the list is not nested `Depth` is
not supported for `@index`.


## Pages in the Sidebar

By default all the pages (`.md` files) in your source directory get added to the sidebar,
sorted by their filenames. However, in most cases you want to use the `pages` argument to
[`makedocs`](@ref) to control how the sidebar looks like. The basic usage is as follows:

```julia
makedocs(
    ...,
    pages = [
        "page.md",
        "Page title" => "page2.md",
        "Subsection" => [
            ...
        ]
    ]
)
```

Using the `pages` argument you can organize your pages into subsections and hide some pages
from the sidebar with the help of the [`hide`](@ref) functions.


## Adding a logo or icon

You can easily add a logo or icon to your documentation which
will be automatically displayed in the navigation sidebar.

During the build process, Documenter looks for suitable
graphic images in the `src/assets/` directory and
automatically copies them to `/build/assets/`.

You can use SVG, PNG, WEBP, GIF, or JPEG images.

Documenter looks for files `logo.svg`, `logo.png`,
`logo.webp`, `logo.gif`, `logo.jpg`, or `logo.jpeg`, in that
order. The first suitable image found is used.

This image will be used for both light and dark themes. If
you want to create a separate design for the dark theme, add a file
called `logo-dark.svg` (or PNG/WEBP/GIF/JPEG).

Files don't need to be square. Images with transparent
backgrounds can look better, particularly for dark themes.

There's a `sidebar_sitename` keyword option for
[`Documenter.HTML`](@ref) that lets you hide the sitename
that's usually displayed below a logo. This is useful if the
logo already contains the name.
