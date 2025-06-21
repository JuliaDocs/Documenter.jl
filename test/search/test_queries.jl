struct TestQuery
    query::String
    expected_docs::Vector{String}
end

# Basic page queries - searching for content that actually exists
basic_queries = [
    TestQuery(
        "tutorial",
        ["Tutorial"]  # Tutorial page exists in search index
    ),
    TestQuery(
        "function",
        ["Function Index"]  # Function Index page exists
    ),
    TestQuery(
        "latex",
        ["LaTeX MWEs"]  # LaTeX MWEs page exists  
    ),
    TestQuery(
        "unicode",
        ["Unicode"]  # Unicode page exists
    )
]

# Function/API queries - searching for actual documented functions
function_queries = [
    TestQuery(
        "func",
        ["Home"]  # Main.Mod.func(x) is documented on Home page
    ),
    TestQuery(
        "autodocs", 
        ["@autodocs tests"]  # AutoDocs functionality
    ),
    TestQuery(
        "repl",
        ["@repl, @example, and @eval have correct LineNumberNodes inserted"]
    ),
    TestQuery(
        "f_1",
        ["@autodocs tests"]  # f_1 function in AutoDocs
    )
]

# Content feature queries - searching for actual documented features
feature_queries = [
    TestQuery(
        "cross reference",
        ["Cross-references"]  # Cross-references page
    ),
    TestQuery(
        "hidden",
        ["Hidden Pages"]  # Hidden pages functionality
    ),
    TestQuery(
        "style",
        ["Style demos"]  # Style demonstrations
    ),
    TestQuery(
        "font",
        ["Font demo"]  # Font demo page
    )
]

# Edge cases - realistic edge cases based on actual content
edge_case_queries = [
    TestQuery(
        "nonexistentthing",
        String[]  # Should return empty
    ),
    TestQuery(
        "edit",
        ["Good EditURL", "Absolute EditURL"]  # Multiple EditURL pages
    ),
    TestQuery(
        "page",
        ["Home", "Tutorial", "Hidden Pages"]  # Common word, multiple matches
    )
]

all_test_queries = vcat(basic_queries, function_queries, feature_queries, edge_case_queries)