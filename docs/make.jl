using Documenter

makedocs(
    modules = Documenter,
    clean   = false,
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material", "python-markdown-math"),
    repo = "github.com/MichaelHatherly/Documenter.jl.git",
)
