# [``\LaTeX`` syntax](@id latex_syntax)

The following section describes how to add equations written using ``\LaTeX`` to your
documentation.

## Escaping characters in docstrings

Since some characters used in ``\LaTeX`` syntax are treated differently in docstrings they
need to be escaped using a `\` character as in the following example:

```julia
"""
Here's some inline maths: \$\\sqrt[n]{1 + x + x^2 + \\ldots}\$.

Here's an equation:

\$\\frac{n!}{k!(n - k)!} = \\binom{n}{k}\$

This is the binomial coefficient.
"""
func(x) = # ...
```

To avoid needing to escape the special characters the `doc""` string macro can be used:

```julia
doc"""
Here's some inline maths: $\sqrt[n]{1 + x + x^2 + \ldots}$.

Here's an equation:

$\frac{n!}{k!(n - k)!} = \binom{n}{k}$

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

## Inline equations

```markdown
Here's some inline maths: ``\sqrt[n]{1 + x + x^2 + \ldots}``.
```

which will be displayed as

---

Here's some inline maths: ``\sqrt[n]{1 + x + x^2 + \ldots}``.

---

## Display equations

````markdown
Here's an equation:

```math
\frac{n!}{k!(n - k)!} = \binom{n}{k}
```

This is the binomial coefficient.
````

which will be displayed as

---

Here's an equation:

```math
\frac{n!}{k!(n - k)!} = \binom{n}{k}
```

This is the binomial coefficient.
