
```@docs
missing_doc
```

```@docs
parse error
```

```@meta
CurrentModule = NonExistantModule
```

```@autodocs
Modules = [NonExistantModule]
```

```@eval
NonExistantModule
```

```@docs
# comment in a @docs block
```

[`foo(x::Foo)`](@ref) creates an [`UndefVarError`](@ref) when `eval`d
for the type signature, since `Foo` is not defined.

Numeric literals don't have bindings: [`1`](@ref). Nor [`"strings"`](@ref).
[`:symbols`] do, however.

Some syntax errors in references will fail with an `ParseError`: [`foo+*bar`](@ref).
Others, like [`foo(x`](@ref) will give an `:incomplete` expression.

This is the footnote [^1]. And [^another] [^another].

[^1]: one

    [^nested]: a nested footnote

[^another_one]:

    Things! [^1]. [^2].

[^nested]

[^nested]:

    Duplicate [^1] nested footnote.

```@docs
ErrorsModule.func
```

```jldoctest
julia> b = 1
2

julia> x

julia> x
ERROR: UndefVarError: x not defined

julia> x
```

```jldoctest; setup
julia> 1+1
2
```
```jldoctest invalidkwarg1; setup
julia> 1+1
2
```
```jldoctest; setup == 1
julia> 1+1
2
```
```jldoctest invalidkwarg2; setup == 1
julia> 1+1
2
```
