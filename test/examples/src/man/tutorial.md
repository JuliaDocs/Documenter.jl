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
        using Documenter
        using Compat.Random
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
import Compat.Markdown
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
       struct T
           x
       end

julia> isdefined(:f), isdefined(:T) # Check for both definitions.
(true, true)

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

julia> div(1, 0)
ERROR: DivideError: integer division error
[...]

julia> println("a"); # Semi-colons *not* on the last expression shouldn't suppress output.
       println(1)    # ...
       2             # ...
a
1
2

julia> println("a"); # Semi-colons *not* on the last expression shouldn't suppress output.
       println(1)    # ...
       2;            # Only those in the last expression.
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

Make sure that stdout is in the right place (#484):

```@repl 1
println("---") === nothing
versioninfo()
```

```@eval
1 + 2
nothing
```

## Including images with `MIME`

If `show(io, ::MIME"image/svg+xml", x)` is overloaded for a particular type
then `@example` blocks will show the SVG image in the output. Assuming the following type
and method live in the `InlineSVG` module

```julia
struct SVG
    code :: String
end
Base.show(io, ::MIME"image/svg+xml", svg::SVG) = write(io, svg.code)
```

.. then we we can invoke and show them with an `@example` block:

```@setup inlinesvg
module InlineSVG
export SVG
mutable struct SVG
    code :: String
end
Base.show(io, ::MIME"image/svg+xml", svg::SVG) = write(io, svg.code)
end # module
```

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width="82" height="76">
  <g style="stroke-width: 3">
    <circle cx="20" cy="56" r="16" style="stroke: #cb3c33; fill: #d5635c" />
    <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" />
    <circle cx="62" cy="56" r="16" style="stroke: #9558b2; fill: #aa79c1" />
  </g>
</svg>
""")
```

_Note: we can't define the `show` method in the `@example` block due to the world age
counter in Julia 0.6 (Documenter's `makedocs` is not aware of any of the new method
definitions happening in `eval`s)._


## Interacting with external files

You can also write output files and then refer to them in the document:

```@example
open("julia.svg", "w") do io
    write(io, """
    <svg width="82" height="76" xmlns="http://www.w3.org/2000/svg">
      <g style="stroke-width: 3">
        <circle cx="20" cy="56" r="16" style="stroke: #cb3c33; fill: #d5635c" />
        <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" />
        <circle cx="62" cy="56" r="16" style="stroke: #9558b2; fill: #aa79c1" />
      </g>
    </svg>
    """)
end
```

![Julia circles](julia.svg)

Dowload [`data.csv`](data.csv).


## [Links](../index.md) in headers

... are dropped in the navigation links.


## Embedding raw HTML

Below is a nicely rendered version of `^D`:

```@raw html
<kbd>Ctrl</kbd> + <kbd>D</kbd>
```
