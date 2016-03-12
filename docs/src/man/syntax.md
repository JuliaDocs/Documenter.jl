# Syntax

This section of the manual summarises the special syntax used by Lapidary.

## `{ref}`

Used in markdown links as the url to tell Lapidary to generate a cross-reference
automatically. The text part of the link can be either a docstring or header name.

    [Foo]({ref})   # Link to the section called "Foo".
    [`bar`]({ref}) # Link to the docstring called `bar`.

## `{docs}`

Splice a collection of docstrings into a document.

```
    {docs}
    Foo
    bar(x)
    @baz(x, y)
```

## `{meta}`

Used to define any number of metadata key/value pairs that can then be used elsewhere in the
page. Currently `CurrentModule = ...` is the only recognised pair.

```
    {meta}
    CurrentModule = FooBar
```

## `{index}`

Generates a list of links to docstrings that have been spliced into a document. The only
valid setting is currently `Pages = ...`.

```
    {index}
    Pages = ["foo.md"]
```

When `Pages` is not provided all pages in the document are included.

## `{contents}`

Generates a nested list of links to document sections. Valid settings are `Pages` and `Depth`.

```
    {contents}
    Pages = ["foo.md"]
    Depth = 5
```

As with `{index}` if `Pages` is not provided then all pages are included. The default
`Depth` value is `2`.

## `{eval}`

Evaluates the contents of the block and inserts the resulting value into the final document.

In the following example we use the PyPlot package to generate a plot and display it in the
final document.

```
    {eval}
    using PyPlot

    x = linspace(-π, π)
    y = sin(x)

    plot(x, y, color = "red")
    savefig("plot.svg")

    nothing

![](plot.svg)
```

Note that each `{eval}` block evaluates its contents within a separate module. When
evaluating each block the present working directory, `pwd`, is set to the directory in
`build` where the file will be written to.

Also, instead of returning `nothing` in the example above we could have returned a new
`Markdown.Image` object directly. This can be more appropriate when the filename is not
known until evaluation of the block itself.
