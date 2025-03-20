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

## Code blocks

Code blocks are rendered as follows:

```
This is an non-highlighted code block.
... Rendered in monospace.
```

When the language is specified for the block, e.g. by starting the block with ````` ```julia`````, the content gets highlighted appropriately (for the languages that are supported by the highlighter).

```julia
function foo(x::Integer)
    @show x + 1
end
```

## Mathematics

For mathematics, both inline and display equations are supported.
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

![Enter a descriptive caption for the image](assets/logo.png)

The path should be relative to the directory of the current file. Alternatively,
use `./` to begin a path relative to the `src` of the documents, e.g.,
`./assets/logo.png`.

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

    Note that admonitions themselves can contain other block-level elements,
    such as code blocks, e.g.

    ```julia
    f(x) = x^2
    ```

    and headings, e.g.

    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

    However, you **can not** have at-blocks, docstrings, doctests, etc. in an admonition.

    An admonition is closed when the indentation stops,
    so blank lines may be used within or before the content to improve raw text readability.

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

###### TODO admonition
!!! todo "'todo' admonition"
    This is a `!!! todo`-type admonition.

###### Details admonition
Admonitions with type `details` is rendered as a collapsed `<details>` block in
the HTML output, with the admonition title as the `<summary>`.

!!! details "'details' admonition"
    This is a `!!! details`-type admonition.

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

| object | implemented | value      |
| ------ | ----------- | ---------- |
| `A`    | ✓           | 10.00      |
| `BB`   | ✓           | 1000000.00 |

With explicit alignment.

| object | implemented |      value |
| :----- | :---------: | ---------: |
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |

Tables that are too wide should become scrollable.

| object                 |                 implemented                  |                                                      value |
| :--------------------- | :------------------------------------------: | ---------------------------------------------------------: |
| `A`                    |                      ✓                       |                                                      10.00 |
| `BBBBBBBBBBBBBBBBBBBB` | ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓ | 1000000000000000000000000000000000000000000000000000000.00 |


## Footnotes

Footnote references can be added with the `[^label]` syntax.[^1] The footnote definitions get collected at the bottom of the page.

The footnote label can be an arbitrary string and even consist of block-level elements.[^Clarke61]

[^1]: A footnote definition uses the `[^label]: ...` syntax in a block scope.

[^Clarke61]:
    > Any sufficiently advanced technology is indistinguishable from magic.
    Arthur C. Clarke, _Profiles of the Future_ (1961): Clarke's Third Law.

## Headings

Finally, headings render as follows

### Heading level 3
#### Heading level 4
##### Heading level 5
###### Heading level 6

To see an example of a level 1 heading see the page title and for level 2 heading, see the one just under this paragraph.

!!! note "Headings in sidebars"
    Level 1 and 2 heading show up in the sidebar, for the current page.

Note that in docstrings, the headings get rewritten as just bold text right now:

```@docs
DocumenterShowcase.baz
```

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

This will include a single docstring and it will look like this:

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

However, if you want, you can also combine multiple docstrings into a single docstring
block. To illustrate this, the [`DocumenterShowcase.bar`](@ref) function has the same
signatures as [`DocumenterShowcase.foo`](@ref).
If we just put `DocumenterShowcase.bar` in an `@docs` block, it will combine the docstrings as follows:

```@docs
DocumenterShowcase.bar
```

If you have very many docstrings, you may also want to consider using the [`@autodocs` block](@ref) which can include a whole set of docstrings automatically based on certain filtering options.

Both `@docs` and `@autodocs` support the [`canonical=false` keyword argument](@ref noncanonical-block). This can be used to include a docstring more than once.
For example, if we do this ...

````markdown
```@docs; canonical=false
DocumenterShowcase.bar
```
````

... we then see the same docstring as above:

```@docs; canonical=false
DocumenterShowcase.bar
```

### An index of docstrings

The [`@index` block](@ref) can be used to generate a list of all the docstrings on a page (or even across pages) and will look as follows:

```@index
Pages = ["showcase.md"]
```

### Multiple uses of the same symbol

Sometimes a symbol has multiple docstrings, for example a type definition, inner and outer constructors. The example
below shows how to use specific ones in the documentation.
````markdown
```@docs
DocumenterShowcase.Foo
DocumenterShowcase.Foo()
DocumenterShowcase.Foo{T}()
```
````

This is then rendered to this:

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

### Setup code

You can have setup code for doctests that gets executed before the actual doctest.
For example, the following doctest needs to have the `Documenter` module to be present.

```jldoctest; setup=:(using Documenter)
julia> Documenter.splitexpr(:(Foo.Bar.baz))
(:(Foo.Bar), :(:baz))
```

This is achieved by the `setup` keyword to `jldoctest`.

````
```jldoctest; setup=:(using Documenter)
````

The alternative approach is to use the `DocTestSetup` keys in `@meta`-blocks, which will apply across multiple doctests.

````markdown
```@meta
DocTestSetup = quote
  f(x) = x^2
end
```
````
```@meta
DocTestSetup = quote
  f(x) = x^2
end
```

```jldoctest
julia> f(2)
4
```

The doctests and `@meta` blocks are evaluated sequentially on each page, so you can always unset the test code by setting it back to `nothing`.

````markdown
```@meta
DocTestSetup = nothing
```
````
```@meta
DocTestSetup = nothing
```

### Teardown code

Dually to setup code described in the preceding section it can be useful to have code that
gets executed *after* the actual doctest, perhaps to restore a setting or release
a resource acquired during setup.
For example, the following doctest expects that `setprecision` was used to
change the default precision for `BigFloat`. After the test completes, this should
be restored to the previous setting.

!!! note
    In real code it is usually better to use `setprecision` with a `do`-block
    to temporarily change the precision. But for the sake of this example it
    is useful to demonstrate the effect of changing and restoring a global setting.

```jldoctest; setup=:(oldprec=precision(BigFloat);setprecision(BigFloat,20)), teardown=:(setprecision(BigFloat,oldprec))
julia> sqrt(big(2.0))
1.4142132
```

This is achieved by the `teardown` keyword to `jldoctest` in addition to `setup`.

````
```jldoctest; setup=:(oldprec=precision(BigFloat);setprecision(BigFloat,20)), teardown=:(setprecision(BigFloat,oldprec))
````

Note that if we now run the same doctest content again but without `setup` and `teardown`
it will produce output with a different (higher) precision. If we had used `setup` without
`teardown` then this doctest would still use the smaller precision, i.e., it would be
affected by the preceding doctest, which is not what we want.
```jldoctest
julia> sqrt(big(2.0))
1.414213562373095048801688724209698078569671875376948073176679737990732478462102
```

The alternative approach is to use the `DocTestSetup` and `DocTestTeardown` keys in `@meta`-blocks, which will apply across multiple doctests.

````markdown
```@meta
DocTestSetup = quote
  oldprec = precision(BigFloat)
  setprecision(BigFloat, 20)
end
DocTestTeardown = quote
  setprecision(BigFloat, oldprec)
end
```
````
```@meta
DocTestSetup = quote
  oldprec = precision(BigFloat)
  setprecision(BigFloat, 20)
end
DocTestTeardown = quote
  setprecision(BigFloat, oldprec)
end
```

```jldoctest
julia> sqrt(big(2.0))
1.4142132
```

The doctests and `@meta` blocks are evaluated sequentially on each page, so you can always unset the test code by setting it back to `nothing`.

````markdown
```@meta
DocTestSetup = nothing
DocTestTeardown = nothing
```
````
```@meta
DocTestSetup = nothing
DocTestTeardown = nothing
```


## Running interactive code

[`@example` block](@ref reference-at-example) run a code snippet and insert the output into the document.
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

If the last element can be rendered as an image or `text/html` etc. (the corresponding `Base.show` method for the particular MIME type has to be defined), it will be rendered appropriately. E.g.:

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

### Color output

Output from [`@repl` block](@ref)s and [`@example` block](@ref reference-at-example)s support colored output,
transforming ANSI color codes to HTML.

!!! compat "Julia 1.6"
    Color output requires Julia 1.6 or higher.
    To enable color output pass `ansicolor=true` to [`Documenter.HTML`](@ref).

#### Colored `@example` block output

**Input:**
````markdown
```@example
code_typed(sqrt, (Float64,))
```
````

**Output:**
```@example
code_typed(sqrt, (Float64,))
```

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

### Named blocks

Generally, each blocks gets evaluated in a separate, clean context (i.e. no variables from previous blocks will be polluting the namespace etc).
However, you can also re-use a namespace by giving the blocks a name.

````markdown
```@example block-name
x = 40
```
will show up like this:
````
```@example block-name
x = 40
```

````markdown
```@example block-name
x + 1
```
will show up like this:
````
```@example block-name
x + 1
```

When you need setup code that you do not wish to show in the generated documentation, you can use [an `@setup` block](@ref reference-at-setup):

````markdown
```@setup block-name
x = 42
```
````
```@setup block-name
x = 42
```

The [`@setup` block](@ref reference-at-setup) essentially acts as a hidden [`@example` block](@ref reference-at-example).
Any state it sets up, you can access in subsequent blocks with the same name.
For example, the following `@example` block

````markdown
```@example block-name
x
```
````

will show up like this:

```@example block-name
x
```

You also have continued blocks which do not evaluate immediately.

````markdown
```@example block-name; continued = true
y = 99
```
````
```@example block-name; continued = true
y = 99
```

The continued evaluation only applies to [`@example` blocks](@ref reference-at-example) and so if you put, for example, a `@repl` block in between, it will lead to an error, because the `y = 99` line of code has not run yet.

````markdown
```@repl block-name
x
y
```
````

```@repl block-name
x
y
```

Another [`@example` block](@ref reference-at-example) with the same name will, however, finish evaluating it.
So a block like

````markdown
```@example block-name
(x, y)
```
````

will lead to

```@example block-name
(x, y)
```
