using Documenter

makedocs(
    format = Documenter.LaTeX(platform = "docker"),
    sitename = "LaTeX TOC Depth",
    pages = [
        "Part-I" => "index.md",
    ],
    authors = "The Julia Project",
)
