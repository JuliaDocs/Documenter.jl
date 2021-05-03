# Showcase

This page showcases the various page elements that are supported by Documenter.
It should be read side-by-side with its source (`docs/src/showcase.md`) to see what syntax exactly is used to create the various elements.

## Table of contents

A table of contents can be generated with an [`@contents` block](@ref).
The one for this page renders as

```@contents
Pages = ["showcase.md"]
```

## Basic Markdown

Documenter can render all the [Markdown syntax supported by the Julia Markdown parser](https://docs.julialang.org/en/v1/stdlib/Markdown/).
You can use all the usual markdown syntax, such as **bold text** and _italic text_ and `print("inline code")`.

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

For mathematics, both inline and display equations are available.
Inline equations should be written as LaTeX between two backticks,
e.g. ``` ``A x^2 + B x + C = 0`` ```.
It will render as ``A x^2 + B x + C = 0``.

The LaTeX for display equations must be wrapped in a ````` ```math ````` code block and will render like

```math
x_{1,2} = \frac{-B \pm \sqrt{B^2 - 4 A C}}{2A}
```

By default, the HTML output renders equations with [KaTeX](https://katex.org/), but [MathJax](https://www.mathjax.org/) can optionally be used as well.

Finally, admonitions for notes, warnings and such:

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

### Lists

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

### Tables

| object | implemented |      value |
|--------|-------------|------------|
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |

With explicit alignment.

| object | implemented |      value |
| :---   |    :---:    |       ---: |
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |

Tables that are too wide should become scrollable.

| object | implemented |      value |
| :---   |    :---:    |       ---: |
| `A`    |      ✓      |      10.00 |
| `BBBBBBBBBBBBBBBBBBBB` | ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓ | 1000000000000000000000000000000000000000000000000000000.00 |


### Footnotes

Footnote references can be added with the `[^label]` syntax.[^1] The footnote definitions get collected at the bottom of the page.

The footnote label can be an arbitrary string and even consist of block-level elements.[^Clarke61]

[^1]: A footnote definition uses the `[^label]: ...` sytax in a block scope.

[^Clarke61]:
    > Any sufficiently advanced technology is indistinguishable from magic.
    Arthur C. Clarke, _Profiles of the Future_ (1961): Clarke's Third Law.

### Headings

Finally, headings render as follows

### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

To see an example of a level 1 heading see the page title and for level 2 heading, see the one just under this paragraph.

!!! note "Headings in sidebars"
    Level 1 and 2 heading show up in the sidebar, for the current page.

## Docstrings

The key feature of Documenter, of course, is the ability to automatically include docstrings
from your package in the manual. The following example docstrings come from the demo
[`DocumenterShowcase`](@ref) module, the source of which can be found in
`docs/DocumenterShowcase.jl`.

To include a docstrings into a manual page, you needs to use an [`@docs` block](@ref)

````markdown
```@docs
DocumenterShowcase
```
````

This will include a single docstring and it will look like this

```@docs
DocumenterShowcase
```

You can include the docstrings corresponding to different function signatures one by one.
E.g., the [`DocumenterShowcase.foo`](@ref) function has two signatures -- `(::Integer)` and `(::AbstractString)`.

````markdown
```@docs
DocumenterShowcase.foo(::Integer)
```
````

yielding the following docstring

```@docs
DocumenterShowcase.foo(::Integer)
```

And now, by having `DocumenterShowcase.foo(::AbstractString)` in the `@docs` block will give the other docstring

```@docs
DocumenterShowcase.foo(::AbstractString)
```

However, if you want, you can also combine multiple docstrings into a single docstring block.
The [`DocumenterShowcase.bar`](@ref) function has the same signatures as

If we just put `DocumenterShowcase.bar` in an `@docs` block, it will combine the docstrings as follows:

```@docs
DocumenterShowcase.bar
```

If you have very many docstrings, you may also want to consider using the [`@autodocs` block](@ref) which can include a whole set of docstrings automatically based on certain filtering options

### An index of docstrings

The [`@index` block](@ref) can be used to generate a list of all the docstrings on a page (or even across pages) and will look as follows

```@index
Pages = ["showcase.md"]
```

### Multiple uses of the same symbol

Sometimes a symbol has multiple docstrings, for example a type definition, inner and outer constructors. The example
below shows how to use specific ones in the documentation.

```@docs
DocumenterShowcase.Foo
DocumenterShowcase.Foo()
DocumenterShowcase.Foo{T}()
```

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
2 + 3
```
````

becomes the following code-output block pair

```@example
2 + 3
```

If the last element can be rendered as an image or `text/html` etc. (the corresponding `Base.show` method for the particular MIME type has to be defined), it will be rendered appropriately. e.g.:

```@example
using Main: DocumenterShowcase
DocumenterShowcase.SVGCircle("000", "aaa")
```

This is handy when combined with the `Markdown` standard library

```@example
using Markdown
Markdown.parse("""
`Markdown.MD` objects can be constructed dynamically on the fly and still get rendered "natively".
""")
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

### REPL-type

[`@repl` block](@ref) can be used to simulate the REPL evaluation of code blocks. For example, the following block

````markdown
```@repl
using Statistics
xs = collect(1:10)
median(xs)
sum(xs)
```
````

It gets expanded into something that looks like as if it was evaluated in the REPL, with the `julia>` prompt prepended etc.:

```@repl
using Statistics
xs = collect(1:10)
median(xs)
sum(xs)
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
julia> Documenter.Utilities.splitexpr(:(Foo.Bar.baz))
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
