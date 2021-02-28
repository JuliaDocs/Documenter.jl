# Syntax

This section of the manual describes the syntax used by Documenter to build documentation.
For supported Markdown syntax, see the [documentation for the Markdown standard library in the Julia manual](https://docs.julialang.org/en/v1/stdlib/Markdown/).

```@contents
Pages = ["syntax.md"]
```

## `@docs` block

Splice one or more docstrings into a document in place of the code block, i.e.

````markdown
```@docs
Documenter
makedocs
deploydocs
```
````

This block type is evaluated within the `CurrentModule` module if defined, otherwise within
`Main`, and so each object listed in the block should be visible from that
module. Undefined objects will raise warnings during documentation generation and cause the
code block to be rendered in the final document unchanged.

Objects may not be listed more than once within the document. When duplicate objects are
detected an error will be raised and the build process will be terminated.

To ensure that all docstrings from a module are included in the final document the `modules`
keyword for [`makedocs`](@ref) can be set to the desired module or modules, i.e.

```julia
makedocs(
    modules = [Documenter],
)
```

which will cause any unlisted docstrings to raise warnings when [`makedocs`](@ref) is
called. If `modules` is not defined then no warnings are printed, even if a document has
missing docstrings.

Notice also that you can use `@docs` to display the documentation strings of only specific
methods, by stating the dispatch types. For example
````markdown
```@docs
f(::Type1, ::Type2)
```
````
will only display the documentation string of `f` that is related to these types.
This can be useful when your module extends a function and adds a documentation
string to that new method.

Note that when specifying signatures, it should match the method definition exactly.
Documenter will not match methods based on dispatch rules. For example, assuming you
have a docstring attached to `foo(::Integer) = ...`, then neither `foo(::Number)` nor
`foo(::Int64)` will match it in an at-docs block (even though `Int64 <: Integer <: Number`).
The only way you can splice that docstring is by listing exactly `foo(::Integer)` in
the at-docs block.


## `@autodocs` block

Automatically splices all docstrings from the provided modules in place of the code block.
This is equivalent to manually adding all the docstrings in a `@docs` block.

````markdown
```@autodocs
Modules = [Foo, Bar, Bar.Baz]
Order   = [:function, :type]
```
````

The above `@autodocs` block adds all the docstrings found in modules `Foo`, `Bar`, and `Bar.Baz` that
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

In addition to `Order`, a `Pages` vector may be included in `@autodocs` to filter docstrings
based on the source file in which they are defined:

````markdown
```@autodocs
Modules = [Foo]
Pages   = ["a.jl", "b.jl"]
```
````

In the above example docstrings from module `Foo` found in source files that end in `a.jl`
and `b.jl` are included. The page order provided by `Pages` is also used to sort the
docstrings. Note that page matching is done using the end of the provided strings and so
`a.jl` will be matched by *any* source file that ends in `a.jl`, i.e. `src/a.jl` or
`src/foo/a.jl`.

To filter out certain docstrings by your own criteria, you can provide function with the
`Filter` keyword:

````markdown
```@autodocs
Modules = [Foo]
Filter = t -> typeof(t) === DataType && t <: Foo.C
```
````

In the given example, only the docstrings of the subtypes of `Foo.C` are shown. Instead
of an [anonymous function](https://docs.julialang.org/en/v1/manual/functions/index.html#man-anonymous-functions-1)
you can give the name of a function you defined beforehand, too:

````markdown
```@autodocs
Modules = [Foo]
Filter =  myCustomFilterFunction
```
````

To include only the exported names from the modules listed in `Modules` use `Private = false`.
In a similar way `Public = false` can be used to only show the unexported names. By
default both of these are set to `true` so that all names will be shown.

````markdown
Functions exported from `Foo`:

```@autodocs
Modules = [Foo]
Private = false
Order = [:function]
```

Private types in module `Foo`:

```@autodocs
Modules = [Foo]
Public = false
Order = [:type]
```
````

!!! note

    When more complex sorting is needed then use `@docs` to define it
    explicitly.

## `@ref` link

Used in markdown links as the URL to tell Documenter to generate a cross-reference
automatically. The text part of the link can be a docstring, header name, or GitHub PR/Issue
number.

````markdown
# Syntax

... [`makedocs`](@ref) ...

# Functions

```@docs
makedocs
```

... [Syntax](@ref) ...

... [#42](@ref) ...
````

Plain text in the "text" part of a link will either cross-reference a header, or, when it is
a number preceded by a `#`, a GitHub issue/pull request. Text wrapped in backticks will
cross-reference a docstring from a `@docs` block.

`@ref`s may refer to docstrings or headers on different pages as well as the current page
using the same syntax.

Note that depending on what the `CurrentModule` is set to, a docstring `@ref` may need to
be prefixed by the module which defines it.

### Duplicate Headers

In some cases a document may contain multiple headers with the same name, but on different
pages or of different levels. To allow `@ref` to cross-reference a duplicate header it must
be given a name as in the following example

```markdown
# [Header](@id my_custom_header_name)

...

## Header

... [Custom Header](@ref my_custom_header_name) ...
```

The link that wraps the named header is removed in the final document. The text for a named
`@ref ...` does not need to match the header that it references. Named `@ref ...`s may refer
to headers on different pages in the same way as unnamed ones do.

Duplicate docstring references do not occur since splicing the same docstring into a
document more than once is disallowed.

### Named doc `@ref`s

Docstring `@ref`s can also be "named" in a similar way to headers as shown in the
[Duplicate Headers](@ref) section above. For example

```julia
module Mod

"""
Both of the following references point to `g` found in module `Main.Other`:

  * [`Main.Other.g`](@ref)
  * [`g`](@ref Main.Other.g)

"""
f(args...) = # ...

end
```

This can be useful to avoid having to write fully qualified names for references that
are not imported into the current module, or when the text displayed in the link is
used to add additional meaning to the surrounding text, such as

```markdown
Use [`for i = 1:10 ...`](@ref for) to loop over all the numbers from 1 to 10.
```

!!! note

    Named doc `@ref`s should be used sparingly since writing unqualified names may, in some
    cases, make it difficult to tell *which* function is being referred to in a particular
    docstring if there happen to be several modules that provide definitions with the same
    name.

## `@meta` block

This block type is used to define metadata key/value pairs that can be used elsewhere in the
page. Currently recognised keys:
- `CurrentModule`: module where Documenter evaluates, for example, [`@docs`-block](@ref)
  and [`@ref`-link](@ref)s.
- `DocTestSetup`: code to be evaluated before a doctest, see the [Setup Code](@ref)
  section under [Doctests](@ref).
- `DocTestFilters`: filters to deal with, for example, unpredictable output from doctests,
  see the [Filtering Doctests](@ref) section under [Doctests](@ref).
- `EditURL`: link to where the page can be edited. This defaults to the `.md` page itself,
  but if the source is something else (for example if the `.md` page is generated as part of
  the doc build) this can be set, either as a local link, or an absolute url.

Example:

````markdown
```@meta
CurrentModule = FooBar
DocTestSetup  = quote
    using MyPackage
end
DocTestFilters = [r"Stacktrace:[\s\S]+"]
EditURL = "link/to/source/file"
```
````

Note that `@meta` blocks are always evaluated in `Main`.

## `@index` block

Generates a list of links to docstrings that have been spliced into a document. Valid
settings are `Pages`, `Modules`, and `Order`. For example:

````markdown
```@index
Pages   = ["foo.md"]
Modules = [Foo, Bar]
Order   = [:function, :type]
```
````

When `Pages` or `Modules` are not provided then all pages or modules are included. `Order`
defaults to

```julia
[:module, :constant, :type, :function, :macro]
```

if not specified. `Order` and `Modules` behave the same way as in [`@autodocs` block](@ref)s
and filter out docstrings that do not match one of the modules or categories specified.

Note that the values assigned to `Pages`, `Modules`, and `Order` may be any valid Julia code
and thus can be something more complex that an array literal if required, i.e.

````markdown
```@index
Pages = map(file -> joinpath("man", file), readdir("man"))
```
````

It should be noted though that in this case `Pages` may not be sorted in the order that is
expected by the user. Try to stick to array literals as much as possible.

## `@contents` block

Generates a nested list of links to document sections. Valid settings are `Pages` and `Depth`.

````markdown
```@contents
Pages = ["foo.md"]
Depth = 5
```
````

As with `@index` if `Pages` is not provided then all pages are included. The default
`Depth` value is `2`.

## `@example` block

Evaluates the code block and inserts the result of the last expression into the final document along with the
original source code. If the last expression returns `nothing`, the `stdout`
and `stderr` streams of the whole block are inserted instead. A semicolon `;`
at the end of the last line has no effect.

````markdown
```@example
a = 1
b = 2
a + b
```
````

The above `@example` block will splice the following into the final document

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

!!! note
    The working directory, `pwd`, is set to the directory in `build` where the file
    will be written to, and the paths in `include` calls are interpreted to be relative to
    `pwd`. This can be customized with the `workdir` keyword of [`makedocs`](@ref).

**Hiding Source Code**

Code blocks may have some content that does not need to be displayed in the final document.
`# hide` comments can be appended to lines that should not be rendered, i.e.

````markdown
```@example
import Random # hide
Random.seed!(1) # hide
A = rand(3, 3)
b = [1, 2, 3]
A \ b
```
````

Note that appending `# hide` to every line in an `@example` block will result in the block
being hidden in the rendered document. The results block will still be rendered though.
`@setup` blocks are a convenient shorthand for hiding an entire block, including the output.

**Empty Outputs**

When an `@example` block returns `nothing`, the results block will show instead
the `stdout` and `stderr` streams produced by the whole block. If these are
empty, the results block is not displayed at all; only the source code block
will be shown in the rendered document.

**Named `@example` Blocks**

By default `@example` blocks are run in their own anonymous `Module`s to avoid side-effects
between blocks. To share the same module between different blocks on a page the `@example`
can be named with the following syntax

````markdown
```@example 1
a = 1
```

```@example 1
println(a)
```
````

The name can be any text, not just integers as in the example above, i.e. `@example foo`.

Named `@example` blocks can be useful when generating documentation that requires
intermediate explanation or multimedia such as plots as illustrated in the following example

````markdown
First we define some functions

```@example 1
using PyPlot # hide
f(x) = sin(2x) + 1
g(x) = cos(x) - x
```

and then we plot `f` over the interval from ``-π`` to ``π``

```@example 1
x = linspace(-π, π)
plot(x, f(x), color = "red")
savefig("f-plot.svg"); nothing # hide
```

![](f-plot.svg)

and then we do the same with `g`

```@example 1
plot(x, g(x), color = "blue")
savefig("g-plot.svg"); nothing # hide
```

![](g-plot.svg)
````

Note that `@example` blocks are evaluated within the directory of `build` where the file
will be rendered . This means than in the above example `savefig` will output the `.svg`
files into that directory. This allows the images to be easily referenced without needing to
worry about relative paths.

`@example` blocks automatically define `ans` which, as in the Julia REPL, is bound to the
value of the last evaluated expression. This can be useful in situations such as the
following one where where binding the object returned by `plot` to a named variable would
look out of place in the final rendered documentation:

````markdown
```@example
using Gadfly # hide
plot([sin, x -> 2sin(x) + x], -2π, 2π)
draw(SVG("plot.svg", 6inch, 4inch), ans); nothing # hide
```

![](plot.svg)
````

**Delayed Execution of `@example` Blocks**

`@example` blocks accept a keyword argument `continued` which can be set to `true` or `false`
(defaults to `false`). When `continued = true` the execution of the code is delayed until the
next `continued = false` `@example`-block. This is needed for example when the expression in
a block is not complete. Example:

````markdown
```@example half-loop; continued = true
for i in 1:3
    j = i^2
```
Some text explaining what we should do with `j`
```@example half-loop
    println(j)
end
```
````

Here the first block is not complete -- the loop is missing the `end`. Thus, by setting
`continued = true` here we delay the evaluation of the first block, until we reach the
second block. A block with `continued = true` does not have any output.

## `@repl` block

These are similar to `@example` blocks, but add a `julia> ` prompt before each toplevel
expression. The `# hide` syntax may be used in `@repl` blocks in the same way
as in `@example` blocks. Furthermore, a semicolon `;` at the end of a line will
suppress the output as in the Julia REPL.

````markdown
```@repl
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

Named `@repl <name>` blocks behave in the same way as named `@example <name>` blocks.

!!! note
    The working directory, `pwd`, is set to the directory in `build` where the file
    will be written to, and the paths in `include` calls are interpreted to be relative to
    `pwd`.  This can be customized with the `workdir` keyword of [`makedocs`](@ref).

!!! note "Soft vs hard scope"

    Julia 1.5 changed the REPL to use the _soft scope_ when handling global variables in
    `for` loops etc. When using Documenter with Julia 1.5 or above, Documenter uses the soft
    scope in `@repl`-blocks and REPL-type doctests.

## `@setup <name>` block

These are similar to `@example` blocks, but both the input and output are hidden from the
final document. This can be convenient if there are several lines of setup code that need to be
hidden.

!!! note

    Unlike `@example` and `@repl` blocks, `@setup` requires a `<name>` attribute to associate it
    with downstream `@example <name>` and `@repl <name>` blocks.

````markdown
```@setup abc
using RDatasets
using DataFrames
iris = dataset("datasets", "iris")
```

```@example abc
println(iris)
```
````


## `@eval` block

Evaluates the contents of the block and inserts the resulting value into the final document.

In the following example we use the PyPlot package to generate a plot and display it in the
final document.

````markdown
```@eval
using PyPlot

x = linspace(-π, π)
y = sin(x)

plot(x, y, color = "red")
savefig("plot.svg")

nothing
```

![](plot.svg)
````

Another example is to generate markdown tables from machine readable data formats such as CSV or JSON.

````markdown
```@eval
using CSV
using Latexify
df = CSV.read("table.csv")
mdtable(df,latex=false)
```
````

Which will generate a markdown version of the CSV file table.csv and render it in the output format.

Note that each `@eval` block evaluates its contents within a separate module. When
evaluating each block the present working directory, `pwd`, is set to the directory in
`build` where the file will be written to, and the paths in `include` calls are interpreted
to be relative to `pwd`.

Also, instead of returning `nothing` in the example above we could have returned a new
`Markdown.MD` object through `Markdown.parse`. This can be more appropriate when the
filename is not known until evaluation of the block itself.

!!! note

    In most cases `@example` is preferred over `@eval`. Just like in normal Julia code where
    `eval` should be only be considered as a last resort, `@eval` should be treated in the
    same way.


## `@raw <format>` block

Allows code to be inserted into the final document verbatim. E.g. to insert custom HTML or
LaTeX code into the output.

The `format` argument is mandatory and Documenter uses it to determine whether a particular
block should be copied over to the output or not. Currently supported formats are `html`
and `latex`, used by the respective writers. A `@raw` block whose `format` is not
recognized is usually ignored, so it is possible to have a raw block for each output format
without the blocks being duplicated in the output.

The following example shows how SVG code with custom styling can be included into documents
using the `@raw` block.

````markdown
```@raw html
<svg style="display: block; margin: 0 auto;" width="5em" heigth="5em">
	<circle cx="2.5em" cy="2.5em" r="2em" stroke="black" stroke-width=".1em" fill="red" />
</svg>
```
````

It will show up as follows, with code having been copied over verbatim to the HTML file.

```@raw html
<svg style="display: block; margin: 0 auto;" width="5em" heigth="5em">
	<circle cx="2.5em" cy="2.5em" r="2em" stroke="black" stroke-width=".1em" fill="red" />
    (SVG)
</svg>
```
