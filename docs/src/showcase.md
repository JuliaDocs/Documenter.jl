# Hidden showcase page

Currently exists just so that there would be doctests to run in manual pages of Documenter's
manual. This page does not show up in navigation.

```jldoctest
julia> 2 + 2
4
```

The following doctests needs doctestsetup:

```jldoctest; setup=:(using Documenter)
julia> Documenter.Utilities.splitexpr(:(Foo.Bar.baz))
(:(Foo.Bar), :(:baz))
```

Let's also try `@meta` blocks:

```@meta
DocTestSetup = quote
  f(x) = x^2
end
```

```jldoctest
julia> f(2)
4
```

```@meta
DocTestSetup = nothing
```
