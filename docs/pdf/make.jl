using Documenter, DocumenterTools
using Test

const ROOT = joinpath(@__DIR__, "..")

# Documenter package docs
doc = makedocs(
    debug = true,
    root = ROOT,
    build = "pdf/build",
    modules = [Documenter, DocumenterTools],
    clean = false,
    format = Documenter.LaTeX(platform = "docker"),
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
            hide("man/hosting.md", [
                "man/hosting/walkthrough.md"
            ]),
            "man/other-formats.md",
        ],
        "showcase.md",
        "Library" => Any[
            "Public" => "lib/public.md",
            "Internals" => Any[
                "lib/internals/anchors.md",
                "lib/internals/builder.md",
                "lib/internals/cross-references.md",
                "lib/internals/docchecks.md",
                "lib/internals/docmeta.md",
                "lib/internals/docsystem.md",
                "lib/internals/doctests.md",
                "lib/internals/documenter.md",
                "lib/internals/documentertools.md",
                "lib/internals/documents.md",
                "lib/internals/dom.md",
                "lib/internals/expanders.md",
                "lib/internals/markdown2.md",
                "lib/internals/mdflatten.md",
                "lib/internals/selectors.md",
                "lib/internals/textdiff.md",
                "lib/internals/utilities.md",
                "lib/internals/writers.md",
            ],
        ],
        "contributing.md",
    ],
);

# hack to only deploy the actual pdf-file
mkpath(joinpath(ROOT, "pdf", "build", "pdfdir"))
let files = readdir(joinpath(ROOT, "pdf", "build"))
    for f in files
        if startswith(f, "Documenter.jl") && endswith(f, ".pdf")
            mv(joinpath(ROOT, "pdf", "build", f),
               joinpath(ROOT, "pdf", "build", "pdfdir", f))
        end
    end
end


deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    root = ROOT,
    target = "pdf/build/pdfdir",
    branch = "gh-pages-pdf",
    forcepush = true,
)
