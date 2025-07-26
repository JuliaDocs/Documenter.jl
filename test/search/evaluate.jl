# Represents the evaluation results for a single search query
struct QueryResult
    query::String
    precision::Float64
    recall::Float64
    f1::Float64
    expected::Vector{String}
    actual::Vector{String}
    # Raw integer values used in calculations
    relevant_count::Int  # Number of relevant documents found
    total_retrieved::Int  # Total number of documents retrieved
    total_relevant::Int   # Total number of relevant documents
end

# Aggregates evaluation results across multiple search queries
struct EvaluationResults
    individual_results::Vector{QueryResult}
    average_precision::Float64
    average_recall::Float64
    average_f1_score::Float64
    # Raw integer values for overall evaluation
    total_relevant_found::Int    # Total number of relevant documents found across all queries
    total_documents_retrieved::Int  # Total number of documents retrieved across all queries
    total_relevant_documents::Int   # Total number of relevant documents across all queries
end

# Calculates precision for search results against expected documents
# Precision = (relevant documents found) / (total documents retrieved)
# Returns precision score, count of relevant documents found, and total documents retrieved
function calculate_precision(results, expected_docs)
    if isempty(results)
        return 0.0, 0, 0
    end

    relevant_count = length(intersect(results, expected_docs))
    total_retrieved = length(results)

    return relevant_count / total_retrieved, relevant_count, total_retrieved
end

# Calculates recall for search results against expected documents
# Recall = (relevant documents found) / (total relevant documents)
# Measures completeness of the search results - how many of the relevant documents were found
# Returns recall score, count of relevant documents found, and total relevant documents
function calculate_recall(results, expected_docs)
    if isempty(expected_docs)
        return 1.0, 0, 0
    end

    found_count = length(intersect(results, expected_docs))
    total_relevant = length(expected_docs)

    return found_count / total_relevant, found_count, total_relevant
end

# Calculates F1 score from precision and recall values
# F1 = 2 * (precision * recall) / (precision + recall)
# Combines precision and recall into a single score, giving equal weight to both metrics
# Returns 0.0 if both precision and recall are 0
function calculate_f1(precision, recall)
    if precision + recall == 0
        return 0.0
    end

    return 2 * (precision * recall) / (precision + recall)
end

# Evaluates a single search query using the provided search function
# Returns a QueryResult containing precision, recall, and F1 metrics
function evaluate_query(search_function, query::TestQuery, search_index_path::String)
    results = search_function(query.query, search_index_path)

    precision, relevant_count, total_retrieved = calculate_precision(results, query.expected_docs)
    recall, found_count, total_relevant = calculate_recall(results, query.expected_docs)
    f1 = calculate_f1(precision, recall)

    return QueryResult(
        query.query,
        precision,
        recall,
        f1,
        query.expected_docs,
        results,
        relevant_count,
        total_retrieved,
        total_relevant
    )
end

# Evaluates multiple search queries and aggregates the results
# Returns an EvaluationResults containing average metrics across all queries
function evaluate_all(search_function, queries, search_index_path::String)
    results = [evaluate_query(search_function, q, search_index_path) for q in queries]

    avg_precision = mean([r.precision for r in results])
    avg_recall = mean([r.recall for r in results])
    avg_f1 = mean([r.f1 for r in results])

    # Calculate total raw values across all queries
    total_relevant_found = sum(r.relevant_count for r in results)
    total_documents_retrieved = sum(r.total_retrieved for r in results)
    total_relevant_documents = sum(r.total_relevant for r in results)

    return EvaluationResults(
        results,
        avg_precision,
        avg_recall,
        avg_f1,
        total_relevant_found,
        total_documents_retrieved,
        total_relevant_documents
    )
end