# Package Guide

## Installation

Lapidary is currently not registered and so must be installed via `Pkg.clone`.

```julia
Pkg.clone("https://github.com/MichaelHatherly/Lapidary.jl")
```

This package supports Julia `0.4` and `0.5`.

## Usage

Lapidary is designed to do one thing -- combine markdown files and inline docstrings from
Julia's docsystem into a single inter-linked document. What follows is a step-by-step guide
to creating a simple document.

### Setting up the folder structure

Firstly, we need a Julia module to document. This could be a package generated via
`PkgDev.generate` or a single `.jl` script. For this guide we'll be using a package called
`Example.jl` that has the following directory layout:

    Example/
        src/
            Example.jl
        ...

Note that the `...` just represent unimportant files and folders.

We must decide on a location where we'd like to store the documentation for this package.
It's recommended to use a folder named `docs/` in the toplevel of the package, like so

    Example/
        docs/
            ...
        src/
            Example.jl
        ...

Inside the `docs/` folder we need to add two things. A source folder which will contain the
markdown files that will be used to build the finished document and a Julia script that will
be used to control the build process. The following names are recommended

    docs/
        src/
        make.jl

### Building an empty document

With our `docs/` directory now setup we're going to build our first document. It'll just be
a single empty file at the moment, but we'll be adding to it later on.

Add the following to your `make.jl` file

```julia
using Lapidary, Example

makedocs()
```

This assumes you've installed Lapidary as discussed in [Installation]({ref}) and that your
Examples package can be found by Julia.

Now add an `index.md` file to the `src/` directory. The name has no particular significance
though and you may name it whatever you like. We'll stick to `index.md` for this guide.

Leave the newly added file empty and the run the following command from the `docs/` directory

```sh
$ julia make.jl
```

Note that `$` just represents the prompt character. You don't need to type that.

If you'd like to see the output from this command in color use

```sh
$ julia --color=yes make.jl
```

We you run that you should see the following output

    LAPIDARY: setting up build directory.
    LAPIDARY: copying assets to build directory.
    LAPIDARY: parsing markdown templates.
    LAPIDARY: expanding parsed template files.
    LAPIDARY: generating cross-reference links.
    LAPIDARY: running doctests.
    LAPIDARY: rending final document to file.

The `docs/` folder should contain a new directory -- called `build/`. It's structure should
look like the following

    build/
        assets/
            Lapidary.css
            mathjaxhelper.js
        index.md

At the moment `build/index.md` should be empty since `src/index.md` is empty.

At this point you can add some text to `src/index.md` and rerun the `make.jl` file to see
the changes if you'd like to.

### Adding some docstrings

Next we'll splice a docstring defined in the `Example` module into the `index.md` file. To
do this first document a function in that module:

```julia
module Example

export func

"""
    func(x)

Returns double the number `x` plus `1`.
"""
func(x) = 2x + 1

end
```

Then in the `src/index.md` file add the following

```markdown
# Example.jl Documentation

    {docs}
    func(x)
```

When we next run `make.jl` the docstring for `Example.func(x)` should appear in place of
the `{docs}` block in `build/index.md`. Note that *more than one* object can be referenced
inside a `{docs}` block -- just place each one on a separate line.

Note that the module in which a `{docs}` block is evaluated is determined by
`current_module()` and so will more than likely be `Main`. This means that each object
listed in the block must be visible there. The module can be changed to something else on
a per-page basis with a `{meta}` block as in the following

```markdown
# Example.jl Documentation

    {meta}
    CurrentModule = Lapidary

...

    {docs}
    func(x)
```

Note that the `...` in the example above is just there to stop the code blocks from merging
into a single block. You could use fenced code blocks instead to avoid needing to have to
break up the blocks using extra text.

### Cross Referencing

It may be necessary to refer to a particular docstring or section of your document from
elsewhere in the document. To do this we can make use of Lapidary's cross-referencing
syntax which looks pretty similar to normal markdown link syntax. Replace the contents of
`src/index.md` with the following

```markdown
# Example.jl Documentation

    {docs}
    func(x)

- link to [Example.jl Documentation]({ref})
- link to [`func(x)`]({ref})
```

So we just have to replace each link's url with `{ref}` and write the name of the thing we'd
link to cross-reference. For document headers it's just plain text that matches the name of
the header and for docstrings enclose the object in backticks.

This also works across different pages in the same way. Note that these sections and
docstrings must be unique within a document.

### Navigation

Lapidary can auto-generate tables of contents and docstring indexes for your document with
the following syntax. We'll illustrate these features using our `index.md` file from the
previous sections. Add the following to that file

```markdown
# Example.jl Documentation

    {contents}

## Functions

    {docs}
    func(x)

## Index

    {index}
```

The `{contents}` block will generate a nested list of links to all the section headers in
the document. By default it will gather all the level 1 and 2 headers from every page in the
document, but this can be adjusted using `Pages` and `Depth` settings as in the following

```
    {contents}
    Pages = ["foo.md", "bar.md"]
    Depth = 3
```

The `{index}` block will generate a flat list of links to all the docs that that have been
spliced into the document using `{docs}` blocks. As with the `{contents}` block the pages to
be included can be set with a `Pages = [...]` line. Since the list is not nested `Depth` is
not supported for `{index}`.

## Syntax

This section provides a quick summary of the available syntax and it's meaning.

### `{ref}`

Used in markdown links as the url to tell Lapidary to generate a cross-reference
automatically. The text part of the link can be either a docstring or header name.

    [Foo]({ref})   # Link to the section called "Foo".
    [`bar`]({ref}) # Link to the docstring called `bar`.

### `{docs}`

Splice a collection of docstrings into a document.

```
    {docs}
    Foo
    bar(x)
    @baz(x, y)
```

### `{meta}`

Used to define any number of metadata key/value pairs that can then be used elsewhere in the
page. Currently `CurrentModule = ...` is the only recognised pair.

```
    {meta}
    CurrentModule = FooBar
```

### `{index}`

Generates a list of links to docstrings that have been spliced into a document. The only
valid setting is currently `Pages = ...`.

```
    {index}
    Pages = ["foo.md"]
```

When `Pages` is not provided all pages in the document are included.

### `{contents}`

Generates a nested list of links to document sections. Valid settings are `Pages` and `Depth`.

```
    {contents}
    Pages = ["foo.md"]
    Depth = 5
```

As with `{index}` if `Pages` is not provided then all pages are included. The default
`Depth` value is `2`.
