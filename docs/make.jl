using Documenter, DocumenterTools
include("DocumenterShowcase.jl")

# The DOCSARGS environment variable can be used to pass additional arguments to make.jl.
# This is useful on CI, if you need to change the behavior of the build slightly but you
# can not change the .travis.yml or make.jl scripts any more (e.g. for a tag build).
if haskey(ENV, "DOCSARGS")
    for arg in split(ENV["DOCSARGS"])
        (arg in ARGS) || push!(ARGS, arg)
    end
end

makedocs(
    modules = [Documenter, DocumenterTools, DocumenterShowcase],
    format = if "pdf" in ARGS
        Documenter.LaTeX(platform = "none")
    else
        Documenter.HTML(
            # Use clean URLs, unless built as a "local" build
            prettyurls = !("local" in ARGS),
            canonical = "https://juliadocs.github.io/Documenter.jl/stable/",
            assets = ["assets/favicon.ico"],
            analytics = "UA-136089579-2",
            highlights = ["yaml"],
            ansicolor = true,
        )
    end,
    build = ("pdf" in ARGS) ? "build-pdf" : "build",
    debug = ("pdf" in ARGS),
    clean = true,
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    linkcheck = "linkcheck" in ARGS,
    linkcheck_ignore = [
        # We'll ignore links that point to GitHub's edit pages, as they redirect to the
        # login screen and cause a warning:
        r"https://github.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/edit(.*)",
    ] ∪ (get(ENV, "GITHUB_ACTIONS", nothing)  == "true" ? [
        # Extra ones we ignore only on CI.
        #
        # It seems that CTAN blocks GitHub Actions?
        "https://ctan.org/pkg/minted",
    ] : []),
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
            "Internals" => map(
                s -> "lib/internals/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/lib/internals")))
            ),
        ],
        "contributing.md",
    ],
    strict = !("strict=false" in ARGS),
    doctest = ("doctest=only" in ARGS) ? :only : true,
)

# if "pdf" in ARGS
#     # hack to only deploy the actual pdf-file
#     mkpath(joinpath(@__DIR__, "build-pdf", "commit"))
#     let files = readdir(joinpath(@__DIR__, "build-pdf"))
#         for f in files
#             if startswith(f, "Documenter.jl") && endswith(f, ".pdf")
#                 mv(joinpath(@__DIR__, "build-pdf", f),
#                 joinpath(@__DIR__, "build-pdf", "commit", f))
#             end
#         end
#     end
#     deploydocs(
#         repo = "github.com/JuliaDocs/Documenter.jl.git",
#         target = "pdf/build-pdf/commit",
#         branch = "gh-pages-pdf",
#         forcepush = true,
#     )
# else
#     deploydocs(
#         repo = "github.com/JuliaDocs/Documenter.jl.git",
#         target = "build",
#         push_preview = true,
#     )
# end
