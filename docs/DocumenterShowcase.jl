"""
This is the [`DocumenterShowcase`](@ref), which contains

* [`DocumenterShowcase.foo`](@ref)
* [`DocumenterShowcase.bar`](@ref)

# Contents

Docstrings can contain admonitions and other block-level nodes.

!!! info

    This admonition is in a docstring. It itself can contain block levels nodes such
    as code blocks:

    ```julia
    println("Hello World")
    ```

    ... or block quotes:

    > Lorem ipsum.

In fact, while not recommended, you can actually have a matryoshka of admonitions:

!!! danger
    !!! warning
        !!! tip
            !!! note
                Stack overflow.
"""
module DocumenterShowcase

"""
Docstring for `foo(::Integer)`.
"""
foo(::Integer) = nothing

"""
Docstring for `foo(::AbstractString)`.
"""
foo(::AbstractString) = nothing

"""
Docstring for `bar(::Integer)`.
"""
bar(::Integer) = nothing

"""
Docstring for `bar(::AbstractString)`.
"""
bar(::AbstractString) = nothing

function hello(who)
    println("Hello, $(who)!")
end

struct SVGCircle
    stroke :: String
    fill :: String
end
function Base.show(io, ::MIME"image/svg+xml", c::SVGCircle)
    write(io, """
    <svg width="50" height="50">
      <g style="stroke-width: 3">
        <circle cx="20" cy="20" r="20" style="stroke: #$(c.stroke); fill: #$(c.fill)" />
      </g>
    </svg>
    """)
end

end # module
