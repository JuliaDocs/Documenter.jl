module DocsSubAnchors

# Testing the per-docstring anchor ids (`<section id="...">`) that aggregated @docs
# entries (a bare `Foo.bar` including all docstrings of the binding) emit in the
# HTML output.

using Test
using Documenter
using IOCapture

include("../TestUtilities.jl"); using Main.TestUtilities

module DocsSubAnchorsContent
    # Note: no docstring on `function f end` itself. If the binding has a docstring
    # with a `Union{}` typesig, a bare `@docs` entry includes only that docstring
    # (exact typesig match) instead of aggregating all method docstrings.
    """
        f(x)

    One-arg method of `f`.
    """
    f(x) = x

    """
        f(x, y)

    Two-arg method of `f`.
    """
    f(x, y) = x + y

    """
        g(x)

    Only documented method of `g`.
    """
    g(x) = x

    """
        h(::Float64)

    Float64 method of `h`.
    """
    h(x::Float64) = x

    """
        h(::String)

    String method of `h`.
    """
    h(x::String) = x

    export f, g, h
end

@testset "Sub-anchors for aggregated docstrings" begin
    kwargs = (
        root = dirname(@__FILE__),
        source = "src",
        build = "build",
        modules = [Main.DocsSubAnchors.DocsSubAnchorsContent],
        sitename = "DocsSubAnchors",
        warnonly = false,
        format = Documenter.HTML(
            prettyurls = false,
            inventory_version = "",
        ),
    )

    @quietly makedocs(; kwargs...)

    index_html = joinpath(dirname(@__FILE__), "build", "index.html")
    @test isfile(index_html)
    if isfile(index_html)
        html = read(index_html, String)
        P = "Main.DocsSubAnchors.DocsSubAnchorsContent"

        # Aggregated entry: methods with a typesig get the same anchor they would
        # have had as explicit signature entries.
        @test contains(html, """<section id="$P.f-Tuple{Any}">""")
        @test contains(html, """<section id="$P.f-Tuple{Any, Any}">""")
        @test !contains(html, "$P.f-doc")
        # The aggregate's own anchor is unchanged.
        @test contains(html, """<summary id="$P.f">""")

        # A single-docstring aggregate still gets a typesig id on its section, but
        # never a positional fallback.
        @test contains(html, """<section id="$P.g-Tuple{Any}">""")
        @test !contains(html, "$P.g-doc")

        # When the aggregate coexists with an explicit signature entry, the
        # explicit entry keeps sole ownership of the signature anchor and the
        # aggregate's section falls back to a positional id.
        @test count("id=\"$P.h-Tuple{Float64}\"", html) == 1
        @test contains(html, """<section id="$P.h-doc-1">""")
        @test contains(html, """<section id="$P.h-Tuple{String}">""")
        # Explicit single-docstring entries get no per-docstring id at all.
        @test !contains(html, "$P.h-Tuple{Float64}-doc")

        # All ids on the page are unique.
        ids = [m.captures[1] for m in eachmatch(r"\sid=\"([^\"]+)\"", html)]
        @test length(ids) == length(unique(ids))
    end
end

end
