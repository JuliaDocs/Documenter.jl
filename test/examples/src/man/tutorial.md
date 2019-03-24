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
        using Random
        Random.seed!(1)
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
import Markdown
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

julia> @isdefined(f), @isdefined(T) # Check for both definitions.
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

If `show(io, ::MIME, x)` is overloaded for a particular type then `@example` blocks can show the SVG, HTML/JS/CSS, PNG, JPEG, GIF or WebP image as appropriate in the output.

Assuming the following type and method live in the `InlineSVG` module

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

We can also show SVG images with interactivity via the `text/html` MIME to display output that combines HTML, JS and CSS. Assume the following type and method live in the `InlineHTML` modeul

```julia
struct HTML
    code::String
end
Base.show(io, ::MIME"text/html", html::HTML) = write(io, read(html.code))
```

.. then we can invoke and show them with an `@example` block (try mousing over the circles to see the applied style):

```@setup inlinehtml
module InlineHTML
mutable struct HTML
    code::String
end
Base.show(io, ::MIME"text/html", html::HTML) = write(io, html.code)
end # module
```

```@example inlinehtml
using .InlineHTML
InlineHTML.HTML("""
<script>
  function showStyle(e) {
    document.querySelector("#inline-html-style").innerHTML = e.getAttribute('style');
  }
</script>
<svg width="100%" height="76">
  <g style="stroke-width: 3">
    <circle cx="20" cy="56" r="16" style="stroke: #cb3c33; fill: #d5635c" onmouseover="showStyle(this)"/>
    <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" onmouseover="showStyle(this)"/>
    <circle cx="62" cy="56" r="16" style="stroke: #9558b2; fill: #aa79c1" onmouseover="showStyle(this)"/>
    <text id="inline-html-style" x="90", y="20"></text>
  </g>
</svg>
""")
```

The same mechanism also works for PNG files. Assuming again the following
type and method live in the `InlinePNG` module

```julia
struct PNG
    filename::String
end
Base.show(io, ::MIME"image/png", png::PNG) = write(io, read(png.filename))
```

.. then we can invoke and show them with an `@example` block:

```@setup inlinepng
module InlinePNG
export PNG
mutable struct PNG
    filename::String
end
Base.show(io, ::MIME"image/png", png::PNG) = write(io, read(png.filename))
end # module
```

```@example inlinepng
using Documenter
using .InlinePNG
PNG(joinpath(dirname(pathof(Documenter)), "..", "test", "examples", "images", "logo.png"))
```


.. and JPEG, GIF and WebP files:

```@setup inlinewebpgifjpeg
module InlineWEBPGIFJPEG
export WEBP, GIF, JPEG
mutable struct WEBP
    filename :: String
end
Base.show(io, ::MIME"image/webp", image::WEBP) = write(io, read(image.filename))
mutable struct GIF
    filename :: String
end
Base.show(io, ::MIME"image/gif", image::GIF) = write(io, read(image.filename))
mutable struct JPEG
    filename :: String
end
Base.show(io, ::MIME"image/jpeg", image::JPEG) = write(io, read(image.filename))
end # module
```

```@example inlinewebpgifjpeg
using Documenter
using .InlineWEBPGIFJPEG
WEBP(joinpath(dirname(pathof(Documenter)), "..", "test", "examples", "images", "logo.webp"))
```

```@example inlinewebpgifjpeg
GIF(joinpath(dirname(pathof(Documenter)), "..", "test", "examples", "images", "logo.gif"))
```

```@example inlinewebpgifjpeg
JPEG(joinpath(dirname(pathof(Documenter)), "..", "test", "examples", "images", "logo.jpg"))
```

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

## Tables

| object | implemented |      value |
|--------|-------------|------------|
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |

With explicit alignment.

| object | implemented |      value |
| :---   |    :---:    |       ---: |
| `A`    |      ✓      |      10.00 |
| `BB`   |      ✓      | 1000000.00 |
