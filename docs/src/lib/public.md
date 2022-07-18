# Public Documentation

Documentation for `Documenter.jl`'s public interface.

See the Internals section of the manual for internal package docs covering all submodules.

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
Documenter.except
hide
asset
deploydocs
doctest
DocMeta
DocMeta.getdocmeta
DocMeta.setdocmeta!
```

### Remotes

```@docs
Documenter.Remotes
Documenter.Remotes.GitHub
```

The following types and functions and relevant when creating custom
[`Remote`](@ref Documenter.Remotes.Remote) types:

```@docs
Documenter.Remotes.Remote
Documenter.Remotes.repourl
Documenter.Remotes.fileurl
Documenter.Remotes.issueurl
```

## DocumenterTools

```@docs
DocumenterTools.generate
DocumenterTools.genkeys
DocumenterTools.OutdatedWarning.generate
```
