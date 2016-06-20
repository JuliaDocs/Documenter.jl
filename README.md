
# Documenter

*A documentation generator for Julia.*

| **Documentation**                                                               | **PackageEvaluator**                                            | **Build Status**                                                                                |
|:-------------------------------------------------------------------------------:|:---------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-latest-img]][docs-latest-url] | [![][pkg-0.4-img]][pkg-0.4-url] [![][pkg-0.5-img]][pkg-0.5-url] | [![][travis-img]][travis-url] [![][appveyor-img]][appveyor-url] [![][codecov-img]][codecov-url] |


## Installation

The package is registered in `METADATA.jl` and so can be installed with `Pkg.add`.

```julia
julia> Pkg.add("Documenter")
```

## Documentation

- [**STABLE**][docs-stable-url] &mdash; **most recently tagged version of the documentation.**
- [**LATEST**][docs-latest-url] &mdash; *in-development version of the documentation.*

## Project Status

The package is tested against Julia `0.4` and *current* `0.5-dev` on Linux, OS X, and Windows.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. Please open an
[issue][issues-url] if you encounter any problems or would just like to ask a question.


[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://juliadocs.github.io/Documenter.jl/latest

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://juliadocs.github.io/Documenter.jl/stable

[travis-img]: https://travis-ci.org/JuliaDocs/Documenter.jl.svg?branch=master
[travis-url]: https://travis-ci.org/JuliaDocs/Documenter.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/h227adt6ovd1u3sx/branch/master?svg=true
[appveyor-url]: https://ci.appveyor.com/project/JuliaDocs/documenter-jl/branch/master

[codecov-img]: https://codecov.io/gh/JuliaDocs/Documenter.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDocs/Documenter.jl

[issues-url]: https://github.com/JuliaDocs/Documenter.jl/issues

[pkg-0.4-img]: http://pkg.julialang.org/badges/Documenter_0.4.svg
[pkg-0.4-url]: http://pkg.julialang.org/?pkg=Documenter
[pkg-0.5-img]: http://pkg.julialang.org/badges/Documenter_0.5.svg
[pkg-0.5-url]: http://pkg.julialang.org/?pkg=Documenter
