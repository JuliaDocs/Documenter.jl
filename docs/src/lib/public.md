# Public Documentation

Documentation for `Documenter.jl`'s public interface.

See [Internal Documentation](@ref) for internal package docs covering all submodules.

## Contents

```@contents
Pages = ["public.md"]
```

## Index

```@index
Pages = ["public.md"]
```

## Public Interface

```@docs
Documenter
makedocs
hide
deploydocs
Deps
Deps.pip
doctest
DocMeta
DocMeta.getdocmeta
DocMeta.setdocmeta!
```

### CI platforms supported by `deploydocs`

```@docs
Documenter.CI_SYSTEM
TRAVIS
GITLAB_CI
CIRRUS_CI
DRONE
APPVEYOR
```

## DocumenterTools

```@docs
DocumenterTools.generate
DocumenterTools.Travis.genkeys
DocumenterTools.Travis
```
