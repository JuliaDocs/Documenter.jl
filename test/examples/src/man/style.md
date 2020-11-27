# Style demos

## Styling of lists

* Lorem ipsum dolor sit amet, consectetur adipiscing elit.
* Nulla quis venenatis justo.
* In non _sodales_ eros.

In an admonition it looks like this:

!!! note "Bulleted lists in admonitions"

    * Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    * Nulla quis venenatis justo.
    * In non _sodales_ eros.

    Second list

    * Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    * Nulla quis venenatis justo.
    * In non _sodales_ eros.

Also, custom admonition classes can be used:

!!! myadmonition "My Admonition Class"

    In the HTML output, this admonition has `is-category-myadmonition` applied to it.
    Its style can be changed by adding styles to `.admonition-header` and `.admonition-body`
    in a custom css file and adding it to the build with, for example:

    ```julia
    makedocs(
        # ...
        format=Documenter.HTML(;
            #...
            assets=["assets/custom.css"]
        )
    )
    ```

    See [`test/examples/src/assets/custom.css`](https://github.com/JuliaDocs/Documenter.jl/blob/master/test/examples/src/assets/custom.css)
    for an example of a custom CSS file.

But otherwise

* Lorem ipsum dolor sit amet, consectetur adipiscing elit.
* Nulla quis venenatis justo.
* In non _sodales_ eros.

In block quotes

> * Lorem ipsum dolor sit amet, consectetur adipiscing elit.
> * Nulla quis venenatis justo.
> * In non _sodales_ eros.
>
> Second list
>
> * Lorem ipsum dolor sit amet, consectetur adipiscing elit.
> * Nulla quis venenatis justo.
> * In non _sodales_ eros.

!!! note
    1. asd
    2. asdf

## Links and code spans

Lorem [ipsum](#) dolor sit [`amet`](#), consectetur adipiscing `elit`.

## Code blocks

```julia
foo = "Example of string $(interpolation)."
```

## Footnote rendering

This sentence has a footnote.[^5]

[^5]: An example of how you can benchmark a log density with gradient `∇P`, obtained as described below:
    ```julia
    using BenchmarkTools, LogDensityProblems
    x = randn(LogDensityProblems.dimension(∇P))
    @benchmark LogDensityProblems.logdensity_and_gradient($∇P, $x)
    ```

## Math

Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

Display equation:

```math
\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
```

!!! note "Long equations in admonitions"

    Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

    Display equation:

    ```math
    \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
    ```

Long equations in footnotes.[^longeq]

[^longeq]:

    Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

    Display equation:

    ```math
    \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
    ```

```@docs
Mod.long_equations_in_docstrings
```
