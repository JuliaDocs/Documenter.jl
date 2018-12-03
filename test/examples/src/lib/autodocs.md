# `@autodocs` tests

```@meta
CurrentModule = Main
```

## Public

Should include docs for

  * [`AutoDocs.Pages.E.f_1`](@ref)
  * [`AutoDocs.Pages.E.f_2`](@ref)
  * [`AutoDocs.Pages.E.f_3`](@ref)

in that order.

```@autodocs
Modules = [AutoDocs.Pages.E]
Private = false
Order = [:function]
```

## Private

Should include docs for

  * [`AutoDocs.Pages.E.g_1`](@ref)
  * [`AutoDocs.Pages.E.g_2`](@ref)
  * [`AutoDocs.Pages.E.g_3`](@ref)

in that order.

```@autodocs
Modules = [AutoDocs.Pages.E]
Public = false
Order = [:function]
```

## Ordering of Public and Private

Should include docs for

  * [`AutoDocs.Pages.E.T_1`](@ref)
  * [`AutoDocs.Pages.E.T_2`](@ref)

in that order.

```@autodocs
Modules = [AutoDocs.Pages.E]
Order = [:type]
```

## Filtering

Should include docs for

  * [`AutoDocs.Filter.Major`](@ref)
  * [`AutoDocs.Filter.Minor1`](@ref)
  * [`AutoDocs.Filter.Minor2`](@ref)

in that order.

```@autodocs
Modules = [AutoDocs.Filter]
Order = [:type]
Filter =  t -> t <: AutoDocs.Filter.Major
```
