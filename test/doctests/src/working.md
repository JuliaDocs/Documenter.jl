This source file contains a working doctest:

```jldoctest
julia> 2 + 2
4
```

Testing catching errors:

```jldoctest
julia> error("0123456789")
ERROR: 0123456789
Stacktrace:
[...]
```

```jldoctest; filter = r"\b[0-9]+\b"
julia> error("0123456789")
ERROR: 9876543210
Stacktrace:
[...]
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

```@meta
DocTestSetup = quote
    methods(args...) = Text("""
    # 1 method for generic function "f":
    [1] f() in Main at none:1
    """)
end
```
```jldoctest
julia> f()=0
f (generic function with 1 method)

julia> methods(f)
# 1 method for generic function "f":
[1] f() in Main at none:1
```
```@meta
DocTestSetup = nothing
```

Comments at the start:

```jldoctest
# Initial comments before the first julia> prompt..
# .. should be ignored.
julia> 2 + 2
4
```

Empty output:

```jldoctest
nothing
# output
```

Filtering with regex substitutions:

```jldoctest; filter = r"([0-9]+\.[0-9]{8})[0-9]+" => s"\1***"
julia> sqrt(2)
1.41421356000
```
