
using Documenter
include("dummy_module.jl")

makedocs(
    root = @__DIR__,
    sitename = "Search Edge Case Tests",
    format = Documenter.HTML(
        prettyurls = false,
    ),
    pages = [
        "Welcome" => "index.md",
        "Atypical Content" => "atypical_content.md",
        "Structural Cases" => "structural_cases.md",
        "Markdown Syntax" => "markdown_syntax.md",
        "Common Words" => "common_words.md",
        "Auto-generated Docs" => "autodocs.md",
        "Cross-references" => "cross_references.md",
        "Doctests" => "doctests.md",
        "LaTeX" => "latex.md",
        "Tables" => "tables.md",
    ],
    build = "build",
)
