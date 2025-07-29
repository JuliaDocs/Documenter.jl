edge_case_queries = [
    # Atypical Content
    TestQuery("α β γ", ["atypical_content.md"]),
    TestQuery("🚀", ["atypical_content.md"]),
    TestQuery("averylongunbrokenstringofcharacterstotestthesearchindex", ["atypical_content.md"]),
    TestQuery("мир", ["atypical_content.md"]),

    # Structural Cases
    TestQuery("An Empty Section", ["structural_cases.md"]),
    TestQuery("A Section With Only A Code Block", ["structural_cases.md"]),
    TestQuery("function foo()", ["structural_cases.md"]),

    # Markdown Syntax
    TestQuery("Deeply nested lists", ["markdown_syntax.md"]),
    TestQuery("complex to parse correctly", ["markdown_syntax.md"]),
    TestQuery("blockquote with nested blockquotes", ["markdown_syntax.md"]),

    # Common Words
    TestQuery("function struct end", ["common_words.md"]),

    # Auto-generated Docs
    TestQuery("Documenter", ["autodocs.md"]),
    TestQuery("makedocs", ["autodocs.md"]),
    TestQuery("func1", ["autodocs.md"]),
    TestQuery("func2", ["autodocs.md"]),
    TestQuery("MyType", ["autodocs.md"]),
    TestQuery("docstring for func1", ["autodocs.md"]),
    TestQuery("docstring for func2", ["autodocs.md"]),

    # Cross-references
    TestQuery("link to the welcome page", ["cross_references.md"]),
    TestQuery("cross-referencing syntax", ["cross_references.md"]),

    # Doctests
    TestQuery("jldoctest", ["doctests.md"]),
    TestQuery("1 + 1", ["doctests.md"]),

    # LaTeX
    TestQuery("inline equation", ["latex.md"]),
    TestQuery("display equation", ["latex.md"]),
    TestQuery("sqrt{x^2 + y^2}", ["latex.md"]),
    TestQuery("int_0^infty e^{-x^2} dx", ["latex.md"]),
    TestQuery("pi", ["latex.md"]),

    # Tables
    TestQuery("table rendering", ["tables.md"]),
    TestQuery("| A | B | C |", ["tables.md"]),
    TestQuery("|---|---|---|", ["tables.md"]),
    TestQuery("| 1 | 2 | 3 |", ["tables.md"]),
]
