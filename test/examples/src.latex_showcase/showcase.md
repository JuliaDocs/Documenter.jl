# Style showcase for ``\LaTeX``

This page showcases the various page elements that are supported by Documenter.

## Table of contents

A table of contents can be generated with an [`@contents` block](@ref).
The one for this page renders as

```@contents
Pages = ["showcase.md"]
```

## Basic Markdown

Documenter can render all the [Markdown syntax supported by the Julia Markdown parser](https://docs.julialang.org/en/v1/stdlib/Markdown/).
You can use all the usual markdown syntax, such as **bold text** and _italic text_ and `print("inline code")`.

## Code blocks

Code blocks are rendered as follows:

```
This is an non-highlighted code block.
... Rendered in monospace.
```

When the language is specified for the block, e.g. by starting the block with ````` ```julia`````, the contents gets highlighted appropriately (for the language that are supported by the highlighter).

```julia
function foo(x::Integer)
    @show x + 1
end
```

## Mathematics

For mathematics, both inline and display equations are available.
Inline equations should be written as LaTeX between two backticks,
e.g. ``` ``A x^2 + B x + C = 0`` ```.
It will render as ``A x^2 + B x + C = 0``.

The LaTeX for display equations must be wrapped in a ````` ```math ````` code block and will render like

```math
x_{1,2} = \frac{-B \pm \sqrt{B^2 - 4 A C}}{2A}
```

By default, the HTML output renders equations with [KaTeX](https://katex.org/), but [MathJax](https://www.mathjax.org/) can optionally be used as well.

!!! warning
    Similar to LaTeX, using `$` and `$$` to escape inline and display equations
    also works. However, doing so is deprecated and this functionality may be
    removed in a future release.

## Images

Include images using basic Markdown syntax:

![Enter a descriptive caption for the image](logo.png)

The path should be relative to the directory of the current file. Alternatively,
use `./` to begin a path relative to the `src` of the documents, e.g.,
`./logo.png`.

## Admonitions

Admonitions are colorful boxes used to highlight parts of the documentation.

Each admonition begins with three `!!!`, and then the content is indented
underneath with four spaces:
```
!!! note "An optional title"
    Here is something you should pay attention to.
```

Documenter supports a range of admonition types for different circumstances.

###### Note admonition
!!! note "'note' admonition"
    Admonitions look like this. This is a `!!! note`-type admonition.

    Note that admonitions themselves can contain other block-level elements too,
    such as code blocks. E.g.

    ```julia
    f(x) = x^2
    ```

    However, you **can not** have at-blocks, docstrings, doctests etc. in an admonition.

    Headings are OK though:
    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

###### Info admonition
!!! info "'info' admonition"
    This is a `!!! info`-type admonition. This is the same as a `!!! note`-type.

###### Tip admonition
!!! tip "'tip' admonition"
    This is a `!!! tip`-type admonition.

###### Warning admonition
!!! warning "'warning' admonition"
    This is a `!!! warning`-type admonition.

###### Danger admonition
!!! danger "'danger' admonition"
    This is a `!!! danger`-type admonition.

###### Compat admonition
!!! compat "'compat' admonition"
    This is a `!!! compat`-type admonition.

###### Unknown admonition class
!!! ukw "Unknown admonition class"
    Admonition with an unknown admonition class. This is a `code example`.

## Lists

Tight lists look as follows

* Lorem ipsum dolor sit amet, consectetur adipiscing elit.
* Nulla quis venenatis justo.
* In non _sodales_ eros.

If the lists contain paragraphs or other block level elements, they look like this:

* Morbi et varius nisl, eu semper orci.

  Donec vel nibh sapien. Maecenas ultricies mauris sapien. Nunc et sem ac justo ultricies dignissim ac vitae sem.

* Nulla molestie aliquet metus, a dapibus ligula.

  Morbi pellentesque sodales sollicitudin. Fusce semper placerat suscipit. Aliquam semper tempus ex, non efficitur erat posuere in. Fusce at orci eu ex sagittis commodo.

  > Fusce tempus scelerisque egestas. Pellentesque varius nulla a varius fringilla.

  Fusce nec urna eu orci porta blandit.

Numbered lists are also supported

1. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
2. Nulla quis venenatis justo.
3. In non _sodales_ eros.

As are nested lists

* Morbi et varius nisl, eu semper orci.

  Donec vel nibh sapien. Maecenas ultricies mauris sapien. Nunc et sem ac justo ultricies dignissim ac vitae sem.

  - Lorem ipsum dolor sit amet, consectetur adipiscing elit.
  - Nulla quis venenatis justo.
  - In non _sodales_ eros.

* Nulla molestie aliquet metus, a dapibus ligula.

  1. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
  2. Nulla quis venenatis justo.
  3. In non _sodales_ eros.

  Fusce nec urna eu orci porta blandit.

Lists can also be included in other blocks that can contain block level items

!!! note "Bulleted lists in admonitions"

    * Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    * Nulla quis venenatis justo.
    * In non _sodales_ eros.

!!! note "Large lists in admonitions"

    * Morbi et varius nisl, eu semper orci.

      Donec vel nibh sapien. Maecenas ultricies mauris sapien. Nunc et sem ac justo ultricies dignissim ac vitae sem.

      - Lorem ipsum dolor sit amet, consectetur adipiscing elit.
      - Nulla quis venenatis justo.
      - In non _sodales_ eros.

    * Nulla molestie aliquet metus, a dapibus ligula.

      1. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
      2. Nulla quis venenatis justo.
      3. In non _sodales_ eros.

      Fusce nec urna eu orci porta blandit.

> * Morbi et varius nisl, eu semper orci.
>
>   Donec vel nibh sapien. Maecenas ultricies mauris sapien. Nunc et sem ac justo ultricies dignissim ac vitae sem.
>
>   - Lorem ipsum dolor sit amet, consectetur adipiscing elit.
>   - Nulla quis venenatis justo.
>   - In non _sodales_ eros.

## Tables

| object | implemented |      value |
|--------|-------------|------------|
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |

With explicit alignment.

| object | implemented |      value |
| :---   |    :---:    |       ---: |
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |
| `CC`   |      v      | 1000000.00 |

Huges tables get scaled down:

```@eval
using Markdown
nrows, ncols = 10, 50
table = Markdown.Table(
    [[[string(i, "-", j)] for j = 1:ncols] for i = 1:nrows],
    [:c for _ in 1:ncols],
)
Markdown.MD([table])
```

Including ones generated by at-example blocks with `show` methods:

```@example
using Markdown
nrows, ncols = 5, 5
table = Markdown.Table(
    [[[string(i, "-", j)] for j = 1:ncols] for i = 1:nrows],
    [:c for _ in 1:ncols],
)
Markdown.MD([table])
```

```@example
using Markdown
nrows, ncols = 10, 50
table = Markdown.Table(
    [[[string(i, "-", j)] for j = 1:ncols] for i = 1:nrows],
    [:c for _ in 1:ncols],
)
Markdown.MD([table])
```

However, tables with huge cells are not properly handled right now:

| object | implemented |      value |
| :---   |    :---:    |       ---: |
| `A`    |      ✓      |      10.00 |
| `BBBBBBBBBBBBBBBBBBBB` | ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓ | 1000000000000000000000000000000000000000000000000000000.00 |

## Footnotes

Footnote references can be added with the `[^label]` syntax.[^1] The footnote definitions get collected at the bottom of the page.

The footnote label can be an arbitrary string and even consist of block-level elements.[^Clarke61]

[^1]: A footnote definition uses the `[^label]: ...` syntax in a block scope.

[^Clarke61]:
    > Any sufficiently advanced technology is indistinguishable from magic.
    Arthur C. Clarke, _Profiles of the Future_ (1961): Clarke's Third Law.

Footnote with more block contents.[^footblock]

[^footblock]:

    And a link to another footnote[^1].

    !!! note "Admonition.."

        .. in a footnote.

## Headings

Finally, headings render as follows

### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

To see an example of a level 1 heading see the page title and for level 2 heading, see the one just under this paragraph.

!!! note "Headings in sidebars"
    Level 1 and 2 heading show up in the sidebar, for the current page.

## Doctesting example

Often you want to write code example such as this:

```jldoctest
julia> f(x) = x^2
f (generic function with 1 method)

julia> f(3)
9
```

If you write them as a ````` ```jldoctest ````` code block, Documenter can make sure that the doctest has not become outdated. See [Doctests](@ref) for more information.

Script-style doctests are supported too:

```jldoctest
2 + 2
# output
4
```

## Running interactive code

[`@example` block](@ref) run a code snippet and insert the output into the document.
E.g. the following Markdown

````markdown
```@example
typeof(π)
```
````

becomes the following code-output block pair

```@example
typeof(π)
```

If the last element can be rendered as `text/latex`:

```@example latexrender
struct LaTeXRender
    s :: String
end
function Base.show(io, ::MIME"text/latex", r::LaTeXRender)
    write(io, """
    Rendering \\texttt{LaTeXRender}: $(r.s)
    """)
end
nothing # hide
```

```@example latexrender
LaTeXRender("render this")
```

If the last value in an `@example` block is a `nothing`, the standard output from the blocks' evaluation gets displayed instead

```@example
println("Hello World")
```

However, do note that if the block prints to standard output, but also has a final non-`nothing` value, the standard output just gets discarded:

```@example
println("Hello World")
42
```

### at-REPL blocks

```@repl
(1 // 2)^2
```

```@repl
x = 1

x // 2

ans^2
```

## Setup blocks

`SetupNode` with `x = 5`...

```@setup foo
x = 5
```

...makes the following evaluate to...

```@example foo
x + 1
```

### Color output

Output from [`@repl` block](@ref)s and [`@example` block](@ref)s support colored output,
transforming ANSI color codes to HTML.

#### Colored `@repl` block output

**Input:**
````markdown
```@repl
printstyled("This should be in bold light cyan.", color=:light_cyan, bold=true)
```
````

**Output:**
```@repl
printstyled("This should be in bold cyan.", color=:cyan, bold=true)
```

**Locally disabled color:**
````markdown
```@repl; ansicolor=false
printstyled("This should be in bold light cyan.", color=:light_cyan, bold=true)
```
````
```@repl; ansicolor=false
printstyled("This should be in bold light cyan.", color=:light_cyan, bold=true)
```

#### Raw ANSI code output

Regardless of the color setting, when you print the ANSI escape codes directly, coloring is
enabled.
```@example
for color in 0:15
    print("\e[38;5;$color;48;5;$(color)m  ")
    print("\e[49m", lpad(color, 3), " ")
    color % 8 == 7 && println()
end
print("\e[m")
```

## Doctest showcase

Currently exists just so that there would be doctests to run in manual pages of Documenter's
manual. This page does not show up in navigation.

```jldoctest
julia> 2 + 2
4
```

The following doctests needs doctestsetup:

```jldoctest; setup=:(using Documenter)
julia> Documenter.splitexpr(:(Foo.Bar.baz))
(:(Foo.Bar), :(:baz))
```

Let's also try `@meta` blocks:

```@meta
DocTestSetup = quote
  f(x) = x^2
end
```

```jldoctest
julia> f(2)
4
```

```@meta
DocTestSetup = nothing
```

## at-raw blocks

Only one of them should end up in the output.

```@raw html
foo
```
```@raw latex
bar
```

## Cross-references

Here we link to the heading [Cross-references](@ref).
[This](@ref "Cross-references") also links there.

We can also link to other pages, such as: [An index of docstrings](@ref).

Then there are link to docstrings: [`Foo.bar`](@ref), [`foobar`](@ref Foo.bar), [foobar](@ref Foo.bar).

And issue references: [#1245](@ref)

### `@example`-block
### `@contents`-block
### `@repl`-block

## Contents

```@contents
```
