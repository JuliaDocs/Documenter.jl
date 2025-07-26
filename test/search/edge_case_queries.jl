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
]
