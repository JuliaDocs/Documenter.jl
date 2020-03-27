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
