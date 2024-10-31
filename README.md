
# Documenter

*A documentation generator for Julia.*

| **Documentation**                                                               | **Build Status**                                                                                |
|:-------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][GHA-img]][GHA-url] [![][codecov-img]][codecov-url] [![PkgEval][pkgeval-img]][pkgeval-url] |


## Installation

The package can be installed with the Julia package manager.
From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```
pkg> add Documenter
```

Or, equivalently, via the `Pkg` API:

```julia
julia> import Pkg; Pkg.add("Documenter")
```

## Documentation

- [**STABLE**][docs-stable-url] &mdash; **documentation of the most recently tagged version.**
- [**DEVEL**][docs-dev-url] &mdash; *documentation of the in-development version.*

## Project Status

The package is tested against, and being developed for, Julia `1.6` and above on Linux, macOS, and Windows.

## Questions and Contributions

Usage questions can be posted on the [Julia Discourse forum][discourse-tag-url] under the `documenter` tag, in the #documentation channel of the [Julia Slack](https://julialang.org/community/) and/or in the [JuliaDocs Gitter chat room][gitter-url].

Contributions are very welcome, as are feature requests and suggestions. Please open an [issue][issues-url] if you encounter any problems. The [contributing page][contrib-url] has a few guidelines that should be followed when opening pull requests and contributing code.

## Related packages

There are several packages that extend Documenter in different ways. The JuliaDocs organization maintains:

* [DocumenterCitations.jl](https://github.com/JuliaDocs/DocumenterCitations.jl)
* [DocumenterInterLinks.jl](https://github.com/JuliaDocs/DocumenterInterLinks.jl)
* [DocumenterMarkdown.jl](https://github.com/JuliaDocs/DocumenterMarkdown.jl)
* [DocumenterTools.jl](https://github.com/JuliaDocs/DocumenterTools.jl)
* [LiveServer.jl](https://github.com/JuliaDocs/LiveServer.jl)

Other third-party packages that can be combined with Documenter include:

* [DemoCards.jl](https://github.com/JuliaDocs/DemoCards.jl)
* [Literate.jl](https://github.com/fredrikekre/Literate.jl)
* [QuizQuestions.jl](https://github.com/jverzani/QuizQuestions.jl)
* [DocumenterMermaid.jl](https://github.com/JuliaDocs/DocumenterMermaid.jl)
* [DocumenterDiagrams.jl](https://github.com/pedromxavier/DocumenterDiagrams.jl)

Finally, there are also a few other packages in the Julia ecosystem that are similar to Documenter, but fill a slightly different niche:

* [Franklin.jl](https://github.com/tlienart/Franklin.jl)
* [Publish.jl](https://github.com/MichaelHatherly/Publish.jl)
* [Weave.jl](https://github.com/JunoLab/Weave.jl)

[contrib-url]: https://documenter.juliadocs.org/dev/contributing/
[discourse-tag-url]: https://discourse.julialang.org/tags/documenter
[gitter-url]: https://gitter.im/juliadocs/users

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://documenter.juliadocs.org/dev

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://documenter.juliadocs.org/stable

[GHA-img]: https://github.com/JuliaDocs/Documenter.jl/workflows/CI/badge.svg
[GHA-url]: https://github.com/JuliaDocs/Documenter.jl/actions?query=workflows/CI

[codecov-img]: https://codecov.io/gh/JuliaDocs/Documenter.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDocs/Documenter.jl

[issues-url]: https://github.com/JuliaDocs/Documenter.jl/issues

[pkgeval-img]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/D/Documenter.svg
[pkgeval-url]: https://juliaci.github.io/NanosoldierReports/pkgeval_badges/D/Documenter.html
