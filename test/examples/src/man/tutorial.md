# Tutorial

[Documentation](@ref)

[Index](@ref)

[Functions](@ref)

[`Main.Mod.func(x)`](@ref)

[`Main.Mod.T`](@ref)

```jldoctest
julia> using Base.Meta # `nothing` shouldn't be displayed.

julia> Meta
Base.Meta

julia> a = 1
1

julia> b = 2;

julia> a + b
3
```

```jldoctest
a = 1
b = 2
a + b

# output

3
```

```@meta
DocTestSetup =
    quote
        srand(1)
    end
```

```jldoctest
a = 1
b = 2
a / b

# output

0.5
```

```jldoctest
julia> a = 1;

julia> b = 2
2

julia> a / b
0.5
```

```@eval
code = string(sprint(Base.banner), "julia>")
Markdown.Code(code)
```

```jldoctest
julia> # First definition.
       function f(x, y)
           x + y
       end
       #
       # Second definition.
       #
       type T
           x
       end

julia> isdefined(:f), isdefined(:T) # Check for both definitions.
(true,true)

julia> import Base

julia> using Base.Meta

julia> r = isexpr(:(using Base.Meta), :using); # Discarded result.

julia> !r
false
```

```jldoctest
julia> for i = 1:5
           println(i)
       end
1
2
3
4
5

julia> println("Printing with semi-comma ending.");
Printing with semi-comma ending.

julia> warn("...");
WARNING: ...

julia> div(1, 0)
ERROR: DivideError: integer division error
[...]

julia> info("...")   # ...
       println("a"); # Semi-colons *not* on the last expression shouldn't suppress output.
       println(1)    # ...
       2             # ...
INFO: ...
a
1
2

julia> info("...")   # ...
       println("a"); # Semi-colons *not* on the last expression shouldn't suppress output.
       println(1)    # ...
       2;            # Only those in the last expression.
INFO: ...
a
1

```

```jldoctest
a = 1
b = 2; # Semi-colons don't affect script doctests.

# output

2
```

```@repl 1
f(x) = (sleep(x); x)
@time f(0.1);
```

```@repl 1
f(0.01)
div(1, 0)
```

Make sure that STDOUT is in the right place (#484):

```@repl 1
println("---") === nothing
versioninfo()
```

```@eval
1 + 2
nothing
```
