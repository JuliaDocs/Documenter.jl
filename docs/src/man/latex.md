# [``\LaTeX`` Syntax](@id latex_syntax)

The following section describes how to add equations written using ``\LaTeX`` to your
documentation.

## Escaping Characters in Docstrings

Since some characters used in ``\LaTeX`` syntax, such as `$` and `\`, are treated differently in docstrings. They
need to be escaped using a `\` character as in the following example:

```julia
"""
Here's some inline maths: ``\\sqrt[n]{1 + x + x^2 + \\ldots}``.

Here's an equation:

``\\frac{n!}{k!(n - k)!} = \\binom{n}{k}``

This is the binomial coefficient.
"""
func(x) = # ...
```

Note that for equations on the manual pages (in `.md` files) the escaping is not necessary. So, when moving equations
between the manual and docstrings, the escaping `\` characters have to the appropriately added or removed.

To avoid needing to escape the special characters in docstrings the `raw""` string macro can be used, combined with `@doc`:

```julia
@doc raw"""
Here's some inline maths: ``\sqrt[n]{1 + x + x^2 + \ldots}``.

Here's an equation:

``\frac{n!}{k!(n - k)!} = \binom{n}{k}``

This is the binomial coefficient.
"""
func(x) = # ...
```

A related issue is how to add dollar signs to a docstring. They need to be
double-escaped as follows:
```julia
"""
The cost was \\\$1.
"""
```

## Inline Equations

```markdown
Here's some inline maths: ``\sqrt[n]{1 + x + x^2 + \ldots}``.
```

which will be displayed as

---

Here's some inline maths: ``\sqrt[n]{1 + x + x^2 + \ldots}``.

---

!!! warning
    Similar to LaTeX, using `$` and `$$` to escape inline and display equations
    also works. However, doing so is deprecated and this functionality may be
    removed in a future release.

## Display Equations

````markdown
Here's an equation:

```math
\frac{n!}{k!(n - k)!} = \binom{n}{k}
```

This is the binomial coefficient.

---

To write a system of equations, use the `aligned` environment:

```math
\begin{aligned}
\nabla\cdot\mathbf{E}  &= 4 \pi \rho \\
\nabla\cdot\mathbf{B}  &= 0 \\
\nabla\times\mathbf{E} &= - \frac{1}{c} \frac{\partial\mathbf{B}}{\partial t} \\
\nabla\times\mathbf{B} &= - \frac{1}{c} \left(4 \pi \mathbf{J} + \frac{\partial\mathbf{E}}{\partial t} \right)
\end{aligned}
```

These are Maxwell's equations.

````

which will be displayed as

---

Here's an equation:

```math
\frac{n!}{k!(n - k)!} = \binom{n}{k}
```

This is the binomial coefficient.

---

To write a system of equations, use the `aligned` environment:

```math
\begin{aligned}
\nabla\cdot\mathbf{E}  &= 4 \pi \rho \\
\nabla\cdot\mathbf{B}  &= 0 \\
\nabla\times\mathbf{E} &= - \frac{1}{c} \frac{\partial\mathbf{B}}{\partial t} \\
\nabla\times\mathbf{B} &= - \frac{1}{c} \left(4 \pi \mathbf{J} + \frac{\partial\mathbf{E}}{\partial t} \right)
\end{aligned}
```

These are Maxwell's equations.

## Printing LaTeX from Julia

To pretty-print LaTeX from Julia, overload `Base.show` for the
`MIME"text/latex"` type. For example:
```@example
struct LaTeXEquation
    content::String
end

function Base.show(io::IO, ::MIME"text/latex", x::LaTeXEquation)
    # Wrap in $$ for display math printing
    return print(io, "\$\$ " * x.content * " \$\$")
end

LaTeXEquation(raw"""
    \left[\begin{array}{c}
        x \\
        y
    \end{array}\right]
""")
```

## Set math engine and define macros for LaTeX

The `mathengine` argument to [`Documenter.HTMLWriter.HTML`](@ref) allows the math rendering engine to be specified, supporting both MathJax and KaTeX (with the latter being the default).

Furthermore, you can also pass custom configuration to the rendering engine. E.g. to add global LaTeX command definitions, you can set `mathengine` to:
```julia
mathengine = Documenter.MathJax(Dict(:TeX => Dict(
    :equationNumbers => Dict(:autoNumber => "AMS"),
    :Macros => Dict(
        :ket => ["|#1\\rangle", 1],
        :bra => ["\\langle#1|", 1],
    ),
)))
```
Or with MathJax v3, the [physics package](http://mirrors.ibiblio.org/CTAN/macros/latex/contrib/physics/physics.pdf) can be loaded:

```julia
mathengine = MathJax3(Dict(
    :loader => Dict("load" => ["[tex]/physics"]),
    :tex => Dict(
        "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
        "tags" => "ams",
        "packages" => ["base", "ams", "autoload", "physics"],
    ),
))
```

The syntax is slightly different if using KaTeX, the following example is what you might include in your `makedocs` function:

```julia
makedocs(
    format = Documenter.HTML(; mathengine=
        Documenter.KaTeX(
            Dict(:delimiters => [
                Dict(:left => raw"$",   :right => raw"$",   display => false),
                Dict(:left => raw"$$",  :right => raw"$$",  display => true),
                Dict(:left => raw"\[",  :right => raw"\]",  display => true),
                ],
                :macros => Dict("\\RR" => "\\mathbb{R}",
                    raw"\Xi" => raw"X_{i}",
                    raw"\Ru" => raw"R_{\mathrm{univ.}}",
                    raw"\Pstd" => raw"P_{\mathrm{std}}",
                    raw"\Tstd" => raw"T_{\mathrm{std}}",
                ),
            )
        )
    )
)
```

[`MathJax2`](@ref), [`MathJax3`](@ref) and [`KaTeX`](@ref) are available types for `mathengine`.
