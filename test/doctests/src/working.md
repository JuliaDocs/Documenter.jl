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

```jldoctest
julia> let x = 1
           println("$x")
           # comment
           println("$x")
       end
1
1

julia> println("xyz")
       # comment
xyz
```

Original issue:

```jldoctest
julia> f()=0
f (generic function with 1 method)

julia> methods(f)
# 1 method for generic function "f":
[1] f() in Main at none:1
```

Comments at the start:

```jldoctest
# Initial comments before the first julia> prompt..
# .. should be ignored.
julia> 2 + 2
4
```