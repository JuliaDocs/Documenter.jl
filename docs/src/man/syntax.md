# Syntax

This section of the manual describes the syntax used by Documenter to build documentation.

    {contents}
    Pages = ["syntax.md"]

## `{docs}`

Splice one or more docstrings into a document in place of the code block, i.e.

```
    {docs}
    Documenter
    makedocs
    deploydocs
```

This block type is evaluated within the `CurrentModule` module if defined, otherwise within
`current_module()`, and so each object listed in the block should be visible from that
module. Undefined objects will raise warnings during documentation generation and cause the
code block to be rendered in the final document unchanged.

Objects may not be listed more than once within the document. When duplicate objects are
detected an error will be raised and the build process will be terminated.

To ensure that all docstrings from a module are included in the final document the `modules`
keyword for [`makedocs`]({ref}) can be set to the desired module or modules, i.e.

```julia
makedocs(
    modules = [Lapidary],
)
```

which will cause any unlisted docstrings to raise warnings when [`makedocs`]({ref}) is
called. If `modules` is not defined then no warnings are printed, even if a document has
missing docstrings.

## `{autodocs}`

Automatically splices all docstrings from the provided modules in place of the code block.
This is equivalent to manually adding all the docstrings in a `{docs}` block.

````markdown
{autodocs}
Modules = [Foo, Bar]
Order   = [:function, :type]
````

The above `{autodocs}` block adds all the docstrings found in modules `Foo` and `Bar` that
refer to functions or types to the document.

Each module is added in order and so all docs from `Foo` will appear before those of `Bar`.
Possible values for the `Order` vector are

- `:module`
- `:constant`
- `:type`
- `:function`
- `:macro`

If no `Order` is provided then the order listed above is used.

When a potential docstring is found in one of the listed modules, but does not match any
value from `Order` then it will be omitted from the document. Hence `Order` acts as a basic
filter as well as sorter.

**Note**

When more complex sorting and filtering is needed then use `{docs}` to define it explicitly.

## `{ref}`

Used in markdown links as the URL to tell Documenter to generate a cross-reference
automatically. The text part of the link can be either a docstring or header name.

```markdown
# Syntax

... [`makedocs`]({ref}) ...

# Functions

    {docs}
    makedocs

... [Syntax]({ref}) ...
```

Plain text in the "text" part of a link will cross-reference a header, while text in
backticks will cross-reference a docstring from a `{docs}` block. The text should match the
name of the header exactly.

`{ref}`s may refer to docstrings or headers on different pages as well as the current page
using the same syntax.

Note that depending on what the `CurrentModule` is set to, a docstring `{ref}` may need to
be prefixed by the module which defines it.

**Duplicate Headers**

In some cases a document may contain multiple headers with the same name, but on different
pages or of different levels. To allow `{ref}` to cross-reference a duplicate header it must
be given a name as in the following example

```markdown
# [Header]({ref#my-custom-header-name})

...

## Header

... [Custom Header]({ref#my-custom-header-name}) ...
```

The link that wraps the named header is removed in the final document. The text for a named
`{ref#...}` does not need to match the header that it references. Named `{ref#...}`s may
refer to headers on different pages in the same way as unnamed ones do.

Duplicate docstring references do not occur since splicing the same docstring into a
document more than once is disallowed.

## `{meta}`

This block type is used to define metadata key/value pairs that can be used elsewhere in the
page. Currently `CurrentModule` and `DocTestSetup` are the only recognised keys.

```
    {meta}
    CurrentModule = FooBar
    DocTestSetup  = quote
        using MyPackage
    end
```

Note that `{meta}` blocks are always evaluated with the `current_module()`, which is
typically `Main`.

See [Setup Code]({ref}) section of the Doctests page for an explanation of `DocTestSetup`.

## `{index}`

Generates a list of links to docstrings that have been spliced into a document. The only
valid setting is currently `Pages = ...`.

```
    {index}
    Pages = ["foo.md"]
```

When `Pages` is not provided all pages in the document are included.

Note that the `Pages` value can be any valid Julia code and so can be something more complex
that an array literal if a large number of pages must be included, i.e.

```
    {index}
    Pages = map(file -> joinpath("man", file), readdir("man"))
```

It should be noted though that in this case `Pages` may not be sorted in the order that is
expected by the user. Try to stick to array literals for `Pages` as much as possible.

## `{contents}`

Generates a nested list of links to document sections. Valid settings are `Pages` and `Depth`.

```
    {contents}
    Pages = ["foo.md"]
    Depth = 5
```

As with `{index}` if `Pages` is not provided then all pages are included. The default
`Depth` value is `2`.

## `{example}`

Evaluates the code block and inserts the result into the final document along with the
original source code.

```
    {example}
    a = 1
    b = 2
    a + b
```

The above `{example}` block will splice the following into the final document

````markdown
```julia
a = 1
b = 2
a + b
```

```
3
```
````

Leading and trailing newlines are removed from the rendered code blocks. Trailing whitespace
on each line is also removed.

**Hiding Source Code**

Code blocks may have some content that does not need to be displayed in the final document.
`# hide` comments can be appended to lines that should not be rendered, i.e.

````markdown
```julia
{example}
srand(1) # hide
A = rand(3, 3)
b = [1, 2, 3]
A \ b
```
````

Note that appending `# hide` to every line in an `{example}` block will result in the block
being hidden in the rendered document. The results block will still be rendered though.

**`STDOUT` and `STDERR`**

The Julia output streams are redirected to the results block when evaluating `{example}`
blocks in the same way as when running doctest code blocks.

**`nothing` Results**

When the `{example}` block evaluates to `nothing` then the second block is not displayed.
Only the source code block will be shown in the rendered document. Note that if any output
from either `STDOUT` or `STDERR` is captured then the results block will be displayed even
if `nothing` is returned.

**Named `{example}` Blocks**

By default `{example}` blocks are run in their own anonymous `Module`s to avoid side-effects
between blocks. To share the same module between different blocks on a page the `{example}`
can be named with the following syntax

````markdown
```julia
{example 1}
a = 1
```

```julia
{example 1}
println(a)
```
````

The name can be any text, not just integers as in the example above, i.e. `{example foo}`.

Named `{example}` blocks can be useful when generating documentation that requires
intermediate explanation or multimedia such as plots as illustrated in the following example

````markdown
First we define some functions

```julia
{example 1}
using PyPlot # hide
f(x) = sin(2x) + 1
g(x) = cos(x) - x
```

and then we plot `f` over the interval from ``-π`` to ``π``

```julia
{example 1}
x = linspace(-π, π)
plot(x, f(x), color = "red")
savefig("f-plot.svg"); nothing # hide
```

![](f-plot.svg)

and then we do the same with `g`

```julia
{example 1}
plot(x, g(x), color = "blue")
savefig("g-plot.svg"); nothing # hide
```

![](g-plot.svg)
````

Note that `{example}` blocks are evaluated within the directory of `build` where the file
will be rendered . This means than in the above example `savefig` will output the `.svg`
files into that directory. This allows the images to be easily referenced without needing to
worry about relative paths.

`{example}` blocks automatically define `ans` which, as in the Julia REPL, is bound to the
value of the last evaluated expression. This can be useful in situations such as the
following one where where binding the object returned by `plot` to a named variable would
look out of place in the final rendered documentation:

````markdown
```julia
{example}
using Gadfly # hide
plot([sin, x -> 2sin(x) + x], -2π, 2π)
draw(SVG("plot.svg", 6inch, 4inch), ans); nothing # hide
```

![](plot.svg)
````

## `{repl}`

These are similar to `{example}` blocks, but adds a `julia> ` prompt before each toplevel
expression. `;` and `# hide` syntax may be used in `{repl}` blocks in the same way as in the
Julia REPL and `{example}` blocks.

````markdown
```julia
{repl}
a = 1
b = 2
a + b
```
````

will generate

````markdown
```julia
julia> a = 1
1

julia> b = 2
2

julia> a + b
3
```
````

Named `{repl <name>}` blocks behave in the same way as named `{example <name>}` blocks.

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

**Note**

In most cases `{example}` is preferred over `{eval}`. Just like in normal Julia code where
`eval` should be only be considered as a last resort, `{eval}` should be treated in the same
way.
