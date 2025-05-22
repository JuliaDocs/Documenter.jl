struct TestQuery
    query::String
    expected_docs::Vector{String}
end

# Basic Queries
basic_queries = [
    TestQuery(
        "function",
        ["functions.html", "methods.html"]
    ),
    TestQuery(
        "array",
        ["arrays.html"]
    )
]

# Julia specific queries
julia_syntax_queries = [
    TestQuery(
        "^",
        ["math.html", "operators.html"]
    ),
    TestQuery(
        "...",
        ["arrays.html", "iterators.html"]
    )
]

all_test_queries = vcat(basic_queries, julia_syntax_queries)