using Documenter, DocumenterTools, Changelog
include("DocumenterShowcase.jl")

# The DOCSARGS environment variable can be used to pass additional arguments to make.jl.
# This is useful on CI, if you need to change the behavior of the build slightly but you
# can not change the .travis.yml or make.jl scripts any more (e.g. for a tag build).
if haskey(ENV, "DOCSARGS")
    for arg in split(ENV["DOCSARGS"])
        (arg in ARGS) || push!(ARGS, arg)
    end
end

# Generate a Documenter-friendly changelog from CHANGELOG.md
Changelog.generate(
    Changelog.Documenter(),
    joinpath(@__DIR__, "..", "CHANGELOG.md"),
    joinpath(@__DIR__, "src", "release-notes.md");
    repo = "JuliaDocs/Documenter.jl",
)

linkcheck_ignore = [
    # We'll ignore links that point to GitHub's edit pages, as they redirect to the
    # login screen and cause a warning:
    r"https://github.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/edit(.*)",
    "https://nvd.nist.gov/vuln/detail/CVE-2018-16487",
    # We'll ignore the links to Documenter tags in CHANGELOG.md, since when you tag
    # a release, the release link does not exist yet, and this will cause the linkcheck
    # CI job to fail on the PR that tags a new release.
    r"https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.\d+.\d+",
]
# Extra ones we ignore only on CI.
if get(ENV, "GITHUB_ACTIONS", nothing) == "true"
    # It seems that CTAN blocks GitHub Actions?
    push!(linkcheck_ignore, "https://ctan.org/pkg/minted")
end

makedocs(
    modules = [Documenter, DocumenterTools, DocumenterShowcase],
    format = if "pdf" in ARGS
        Documenter.LaTeX(platform = "docker")
    else
        Documenter.HTML(
            # Use clean URLs, unless built as a "local" build
            prettyurls = !("local" in ARGS),
            canonical = "https://documenter.juliadocs.org/stable/",
            assets = ["assets/favicon.ico"],
            analytics = "UA-136089579-2",
            highlights = ["yaml"],
            ansicolor = true,
            size_threshold_ignore = ["release-notes.md"],
            inventory_version = Documenter.DOCUMENTER_VERSION,
        )
    end,
    build = ("pdf" in ARGS) ? "build-pdf" : "build",
    debug = ("pdf" in ARGS),
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    linkcheck = "linkcheck" in ARGS,
    linkcheck_ignore = linkcheck_ignore,
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Guide" => "man/guide.md",
            "man/examples.md",
            "man/syntax.md",
            "man/doctests.md",
            "man/latex.md",
            hide("man/hosting.md", ["man/hosting/walkthrough.md"]),
            "man/other-formats.md",
        ],
        "showcase.md",
        "Reference" => Any[
            "Public API" => "lib/public.md",
            "lib/remote-links.md",
            "Semantic versioning" => "lib/semver.md",
        ],
        "Developers" => [
            "contributing.md",
            "checklists.md",
            "Internals" => map(
                s -> "lib/internals/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/lib/internals")))
            ),
        ],
        "release-notes.md",
    ],
    warnonly = ("strict=false" in ARGS),
    doctest = ("doctest=only" in ARGS) ? :only : true,
)

if "pdf" in ARGS
    # hack to only deploy the actual pdf-file
    mkpath(joinpath(@__DIR__, "build-pdf", "commit"))
    let files = readdir(joinpath(@__DIR__, "build-pdf"))
        for f in files
            if startswith(f, "Documenter.jl") && endswith(f, ".pdf")
                mv(
                    joinpath(@__DIR__, "build-pdf", f),
                    joinpath(@__DIR__, "build-pdf", "commit", f)
                )
            end
        end
    end
    deploydocs(
        repo = "github.com/JuliaDocs/Documenter.jl.git",
        target = "pdf/build-pdf/commit",
        branch = "gh-pages-pdf",
        forcepush = true,
    )
else
    deploydocs(
        repo = "github.com/JuliaDocs/Documenter.jl.git",
        target = "build",
        push_preview = true,
    )
end
