# Testing

We test the `meta` keyword to `makedocs` by using it to set `DocTestSetup` to
code which initializes `x`. If and only if that setup block is run, the
following doctest passes.

```jldoctest
julia> x
42
```
