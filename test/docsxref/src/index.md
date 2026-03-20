# DocsXRefTests

On the *page* (unlike in the `g` docstring) can link directly to [`AbstractSelector`](@ref) because the `CurrentModule` is `Main`.

Implicit link to a header (single word): [API](@ref).
Explicit link to a header (single word): [header link](@ref "API").
Explicit link to a header via `@id`: [header id link](@ref api-reference).

Implicit link to a header (multiple words): [Two words](@ref).
Explicit link to a header (multiple words): [header link](@ref "Two words").

Implicit link to a non-existent header (single word): [header](@ref).
Explicit link to a non-existent header (single word): [header link](@ref "header").

Implicit link to a non-existent header (multiple words): [Multiple words](@ref).
Explicit link to a non-existent header (multiple words): [header link](@ref "Multiple words").
Explicit link to a non-existent header via `@id`: [header id link](@ref missing-header-id).
Explicit link to a non-existent dashed header via `@id`: [dashed header id link](@ref missing-header-id-with-dashes).

Implicit link to an issue: [#12345](@ref).
Explicit link to an issue: [issue link](@ref #12345).

Implicit link to a docstring: [`DocsReferencingMain.g`](@ref).
Explicit link to a docstring: [docstring link](@ref DocsReferencingMain.f).
Explicit link to a docstring with backticks: [docstring code link](@ref `DocsReferencingMain.g`).

Implicit link to a non-existent docstring: [`foobar`](@ref).
Explicit link to a non-existent docstring: [docstring link](@ref Main.foobar).
Explicit link to a non-existent docstring with backticks: [docstring code link](@ref `Main.foobar`).

Conflicting header/docstring label: [conflict link](@ref DocsReferencingMain.g).
Conflicting header/docstring label with backticks: [conflict docs link](@ref `DocsReferencingMain.g`).

## API

## [API reference](@id api-reference)

```@docs
DocsReferencingMain.f
DocsReferencingMain.g
```

```@docs
Documenter.Selectors.AbstractSelector
Documenter.hide
```

## Two words

Something

## [Header/docstring conflict](@id DocsReferencingMain.g)

Something else
