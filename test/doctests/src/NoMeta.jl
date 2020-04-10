module NoMeta

"""
This docstring contains a doctest that needs a DocTestSetup

```jldoctest
julia> baz(20)
40
```
"""
function foo end

"""
This docstring contains a doctest that needs a DocTestSetup, but it's provided:

```@meta
DocTestSetup = quote
    qux(x) = 3x
end
```

```jldoctest
julia> qux(10)
30
```

```@meta
DocTestSetup = nothing
```
"""
function bar end

end
