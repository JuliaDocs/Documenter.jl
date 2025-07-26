
using Documenter

makedocs(
    root = @__DIR__,
    sitename = "Search Edge Case Tests",
    format = Documenter.HTML(
        prettyurls = false,
    ),
    pages = [
        "Home" => "index.md",
        "Atypical Content" => "atypical_content.md",
        "Structural Cases" => "structural_cases.md",
        "Markdown Syntax" => "markdown_syntax.md",
        "Common Words" => "common_words.md",
    ],
    build = "build",
)
