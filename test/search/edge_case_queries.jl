
struct TestQuery
    query::String
    expected_docs::Vector{String}
end

atypical_content_queries = [
    TestQuery("α β γ", ["atypical_content.md"]),
    TestQuery("🚀", ["atypical_content.md"]),
    TestQuery("averylongunbrokenstringofcharacterstotestthesearchindex", ["atypical_content.md"]),
    TestQuery("мир", ["atypical_content.md"]),
]

structural_cases_queries = [
    TestQuery("An Empty Section", ["structural_cases.md"]),
    TestQuery("A Section With Only A Code Block", ["structural_cases.md"]),
    TestQuery("function foo()", ["structural_cases.md"]),
]

markdown_syntax_queries = [
    TestQuery("Deeply nested lists", ["markdown_syntax.md"]),
    TestQuery("complex to parse correctly", ["markdown_syntax.md"]),
    TestQuery("blockquote with nested blockquotes", ["markdown_syntax.md"]),
]

common_words_queries = [
    TestQuery("function struct end", ["common_words.md"]),
]

autodocs_queries = [
    TestQuery("Documenter", ["autodocs.md"]),
    TestQuery("makedocs", ["autodocs.md"]),
    TestQuery("func1", ["autodocs.md"]),
    TestQuery("func2", ["autodocs.md"]),
    TestQuery("MyType", ["autodocs.md"]),
    TestQuery("docstring for func1", ["autodocs.md"]),
    TestQuery("docstring for func2", ["autodocs.md"]),
]

cross_references_queries = [
    TestQuery("link to the welcome page", ["cross_references.md"]),
    TestQuery("cross-referencing syntax", ["cross_references.md"]),
]

doctests_queries = [
    TestQuery("jldoctest", ["doctests.md"]),
    TestQuery("1 + 1", ["doctests.md"]),
]


tables_queries = [
    TestQuery("table rendering", ["tables.md"]),
    TestQuery("| A | B | C |", ["tables.md"]),
    TestQuery("|---|---|---|", ["tables.md"]),
    TestQuery("| 1 | 2 | 3 |", ["tables.md"]),
]

all_edge_case_queries = vcat(atypical_content_queries, structural_cases_queries, markdown_syntax_queries, common_words_queries, autodocs_queries, cross_references_queries, doctests_queries, tables_queries)