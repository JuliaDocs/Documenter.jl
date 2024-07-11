# Documenter.jl

*A documentation generator for Julia.*

A package for building documentation from docstrings and markdown files.

!!! note

    Please read through the
    [Documentation](https://docs.julialang.org/en/v1/manual/documentation/) section
    of the main Julia manual if this is your first time using Julia's documentation system.
    Once you've read through how to write documentation for your code then come back here.

## Package Features

- Write all your documentation in [Markdown](https://en.wikipedia.org/wiki/Markdown).
- Minimal configuration.
- Doctests Julia code blocks.
- Cross references for docs and section headers.
- [``\LaTeX`` syntax](@ref latex_syntax) support.
- Checks for missing docstrings and incorrect cross references.
- Generates tables of contents and docstring indexes.
- Automatically builds and deploys docs from GitHub Actions to GitHub Pages, and also supports several other CI providers.

The [Package Guide](@ref) provides a tutorial explaining how to get started using Documenter.

Some examples of packages using Documenter can be found on the [Examples](@ref) page.

See the [Index](@ref main-index) for the complete list of documented functions and types.

## Manual Outline

```@contents
Pages = [
    "man/guide.md",
    "man/examples.md",
    "man/syntax.md",
    "man/doctests.md",
    "man/hosting.md",
    "man/latex.md",
    "man/contributing.md",
]
Depth = 1
```

## Library Outline

```@contents
Pages = ["lib/public.md", "lib/internals.md"]
```

### [Index](@id main-index)

```@index
Pages = ["lib/public.md"]
```
