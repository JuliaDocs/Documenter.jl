# Public Documentation

Documentation for `Documenter.jl`'s public interface.

See the Internals section of the manual for internal package docs covering all submodules.

## Contents

```@contents
Pages = ["public.md"]
Depth = 2:2
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
Documenter.MissingRemoteError
asset
Documenter.RawHTMLHeadContent
deploydocs
doctest
DocMeta
DocMeta.getdocmeta
DocMeta.setdocmeta!
```

## DocumenterTools

```@docs
DocumenterTools.generate
DocumenterTools.genkeys
DocumenterTools.OutdatedWarning.generate
```

## Extensions

These APIs are intended for extension and plugin authors to use.
They would normally not be relevant for usual end-users.

```@docs
Documenter.writer_supports_ansicolor
```
