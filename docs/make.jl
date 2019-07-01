using Documenter, DocumenterTools

# The DOCSARGS environment variable can be used to pass additional arguments to make.jl.
# This is useful on CI, if you need to change the behavior of the build slightly but you
# can not change the .travis.yml or make.jl scripts any more (e.g. for a tag build).
if haskey(ENV, "DOCSARGS")
    for arg in split(ENV["DOCSARGS"])
        push!(ARGS, arg)
    end
end

makedocs(
    modules = [Documenter, DocumenterTools],
    format = Documenter.HTML(
        # Use clean URLs, unless built as a "local" build
        prettyurls = !("local" in ARGS),
        canonical = "https://juliadocs.github.io/Documenter.jl/stable/",
        assets = ["assets/favicon.ico"],
        analytics = "UA-136089579-2",
    ),
    clean = false,
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    linkcheck = !("skiplinks" in ARGS),
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
        "Library" => Any[
            "Public" => "lib/public.md",
            hide("Internals" => "lib/internals.md", Any[
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
            ])
        ],
        "contributing.md",
    ],
    strict = !("strict=false" in ARGS),
    doctest = ("doctest=only" in ARGS) ? :only : true,
)

deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    target = "build",
)
