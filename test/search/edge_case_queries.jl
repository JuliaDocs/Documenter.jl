struct TestQuery
    query::String
    expected_docs::Vector{String}
end

atypical_content_queries = [
    TestQuery("α β γ", String[]),
    TestQuery("🚀", String[]),
    TestQuery("averylongunbrokenstringofcharacterstotestthesearchindex", ["Atypical Content"]),
    TestQuery("мир", String[]),
    TestQuery("empty", ["An Empty Section"]),
    TestQuery("function", ["Structural Cases", "Doctests"]),
]

structural_cases_queries = [
    TestQuery("An Empty Section", ["An Empty Section"]),
    TestQuery("A Section With Only A Code Block", ["A Section With Only A Code Block"]),
    TestQuery("function foo()", ["Structural Cases"]),
]

markdown_syntax_queries = [
    TestQuery("Deeply nested lists", ["Markdown Syntax"]),
    TestQuery("complex to parse correctly", ["Markdown Syntax"]),
    TestQuery("blockquote with nested blockquotes", String[]),
]

common_words_queries = [
    TestQuery("function struct end", ["Structural Cases", "Common Words"]),
]

autodocs_queries = [
    TestQuery("Documenter", ["Structural Cases"]),
    TestQuery("makedocs", String[]),
    TestQuery("func1", ["Main.DummyModule.func1", "Main.DummyModule.func2"]),
    TestQuery("func2", ["Main.DummyModule.func2", "Main.DummyModule.func1"]),
    TestQuery("MyType", ["Main.DummyModule.MyType"]),
    TestQuery("docstring for func1", ["Main.DummyModule.func1", "Main.DummyModule.func2"]),
    TestQuery("docstring for func2", ["Main.DummyModule.func2", "Main.DummyModule.func1"]),
]

cross_references_queries = [
    TestQuery("link to the welcome page", ["Cross_references"]),
    TestQuery("cross-referencing syntax", ["Cross_references"]),
]

doctests_queries = [
    TestQuery("jldoctest", String[]),
    TestQuery("1 + 1", ["An Empty Section", "A Section With Only A Title", "Cross-references", "A Section With Only A Code Block", "Cross-References"]),
]


tables_queries = [
    TestQuery("table rendering", ["Tables"]),
    TestQuery("cell content A", ["Tables"]),
    TestQuery("cell content B", ["Tables"]),
    TestQuery("cell content C", ["Tables"]),
    TestQuery("1", ["Tables", "Doctests"]),
    TestQuery("2", ["Tables", "Doctests"]),
    TestQuery("3", ["Tables", "Doctests"]),
    TestQuery("4", ["Tables"]),
    TestQuery("5", ["Tables", "Doctests"]),
    TestQuery("6", ["Tables"]),
    # Test that markdown table syntax doesn't return search results
    TestQuery("|---|---|---|", String[]),
    TestQuery("| A | B | C |", String[]),
    TestQuery("|", String[]),
    TestQuery("---", String[]),
]

all_edge_case_queries = vcat(atypical_content_queries, structural_cases_queries, markdown_syntax_queries, common_words_queries, autodocs_queries, cross_references_queries, doctests_queries, tables_queries)
