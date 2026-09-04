# Test warnings for misspelled code block languages

A misspelled doctest language must warn, not abort the build (issue #2997).
```jldoctests
julia> 1 + 1
2
```

The same for at-blocks.
```@examples
1 + 1
```

A deliberate custom language starting with a known one warns as well.
```jldoctest_special
julia> 2 + 2
4
```

An unrelated language stays silent.
```julia
1 + 1
```
