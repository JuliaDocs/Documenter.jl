using Documenter

makedocs(
    modules = [Documenter],
    clean = false,
    format = :html,
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
            "man/hosting.md",
            "man/latex.md",
            "man/internals.md",
            "man/contributing.md",
        ],
        "Library" => Any[
            "Public" => "lib/public.md",
            hide("Internals" => "lib/internals.md", Any[
                "lib/internals/anchors.md",
                "lib/internals/builder.md",
                "lib/internals/cross-references.md",
                "lib/internals/docchecks.md",
                "lib/internals/docsystem.md",
                "lib/internals/documenter.md",
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
            ])
        ]
    ],
    # Use clean URLs, unless built as a "local" build
    html_prettyurls = !("local" in ARGS),
)

deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
)
