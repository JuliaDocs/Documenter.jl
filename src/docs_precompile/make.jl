using Documenter, Logging

# A module with docstrings for the `@docs` and `@autodocs` blocks.
module _PrecompileExample
    export Point, norm2

    "A constant."
    const ORIGIN = 0

    """
        Point{T}

    A point, see [`norm2`](@ref).

    # Fields
    - `x::T`: the x coordinate
    - `y::T`: the y coordinate
    """
    struct Point{T <: Real}
        x::T
        y::T
    end

    """
        norm2(p::Point) -> Real

    The squared norm of `p`, ``x^2 + y^2``.

    !!! note
        See also [`Point`](@ref).
    """
    norm2(p::Point) = p.x^2 + p.y^2

    "A method with a `Union` argument."
    norm2(x::Union{Integer, AbstractFloat}, y::Real = 0; scale::Real = 1) = scale * (x^2 + y^2)

    "An abstract type."
    abstract type Shape end

    "A macro."
    macro m(x)
        return x
    end
end

# Code blocks that are evaluated (`@example`, doctests etc) are left out because they
# create modules in `Main`, which isn't allowed during precompilation. For the same reason
# `CurrentModule` is set with `meta`, because `@meta` blocks are evaluated in `Main`.
with_logger(NullLogger()) do
    makedocs(
        sitename = "TestPkg",
        root = @__DIR__,
        modules = [_PrecompileExample],
        meta = Dict{Symbol, Any}(:CurrentModule => _PrecompileExample),
        pages = Any[
            "Home" => "index.md",
            "API" => "api.md",
        ],
        build = mktempdir(),
        remotes = nothing,
        checkdocs = :exports,
    )
end
