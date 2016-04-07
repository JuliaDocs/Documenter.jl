using Documenter

makedocs(
    modules = Documenter,
    clean   = false,
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material"),
    repo = "github.com/MichaelHatherly/Documenter.jl.git",
)
