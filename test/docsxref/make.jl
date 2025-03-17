module DocsXRefTests

# Testing the fallback behavior implemented in
# https://github.com/JuliaDocs/Documenter.jl/pull/2470

using Test
using Documenter
using IOCapture

isdefined(Main, :Documenter) || @eval Main import Documenter

isdefined(Main, :AbstractSelector) || @eval Main using Documenter.Selectors: AbstractSelector

isdefined(Main, :DocsReferencingMain) || @eval Main module DocsReferencingMain
    export f, g

    """This is the function `f`.

    It references [`Documenter.Selectors.AbstractSelector`](@ref), which
    resolves only because of a fallback to `Main`.

    See also [`g`](@ref).
    """
    f(x) = x

    """This is the function `g`

    If references [`Main.AbstractSelector`](@ref), which should resolve,
    unlike the non-fully-qualified [`AbstractSelector`](@ref) (even though
    `AbstractSelector` is in `Main`)

    See also [`f`](@ref).
    """
    g(x) = x
end


@testset "xrefs to Main" begin

    kwargs = (
        root = dirname(@__FILE__),
        source = "src",
        build = "build",
        sitename = "DocsXRef",
        warnonly = true,
        format = Documenter.HTML(
            prettyurls = false,
            inventory_version = "",
        ),
    )

    captured = IOCapture.capture() do
        makedocs(; kwargs...)
    end
    @test isnothing(captured.value)
    @test contains(
        replace(captured.output, "\\src\\index" => "/src/index"),
        """
        ┌ Warning: Cannot resolve @ref for md"[`AbstractSelector`](@ref)" in docsxref/src/index.md.
        │ - No docstring found in doc for binding `Main.DocsReferencingMain.AbstractSelector`.
        │ - Fallback resolution in Main for `AbstractSelector` -> `Documenter.Selectors.AbstractSelector` is only allowed for fully qualified names
        """
    )
    @test contains(
        replace(captured.output, "\\src\\page" => "/src/page"),
        """
        ┌ Warning: Cannot resolve @ref for md"[`DocsReferencingMain.f`](@ref)" in docsxref/src/page.md.
        │ - Exception trying to find docref for `DocsReferencingMain.f`: unable to get the binding for `DocsReferencingMain.f` in module Documenter.Selectors
        │ - Fallback resolution in Main for `DocsReferencingMain.f` -> `Main.DocsReferencingMain.f` is only allowed for fully qualified names
        """
    )
    index_html = joinpath(dirname(@__FILE__), "build", "index.html")
    @test isfile(index_html)
    if isfile(index_html)
        html = read(index_html, String)
        @test contains(html, "<a href=\"index.html#Documenter.Selectors.AbstractSelector\"><code>AbstractSelector</code></a>")
        @test contains(html, "<a href=\"index.html#Documenter.Selectors.AbstractSelector\"><code>Documenter.Selectors.AbstractSelector</code></a>")
        @test contains(html, "<a href=\"index.html#Documenter.Selectors.AbstractSelector\"><code>Main.AbstractSelector</code></a>")
        @test contains(html, "<a href=\"@ref\"><code>AbstractSelector</code></a>")
    end
    page_html = joinpath(dirname(@__FILE__), "build", "page.html")
    @test isfile(page_html)
    if isfile(page_html)
        html = read(page_html, String)
        @test contains(html, "<a href=\"index.html#Documenter.Selectors.AbstractSelector\"><code>AbstractSelector</code></a>")
        @test contains(html, "<a href=\"@ref\"><code>DocsReferencingMain.f</code></a>")
        @test contains(html, "<a href=\"index.html#Main.DocsReferencingMain.f\"><code>Main.DocsReferencingMain.f</code></a>")
        @test contains(html, "<a href=\"index.html#Documenter.hide\"><code>Documenter.hide</code></a>")
    end

end

end
