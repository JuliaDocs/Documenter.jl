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

---

## MkDocs and MathJax

To get MkDocs to display ``\LaTeX`` equations correctly we need to update several of this
configuration files described in the [Package Guide](@ref).

`docs/make.jl` should add the `python-markdown-math` dependency to allow for equations to
be rendered correctly.

```julia
# ...

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    # ...
)
```

This package should also be installed locally so that you can preview the generated
documentation prior to pushing new commits to a repository.

```sh
$ pip install python-markdown-math
```

The `docs/mkdocs.yml` file must add the `python-markdown-math` extension, called `mdx_math`,
as well as two MathJax JavaScript files:

```yaml
# ...
markdown_extensions:
  - mdx_math
  # ...

extra_javascript:
  - https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS_HTML
  - assets/mathjaxhelper.js
# ...
```

**Final Remarks**

Following this guide and adding the necessary changes to the configuration files should
enable properly rendered mathematical equations within your documentation both locally and
when built and deployed using the Travis built service.
