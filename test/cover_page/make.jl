using Documenter

makedocs(
    format = Documenter.LaTeX(platform = "docker"),
    sitename = "PDF Cover Page",
    pages = [
        "Home" => "index.md",
    ],
    authors = "The Julia Project",
)
