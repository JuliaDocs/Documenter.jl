
# Documenter

*A documentation generator for Julia.*

| **Documentation**                                                               | **PackageEvaluator**                                                                            | **Build Status**                                                                                |
|:-------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-latest-img]][docs-latest-url] | [![][pkg-0.4-img]][pkg-0.4-url] [![][pkg-0.5-img]][pkg-0.5-url] [![][pkg-0.6-img]][pkg-0.6-url] [![][pkg-0.7-img]][pkg-0.7-url] | [![][travis-img]][travis-url] [![][appveyor-img]][appveyor-url] [![][codecov-img]][codecov-url] |


## Installation

The package is registered in `METADATA.jl` and so can be installed with `Pkg.add`.

```julia
julia> Pkg.add("Documenter")
```

## Documentation

- [**STABLE**][docs-stable-url] &mdash; **most recently tagged version of the documentation.**
- [**LATEST**][docs-latest-url] &mdash; *in-development version of the documentation.*

## Project Status

The package is tested against Julia `0.6` and *current* `0.7-dev` on Linux, OS X, and Windows.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. The [contributing][contrib-url] page details the guidelines that should be followed when opening pull requests.

Please open an [issue][issues-url] if you encounter any problems. If you have a question then feel free to ask for help in the [Gitter chat room][gitter-url].

[gitter-url]: https://gitter.im/juliadocs/users

[contrib-url]: https://juliadocs.github.io/Documenter.jl/latest/man/contributing/

[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://juliadocs.github.io/Documenter.jl/latest

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://juliadocs.github.io/Documenter.jl/stable

[travis-img]: https://travis-ci.org/JuliaDocs/Documenter.jl.svg?branch=master
[travis-url]: https://travis-ci.org/JuliaDocs/Documenter.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/xx7nimfpnl1r4gx0?svg=true
[appveyor-url]: https://ci.appveyor.com/project/JuliaDocs/documenter-jl

[codecov-img]: https://codecov.io/gh/JuliaDocs/Documenter.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDocs/Documenter.jl

[issues-url]: https://github.com/JuliaDocs/Documenter.jl/issues

[pkg-0.4-img]: http://pkg.julialang.org/badges/Documenter_0.4.svg
[pkg-0.4-url]: http://pkg.julialang.org/?pkg=Documenter&ver=0.4
[pkg-0.5-img]: http://pkg.julialang.org/badges/Documenter_0.5.svg
[pkg-0.5-url]: http://pkg.julialang.org/?pkg=Documenter&ver=0.5
[pkg-0.6-img]: http://pkg.julialang.org/badges/Documenter_0.6.svg
[pkg-0.6-url]: http://pkg.julialang.org/?pkg=Documenter&ver=0.6
[pkg-0.7-img]: http://pkg.julialang.org/badges/Documenter_0.7.svg
[pkg-0.7-url]: http://pkg.julialang.org/?pkg=Documenter&ver=0.7
