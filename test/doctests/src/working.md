This source file contains a working doctest:

```jldoctest
julia> 2 + 2
4
```

Test comments or comment-like lines:

```jldoctest
julia> f(x) = println("# output from f\n$x");

julia> f(42)
# output from f
42

julia> f(42)
       # comment line
# output from f
42
```
