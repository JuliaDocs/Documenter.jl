# No `@meta` block

This page deliberately has no `@meta` block, so `CurrentModule` and `CollapsedDocStrings` can only reach it through the `meta` keyword of `makedocs`. The `@ref` below resolves only if `CurrentModule` survives into the cross-reference stage, and the docstring below is marked as collapsed only if `CollapsedDocStrings` survives into the HTML writer.

See [`unexported_function`](@ref).

```@docs
unexported_function
```
