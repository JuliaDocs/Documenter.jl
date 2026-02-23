module XRefSignatures

# Testing the method signature lookup behaviour (with UnionAll) as described in
# https://github.com/JuliaDocs/Documenter.jl/pull/2889

using Test
using Documenter
using IOCapture

isdefined(Main, :XRefSignaturesMain) || @eval Main module XRefSignaturesMain
    """
        g

    This is the general function `g`.
    """
    function g end

    """
        g(::Float64)

    This is the specialized method of `g` with signature (::Float64)

    See also [parametric `g`](@ref g(::X) where X).

    See also [parametric array `g`](@ref g(::AbstractArray{S}) where S <: Number).
    """
    g(::Float64) = "Specialized to Float64."

    """
        g(::X) where X

    This is a parametric method `g`, with UnionAll signature (::X) where X

    See also [specialized `g`](@ref g(::Float64)).
    """
    function g(::X) where {X}
        return "Parametric method $(nameof(X))."
    end

    """
        g(::AbstractArray{T}) where T <: Number

    This is another parametric method `g`, this time with a constrained type parameter.

    See also [plain parametric `g`](@ref g(::X) where X).
    """
    function g(::AbstractArray{T}) where {T <: Number}
        return "Numerical array method $(nameof(T))."
    end

    export g
end


@testset "Cross-referencing methods" begin
    kwargs = (
        root = dirname(@__FILE__),
        source = "src",
        build = "build",
        modules = Main.XRefSignaturesMain,
        sitename = "XRefSignatures",
        warnonly = false,
        format = Documenter.HTML(
            prettyurls = false,
            inventory_version = "",
        ),
    )

    captured = IOCapture.capture() do
        makedocs(; kwargs...)
    end
    @test isnothing(captured.value)

    index_html = joinpath(dirname(@__FILE__), "build", "index.html")
    @test isfile(index_html)
    if isfile(index_html)
        html = read(index_html, String)

        # Find anchor name for docstring containing AbstractArray (this differs between Julia 1.6 and 1.12!)
        array_anchor_pattern = r"""<a\s+class="docstring-binding"\s+href="([^"]*AbstractArray[^"]*)"[^>]*>\s*<code>Main\.XRefSignaturesMain\.g</code>\s*</a>"""x
        array_anchor_rx = match(array_anchor_pattern, html)
        @test !isnothing(array_anchor_rx)
        array_anchor = array_anchor_rx.captures[1]

        # Body -> API xref
        @test contains(html, """<a href="index.html#Main.XRefSignaturesMain.g-Tuple{Float64}">specialized methods</a>""")
        @test contains(html, """<a href="index.html#Main.XRefSignaturesMain.g-Tuple{X} where X">parametric methods</a>""")
        @test contains(html, """<a href="index.html$(array_anchor)">constrained parametric methods</a>""")
        @test contains(html, """<a href="index.html#Main.XRefSignaturesMain.g-Tuple{X} where X"><code>g(::Y) where Y</code></a>""")

        # API -> API xref
        @test contains(html, """See also <a href="index.html#Main.XRefSignaturesMain.g-Tuple{X} where X">parametric <code>g</code></a>""")
        @test contains(html, """See also <a href="index.html$(array_anchor)">parametric array <code>g</code></a>""")
        @test contains(html, """See also <a href="index.html#Main.XRefSignaturesMain.g-Tuple{Float64}">specialized <code>g</code></a>""")
        @test contains(html, """See also <a href="index.html#Main.XRefSignaturesMain.g-Tuple{X} where X">plain parametric <code>g</code></a>""")
    end
end

end
