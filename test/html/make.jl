using Documenter
using Compat

makedocs(
    modules  = Documenter,
    clean    = false,
    source   = "../../docs/src",
    format   = Documenter.Formats.HTML,
    sitename = "Documenter.jl",
    pages    = [( # Compat: parens needed for 0.4 syntax compat
        "Overview" => "index.md",
        "Manual" => [
            "man/guide.md",
            "man/examples.md",
            "man/syntax.md",
            "man/doctests.md",
            "man/hosting.md",
            "man/latex.md",
            "man/internals.md",
        ],
        "Library" => [
            "lib/public.md",
            "Internals" => [
                "lib/internals.md",
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
    )...]
)
