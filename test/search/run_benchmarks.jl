using Statistics
using Dates
using PrettyTables

include("test_queries.jl")
include("evaluate.jl")
include("real_search.jl")

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
    pretty_table(io, summary_data, header=["Metric", "Value"]; alignment=:l) 

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
        detailed_data[i, 8] = string(result.expected)
        detailed_data[i, 9] = string(result.actual)
    end
    pretty_table(io, detailed_data, header=["Query", "Precision (%)", "Recall (%)", "F1 (%)", "Relevant Found", "Total Retrieved", "Total Relevant", "Expected", "Actual"]; alignment=:l)
    return
end

function run_benchmarks()
    println("Running search benchmarks...")

    # Test basic queries
    basic_results = evaluate_all(real_search, basic_queries)

    # Test feature queries
    feature_results = evaluate_all(real_search, feature_queries)

    # Test edge cases
    edge_results = evaluate_all(real_search, edge_case_queries)

    # Overall results
    all_results = evaluate_all(real_search, all_test_queries)

    # Show only overall results in terminal
    println("\n== Overall Results ==")
    summary_data = [
        string("Average Precision")  string(round(all_results.average_precision * 100, digits = 1));
        string("Average Recall")     string(round(all_results.average_recall * 100, digits = 1));
        string("Average F1 Score")   string(round(all_results.average_f1_score * 100, digits = 1));
        string("Total Relevant Found") string(all_results.total_relevant_found);
        string("Total Documents Retrieved") string(all_results.total_documents_retrieved);
        string("Total Relevant Documents") string(all_results.total_relevant_documents)
    ]
    pretty_table(summary_data, header=["Metric", "Value"]; alignment=:l, 
    header_crayon=crayon"bold blue") 

    # Write detailed results to file
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    results_file = "search_benchmark_results_$(timestamp).txt"

    open(results_file, "w") do io
        println(io, "Search Benchmark Results - $(timestamp)")
        write_detailed_results(basic_results, "Basic Queries", io)
        write_detailed_results(feature_results, "Feature Queries", io)
        write_detailed_results(edge_results, "Edge Case Queries", io)
        write_detailed_results(all_results, "Overall Results", io)
    end

    println("\nDetailed results have been written to: $results_file")

    return all_results
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmarks()
end
