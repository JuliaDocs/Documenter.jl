module LaTeXFormatTests

using Test

using Documenter

# Documenter package docs
@info("Building Documenter's docs with LaTeX.")
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
            "man/latex.md",
            "man/hosting.md",
            "man/other-formats.md",
        ],
        "Library" => Any[
            "Public" => "lib/public.md",
            hide("Internals" => "lib/internals.md", Any[
                "lib/internals/anchors.md",
                "lib/internals/builder.md",
                "lib/internals/cross-references.md",
                "lib/internals/docchecks.md",
                "lib/internals/docsystem.md",
                "lib/internals/doctests.md",
                "lib/internals/documenter.md",
                "lib/internals/documentertools.md",
                "lib/internals/documents.md",
                "lib/internals/dom.md",
                "lib/internals/expanders.md",
                "lib/internals/formats.md",
                "lib/internals/mdflatten.md",
                "lib/internals/selectors.md",
                "lib/internals/textdiff.md",
                "lib/internals/utilities.md",
                "lib/internals/writers.md",
            ])
        ],
        "contributing.md",
    ]
)

@testset "LaTeX" begin
    @test isa(doc, Documenter.Documents.Document)
end

end
