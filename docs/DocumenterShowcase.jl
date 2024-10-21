"""
This is the [`DocumenterShowcase`](@ref), which contains

* [`DocumenterShowcase.foo`](@ref)
* [`DocumenterShowcase.bar`](@ref)

!!! compat "Documenter 0.24"

    This showcase page is included in Documenter version 0.24.0 and above.

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
    foo(::Integer)

Docstring for `foo(::Integer)`.
"""
foo(::Integer) = nothing

"""
    foo(::AbstractString)

Docstring for `foo(::AbstractString)`.
"""
foo(::AbstractString) = nothing

"""
    bar(::Integer)

Docstring for `bar(::Integer)`.
"""
bar(::Integer) = nothing

"""
    bar(::AbstractString)

Docstring for `bar(::AbstractString)`.
"""
bar(::AbstractString) = nothing

"""
    baz(x, f, k)

Function with a more complex docstring.
Headings that are part of docstrings are not rendered as headings but rather as bold text:

# Arguments
- `x::Integer`: the first argument
- `f`: a function with multiple allowable arguments itself  

  ## Pattern
  - `f(a::Integer)`
  - `f(a::Real)`
  - `f(a::Real, b::Real)`

- `k::Integer`: the third argument

See also [`bar`](@ref).
"""
baz(x::Integer, f, k::Integer) = nothing

function hello(who)
    println("Hello, $(who)!")
    return
end

struct SVGCircle
    stroke::String
    fill::String
end
function Base.show(io, ::MIME"image/svg+xml", c::SVGCircle)
    write(
        io, """
        <svg width="50" height="50">
          <g style="stroke-width: 3">
            <circle cx="25" cy="25" r="24" stroke-width="2" style="stroke: #$(c.stroke); fill: #$(c.fill)" />
          </g>
        </svg>
        """
    )
    return
end

"The type definition."
struct Foo{T, S} end

"Constructor `Foo()` with no arguments."
Foo() = Foo{Nothing, Nothing}()

"Constructor `Foo{T}()` with one parametric argument."
Foo{T}() where {T} = Foo{T, Nothing}()

end # module
