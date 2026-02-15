# Syntax Versioning Tests

This page tests the `syntax=` attribute for doctests.

## Per-block syntax version

This doctest uses the `syntax=` attribute to specify Julia 1.14 syntax:

```jldoctest; syntax = v"1.14"
julia> result = @label myblock begin
           for i in 1:5
               if i > 3
                   break myblock i * 10
               end
           end
           0
       end
40
```

## Verifying syntax version with @VERSION

```jldoctest; syntax = v"1.14"
julia> (Base.Experimental.@VERSION).syntax == v"1.14"
true
```

## Negative test: syntax version 1.13

This verifies that setting `syntax = v"1.13"` actually uses the 1.13 parser,
not the default one.

```jldoctest; syntax = v"1.13"
julia> (Base.Experimental.@VERSION).syntax == v"1.13"
true
```
