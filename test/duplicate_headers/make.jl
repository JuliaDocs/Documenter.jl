module DuplicateHeaderTests

# A non-unique header slug must be reported, and must never be resolved as a binding:
# `[Blow-Ups](@ref)` parses as `Blow - Ups` and used to link to the docstring of `-`
# (https://github.com/JuliaDocs/Documenter.jl/issues/2668).
#
# It must also not pre-empt a reference that a later step resolves correctly, which is what
# made https://github.com/JuliaDocs/Documenter.jl/issues/2843 report 66 working links.

using Test
using Documenter
using IOCapture

isdefined(Main, :DuplicateHeaderContent) || @eval Main module DuplicateHeaderContent
    struct MyStruct end
    """This is the `-` method."""
    Base.:-(::MyStruct) = nothing

    """This is the `Stepsize` type, whose name also occurs as a header."""
    struct Stepsize end
end

@testset "Duplicate headers" begin
    captured = IOCapture.capture() do
        makedocs(
            root = dirname(@__FILE__),
            source = "src",
            build = "build",
            sitename = "DuplicateHeaders",
            modules = [Main.DuplicateHeaderContent],
            warnonly = true,
            remotes = nothing,
            format = Documenter.HTML(prettyurls = false, inventory_version = ""),
        )
    end
    output = replace(captured.output, "\\src\\index" => "/src/index")

    # The ambiguity is reported ...
    @test contains(output, "Cannot resolve @ref for md\"[Blow-Ups](@ref)\"")
    @test contains(output, "Header with slug 'Blow-Ups' is not unique")
    # ... and not papered over by a docstring lookup.
    @test !contains(output, "binding `Base.-`")

    html = read(joinpath(dirname(@__FILE__), "build", "index.html"), String)
    @test contains(html, "<a href=\"@ref\">Blow-Ups</a>")
    @test !occursin(r"<a href=\"[^\"]*Base[^\"]*\">Blow-Ups</a>", html)
    # An ambiguous header slug does not stop a docstring reference of the same name.
    @test contains(html, "#Main.DuplicateHeaderContent.Stepsize\"><code>Main.DuplicateHeaderContent.Stepsize</code></a>")
end

end
