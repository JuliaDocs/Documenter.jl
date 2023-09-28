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
Markdown.MD([Markdown.Code(code)])
```

```@eval
rand(20, 20)
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

Without xmlns tag:

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

With xmlns tag:

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width="82" height="76" xmlns="http://www.w3.org/2000/svg">
  <g style="stroke-width: 3">
    <circle cx="20" cy="56" r="16" style="stroke: #cb3c33; fill: #d5635c" />
    <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" />
    <circle cx="62" cy="56" r="16" style="stroke: #9558b2; fill: #aa79c1" />
  </g>
</svg>
""")
```

With single quotes:

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width='82' height='76' xmlns='http://www.w3.org/2000/svg'>
  <g style='stroke-width: 3'>
    <circle cx='20' cy='56' r='16' style='stroke: #cb3c33; fill: #d5635c' />
    <circle cx='41' cy='20' r='16' style='stroke: #389826; fill: #60ad51' />
    <circle cx='62' cy='56' r='16' style='stroke: #9558b2; fill: #aa79c1' />
  </g>
</svg>
""")
```

With a mixture of single and double quotes:

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width='82' height='76' xmlns='http://www.w3.org/2000/svg'>
  <g style='stroke-width: 3'>
    <circle cx='20' cy='56' r='16' style='stroke: #cb3c33; fill: #d5635c' />
    <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" />
    <circle cx='62' cy='56' r='16' style='stroke: #9558b2; fill: #aa79c1' />
  </g>
</svg>
""")
```

With viewBox and without xmlns, making the svg really large to test that it is resized correctly:

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width="8200" height="7600" viewBox="0 0 82 76">
  <g style="stroke-width: 3">
    <circle cx="20" cy="56" r="16" style="stroke: #cb3c33; fill: #d5635c" />
    <circle cx="41" cy="20" r="16" style="stroke: #389826; fill: #60ad51" />
    <circle cx="62" cy="56" r="16" style="stroke: #9558b2; fill: #aa79c1" />
  </g>
</svg>
""")
```

Without viewBox and without xmlns, making the svg really large to test that it is resized correctly:

```@example inlinesvg
using .InlineSVG
SVG("""
<svg width="8200" height="7600">
  <g style="stroke-width: 300">
    <circle cx="2000" cy="5600" r="1600" style="stroke: #cb3c33; fill: #d5635c" />
    <circle cx="4100" cy="2000" r="1600" style="stroke: #389826; fill: #60ad51" />
    <circle cx="6200" cy="5600" r="1600" style="stroke: #9558b2; fill: #aa79c1" />
  </g>
</svg>
""")
```

_Note: we can't define the `show` method in the `@example` block due to the world age
counter in Julia 0.6 (Documenter's `makedocs` is not aware of any of the new method
definitions happening in `eval`s)._

We can also show SVG images with interactivity via the `text/html` MIME to display output that combines HTML, JS and CSS. Assume the following type and method live in the `InlineHTML` module

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

Download [`data.csv`](data.csv).


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

## Customizing assets

The following example only works on the deploy build where

```julia
mathengine = MathJax2(Dict(
    :TeX => Dict(
        :equationNumbers => Dict(:autoNumber => "AMS"),
        :Macros => Dict(
            :ket => ["|#1\\rangle", 1],
            :bra => ["\\langle#1|", 1],
            :pdv => ["\\frac{\\partial^{#1} #2}{\\partial #3^{#1}}", 3, ""],
        ),
    ),
)),
```
or on MathJax v3, the
[physics package](http://mirrors.ibiblio.org/CTAN/macros/latex/contrib/physics/physics.pdf)
can be loaded:

```julia
mathengine = MathJax3(Dict(
    :loader => Dict("load" => ["[tex]/physics"]),
    :tex => Dict(
        "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
        "tags" => "ams",
        "packages" => ["base", "ams", "autoload", "physics"],
    ),
)),
```

```math
\bra{x}\ket{y}
\pdv[n]{f}{x}
```

The following at-raw block only renders correctly on the deploy build, where

```julia
assets = [
  asset("https://fonts.googleapis.com/css?family=Nanum+Brush+Script&display=swap", class=:css),
  ...
]
```

```@raw html
<div style="font-family: 'Nanum Brush Script'; text-align: center; font-size: xx-large;">
Hello World!
<br />
Written in <a href="https://fonts.google.com/specimen/Nanum+Brush+Script">Nanum Brush Script.</a>
</div>
```

## Handling of `text/latex`

You can define a type that has a `Base.show` method for the `text/latex` MIME:

```@example showablelatex
struct LaTeXEquation
    code :: String
end
Base.show(io, ::MIME"text/latex", latex::LaTeXEquation) = write(io, latex.code)
nothing # hide
```

In an `@example` or `@eval` block, it renders as an equation:

```@example showablelatex
LaTeXEquation(raw"Foo $x^2$ bar.")
```

Documenter also supports having the LaTeX text being already wrapped in `\[ ... \]`:

```@example showablelatex
LaTeXEquation(raw"\[\left[ \begin{array}{rr}x&2 x\end{array}\right]\]")
```

or wrapped in `$$ ... $$`:

```@example showablelatex
LaTeXEquation(raw"$$\begin{bmatrix} 1 & 2 \\ 3 & 4 \end{bmatrix}$$")
```

---

Extra tests for handling multi-line equations ([#1518](https://github.com/JuliaDocs/Documenter.jl/pull/1518)):


```@example showablelatex
LaTeXEquation(raw"""
\[
    \left[
        \begin{array}{rr}
            x & 2x
        \end{array}
    \right]
\]
""")
```

```@example showablelatex
LaTeXEquation(raw"""$$
\begin{bmatrix}
    1 & 2 \\
    3 & 4
\end{bmatrix}
$$""")
```

Without `raw""` strings we have to double-escape our `\` and `$`:

```@example showablelatex
LaTeXEquation("\\[\\left[\\begin{array}{rr} x & 2x \\\\ \n y & y \\end{array}\\right]\\]")
```

```@example showablelatex
LaTeXEquation("\$\$\\begin{bmatrix} 1 & 2 \\\\ \n 3 & 4 \\end{bmatrix}\$\$")
```

Inline-ish `text/latex` bytes:

```@example showablelatex
LaTeXEquation("\$ x_{1} + x_{2} \$")
```

## Videos

![](https://dl8.webmfiles.org/big-buck-bunny_trailer.webm)
