```@meta
CurrentModule = Documenter.Selectors
```

# Second page

This page is in the context of `Documenters.Selectors`. Thus, we can directly link to [`AbstractSelector`](@ref), but we cannot link to [`DocsReferencingMain.f`](@ref). But if we use the fully qualified name, it works: [`Main.DocsReferencingMain.f`](@ref).

We can also link to [`Documenter.hide`](@ref) because of the fallback to `Main`.
