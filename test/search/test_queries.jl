struct TestQuery
    query::String
    expected_docs::Vector{String}
end

navigational_queries = [
    TestQuery(
        "makedocs",
        ["Documenter.makedocs", "Markdown & MkDocs", "Doctests", "Syntax", "Documenter.LatexWriter"]
    ),
    TestQuery(
        "deploydocs",
        ["Deploydocs", "The deploydocs function", "Documenter.deploydocs", "Hosting Documentation"]  
    ),  
] 

informational_queries = [
    TestQuery(
        "cross references",
        ["External Cross-References", "Guide", "Syntax", "Documenter.crossref"]  
    ),
    TestQuery(
        "hosting documentation",
        ["Hosting Documentation", "SSH Deploy Keys Walkthrough", "Documenter.xref", "Guide"]
    ), 
    TestQuery(
        "unicode",
        ["Documenter.JSDependencies.json_jsescape", "Release Notes"]  
    ),
]

api_lookup_queries = [
    TestQuery(
        "doctest",
        ["DocTestSetup and DocTestTeardown in @meta blocks", "Doctesting example", "Doctesting as Part of Testing", "Documenter.doctest", "Documenter._doctest"]  
    ),
    TestQuery(
        "@docs",
        ["@docs block", "@docs; canonical=false block", "docs/Project.toml", "Markdown & MkDocs", "Documenter.docs"]  
    ),
    TestQuery(
        "HTML themes",
        ["Documenter.HTMLWriter.HTML", "Guide", "Release Notes", "Semantic Versioning"]  
    ),
]

# Edge cases - realistic edge cases based on actual content
edge_case_queries = [
    TestQuery(
        "nonexistent function",
        String[]  # Should return empty
    ),
]

special_symbol_queries = [
    TestQuery(
        "^",
        ["Version v1.6.0 - 2024-08-20", "Version v1.9.0 - 2025-03-17", "Version v1.5.0 - 2024-06-26", "Version v1.4.0 - 2024-04-14", "Version v1.8.1 - 2025-02-11"]
    ),
    TestQuery(
        "@",
        ["@ref and @id links", "@raw <format> block", "@setup <name> block", "@docs; canonical=false block", "@eval block"]
    )

]

all_test_queries = vcat(navigational_queries, informational_queries, api_lookup_queries, edge_case_queries, special_symbol_queries)
