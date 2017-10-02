module LaTeXFormatTests

using Test

using Documenter

# Documenter package docs
info("Building Documenter's docs with LaTeX.")
const Documenter_root = normpath(joinpath(dirname(@__FILE__), "..", "..", "docs"))
doc = makedocs(
    debug = true,
    root = Documenter_root,
    modules = [Documenter],
    clean = false,
    format = :latex,
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Guide" => "man/guide.md",
            "man/examples.md",
            "man/syntax.md",
            "man/doctests.md",
            "man/hosting.md",
            "man/latex.md",
            "man/internals.md",
            "man/contributing.md",
        ],
        "Library" => Any[
            "Public" => "lib/public.md",
            "Internals" => Any[
                "Internals" => "lib/internals.md",
                "lib/internals/anchors.md",
                "lib/internals/builder.md",
                "lib/internals/cross-references.md",
                "lib/internals/docchecks.md",
                "lib/internals/docsystem.md",
                "lib/internals/documents.md",
                "lib/internals/dom.md",
                "lib/internals/expanders.md",
                "lib/internals/formats.md",
                "lib/internals/generator.md",
                "lib/internals/mdflatten.md",
                "lib/internals/selectors.md",
                "lib/internals/utilities.md",
                "lib/internals/walkers.md",
                "lib/internals/writers.md",
            ]
        ]
    ]
)

@testset "LaTeX" begin
    @test isa(doc, Documenter.Documents.Document)
end

end
