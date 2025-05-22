function calculate_precision(results, expected_docs)
    if isempty(results)
        return 0.0
    end

    relevant_count = length(intersect(results, expected_docs))

    return relevant_count / length(results)
end

function calculate_recall(results, expected_docs)
    if isempty(expected_docs)
        return 1.0
    end

    found_count = length(intersect(results, expected_docs))

    return found_count / length(expected_docs)
end

function calculate_f1(precision, recall)
    if precision + recall == 0
        return 0.0
    end

    return 2 * (precision * recall) / (precision + recall)
end

function evaluate_query(search_function, query::TestQuery)
    results = search_function(query.query)

    precision = calculate_precision(results, query.expected_docs)
    recall = calculate_recall(results, query.expected_docs)
    f1 = calculate_f1(precision, recall)

    return Dict(
        "query" => query.query,
        "precision" => precision,
        "recall" => recall,
        "f1" => f1,
        "expected" => query.expected_docs,
        "actual" => results
    )
end

function evaluate_all(search_function, queries)
    results = [evaluate_query(search_function, q) for q in queries]

    avg_precision = mean([r["precision"] for r in results])
    avg_recall = mean([r["recall"] for r in results])
    avg_f1 = mean([r["f1"] for r in results])

    return Dict(
        "individual_results" => results,
        "average_precision" => avg_precision,
        "average_recall" => avg_recall,
        "average_f1_score" => avg_f1
    )
end
