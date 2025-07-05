using Statistics
using Dates
using PrettyTables
using Crayons

include(joinpath(@__DIR__, "test_queries.jl"))
include(joinpath(@__DIR__, "evaluate.jl"))
include(joinpath(@__DIR__, "real_search.jl"))

function write_detailed_results(results::EvaluationResults, category::String, io::IO)
    println(io, "\n== $category ==")
    summary_data = [
        string("Average Precision")  string(round(results.average_precision * 100, digits = 1));
        string("Average Recall")     string(round(results.average_recall * 100, digits = 1));
        string("Average F1 Score")   string(round(results.average_f1_score * 100, digits = 1));
        string("Total Relevant Found") string(results.total_relevant_found);
        string("Total Documents Retrieved") string(results.total_documents_retrieved);
        string("Total Relevant Documents") string(results.total_relevant_documents)
    ]
    pretty_table(io, summary_data, header = ["Metric", "Value"]; alignment = :l)

    println(io, "\nDetailed Results:")
    detailed_data = Matrix{String}(undef, length(results.individual_results), 9)
    for (i, result) in enumerate(results.individual_results)
        detailed_data[i, 1] = string(result.query)
        detailed_data[i, 2] = string(round(result.precision * 100, digits = 1))
        detailed_data[i, 3] = string(round(result.recall * 100, digits = 1))
        detailed_data[i, 4] = string(round(result.f1 * 100, digits = 1))
        detailed_data[i, 5] = string(result.relevant_count)
        detailed_data[i, 6] = string(result.total_retrieved)
        detailed_data[i, 7] = string(result.total_relevant)
        detailed_data[i, 8] = string(first(result.expected, 5))
        detailed_data[i, 9] = string(result.actual)
    end
    pretty_table(io, detailed_data, header = ["Query", "Precision (%)", "Recall (%)", "F1 (%)", "Relevant Found", "Total Retrieved", "Total Relevant", "Expected", "Actual"]; alignment = :l)
    return
end

function run_benchmarks()
    println("Running search benchmarks...")

    # Test navigational queries
    navigational_results = evaluate_all(real_search, navigational_queries)

    # Test informational queries
    informational_results = evaluate_all(real_search, informational_queries)

    # Test api lookup cases
    api_lookup_results = evaluate_all(real_search, api_lookup_queries)

    # Test edge case cases
    edge_case_results = evaluate_all(real_search, edge_case_queries)

    # Test special symbol cases
    special_symbol_results = evaluate_all(real_search, special_symbol_queries)


    # Overall results
    all_results = evaluate_all(real_search, all_test_queries)

    println("\n== Overall Results ==")

    # Function to get color based on percentage value
    function get_color_for_percentage(value)
        if value >= 80.0
            return crayon"green"
        elseif value >= 60.0
            return crayon"yellow"
        elseif value >= 40.0
            return crayon"red"
        else
            return crayon"bold red"
        end
    end

    # Create colored summary data
    precision_val = round(all_results.average_precision * 100, digits = 1)
    recall_val = round(all_results.average_recall * 100, digits = 1)
    f1_val = round(all_results.average_f1_score * 100, digits = 1)

    summary_data = [
        string("Average Precision")  string(precision_val);
        string("Average Recall")     string(recall_val);
        string("Average F1 Score")   string(f1_val);
        string("Total Relevant Found") string(all_results.total_relevant_found);
        string("Total Documents Retrieved") string(all_results.total_documents_retrieved);
        string("Total Relevant Documents") string(all_results.total_relevant_documents)
    ]

    # Create highlighters for each percentage metric
    precision_highlighter = Highlighter((data, i, j) -> i == 1 && j == 2, get_color_for_percentage(precision_val))
    recall_highlighter = Highlighter((data, i, j) -> i == 2 && j == 2, get_color_for_percentage(recall_val))
    f1_highlighter = Highlighter((data, i, j) -> i == 3 && j == 2, get_color_for_percentage(f1_val))

    pretty_table(
        summary_data, header = ["Metric", "Value"]; alignment = :l,
        header_crayon = crayon"bold blue", highlighters = (precision_highlighter, recall_highlighter, f1_highlighter)
    )

    # Write detailed results to file
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    results_file = joinpath(@__DIR__, "search_benchmark_results_$(timestamp).txt")

    open(results_file, "w") do io
        println(io, "Search Benchmark Results - $(timestamp)")
        write_detailed_results(navigational_results, "Navigational Queries", io)
        write_detailed_results(informational_results, "Feature Queries", io)
        write_detailed_results(api_lookup_results, "API Lookup Case Queries", io)
        write_detailed_results(edge_case_results, "Edge Case Queries", io)
        write_detailed_results(special_symbol_results, "Special Symbol Case Queries", io)
        write_detailed_results(all_results, "Overall Results", io)
    end

    println("\nDetailed results have been written to: $results_file")

    return all_results
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmarks()
end
