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

# ==============================================================================
#  Modify the release notes
# ==============================================================================

function fix_release_line(
    line::String;
    repo::String = "JuliaDocs/Documenter.jl",
)
    # Rule: ((abc#XXXX) -> ([abc#XXXX](https://github.com/abc/issue/XXXX))
    # Description: Replace issue/PR nnumbers with a link to the default repo
    # Example: (JuliaLang/julia#123) -> ([JuliaLang/julia#123](https://github.com/JuliaLang/julia/issues/123))
    # There is no need to distinguish between PRs and Issues because GitHub
    # redirects.
    while (m = match(r"\(([a-zA-Z0-9/]+?)\#([0-9]+)\)", line)) !== nothing
        new_repo, id = m.captures[1], m.captures[2]
        line = replace(line, m.match => "([$new_repo#$id](https://github.com/$new_repo/issues/$id))")
    end
    # Rule: (#XXXX) -> ([#XXXX](https://github.com/url/issue/XXXX))
    # Description: Replace issue/PR nnumbers with a link to the default repo
    # Example: (#123) -> ([#123](https://github.com/JuliaDocs/Documenter.jl/issues/123))
    # There is no need to distinguish between PRs and Issues because GitHub
    # redirects.
    while (m = match(r"\(\#([0-9]+)\)", line)) !== nothing
        id = m.captures[1]
        line = replace(line, m.match => "([#$id](https://github.com/$repo/issues/$id))")
    end
    # Rule: (@XXXX) -> ([@XXXX](https://github.com/XXXX))
    # Description: Replace users with a link to their GitHub
    # Example: (@odow) -> ([@odow](https://github.com/odow))
    while (m = match(r"\(@(.+?)\)", line)) !== nothing
        id = m.captures[1]
        line = replace(line, m.match => "([@$id](https://github.com/$id))")
    end
    # Rule: ## Version vX.Y.Z -> ## Version [vX.Y.Z](url/releases/tag/vX.Y.Z)
    # Description: Replace version headers with a link to the GitHub tag
    # Example: ## Version v0.27.0 -> ## Version [v0.27.0](https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.0)
    while (m = match(r"\#\# Version (v[0-9]+.[0-9]+.[0-9]+)", line)) !== nothing
        tag = m.captures[1]
        line = replace(
            line,
            m.match => "## Version [$tag](https://github.com/$repo/releases/tag/$tag)",
        )
    end
    return line
end

function rewrite_changelog(;
    changelog_filename::String,
    release_notes_filename::String,
    current_module::String,
    repo::String,
    branch::String = "master",
)
    header = """
    ```@meta
    CurrentModule = $current_module
    EditURL = "https://github.com/$repo/blob/$branch/CHANGELOG.md"
    ```
    """
    open(changelog_filename, "r") do in_io
        open(release_notes_filename, "w") do out_io
            write(out_io, header)
            for line in readlines(in_io; keep = true)
                write(out_io, fix_release_line(line; repo = repo))
            end
        end
    end
    return
end

rewrite_changelog(
    changelog_filename = joinpath(dirname(@__DIR__), "CHANGELOG.md"),
    release_notes_filename = joinpath(@__DIR__, "src", "release-notes.md"),
    current_module = "Documenter",
    repo = "JuliaDocs/Documenter.jl",

)

makedocs(
    modules = [Documenter, DocumenterTools, DocumenterShowcase],
    format = if "pdf" in ARGS
        Documenter.LaTeX(platform = "docker")
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
    clean = false,
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
        "release-notes.md",
    ],
    strict = !("strict=false" in ARGS),
    doctest = ("doctest=only" in ARGS) ? :only : true,
)

if "pdf" in ARGS
    # hack to only deploy the actual pdf-file
    mkpath(joinpath(@__DIR__, "build-pdf", "commit"))
    let files = readdir(joinpath(@__DIR__, "build-pdf"))
        for f in files
            if startswith(f, "Documenter.jl") && endswith(f, ".pdf")
                mv(joinpath(@__DIR__, "build-pdf", f),
                joinpath(@__DIR__, "build-pdf", "commit", f))
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
