using Documenter, DocumenterTools

makedocs(
    modules = [Documenter, DocumenterTools],
    clean = false,
    assets = ["assets/favicon.ico"],
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    analytics = "UA-89508993-1",
    linkcheck = !("skiplinks" in ARGS),
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
    ],
    # Use clean URLs, unless built as a "local" build
    html_prettyurls = !("local" in ARGS),
    html_canonical = "https://juliadocs.github.io/Documenter.jl/stable/",
)

deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    target = "build",
)
