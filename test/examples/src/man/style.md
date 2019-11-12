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
