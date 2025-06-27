using Statistics
using Dates

include("test_queries.jl")
include("evaluate.jl")
include("real_search.jl")

function write_detailed_results(results::EvaluationResults, category::String, io::IO)
    println(io, "\n== $category ==")
    println(io, "Average Precision: $(round(results.average_precision * 100, digits = 1))%")
    println(io, "Average Recall: $(round(results.average_recall * 100, digits = 1))%")
    println(io, "Average F1 Score: $(round(results.average_f1_score * 100, digits = 1))%")
    println(io, "Total Relevant Found: $(results.total_relevant_found)")
    println(io, "Total Documents Retrieved: $(results.total_documents_retrieved)")
    println(io, "Total Relevant Documents: $(results.total_relevant_documents)")

    println(io, "\nDetailed Results:")
    for result in results.individual_results
        println(io, "\nQuery: '$(result.query)'")
        println(io, "  Precision: $(round(result.precision * 100, digits = 1))%")
        println(io, "  Recall: $(round(result.recall * 100, digits = 1))%")
        println(io, "  F1 Score: $(round(result.f1 * 100, digits = 1))%")
        println(io, "  Relevant Found: $(result.relevant_count)")
        println(io, "  Total Retrieved: $(result.total_retrieved)")
        println(io, "  Total Relevant: $(result.total_relevant)")
        println(io, "  Expected: $(result.expected)")
        println(io, "  Actual: $(result.actual)")
    end
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
    println("Average Precision: $(round(all_results.average_precision * 100, digits = 1))%")
    println("Average Recall: $(round(all_results.average_recall * 100, digits = 1))%")
    println("Average F1 Score: $(round(all_results.average_f1_score * 100, digits = 1))%")
    println("Total Relevant Found: $(all_results.total_relevant_found)")
    println("Total Documents Retrieved: $(all_results.total_documents_retrieved)")
    println("Total Relevant Documents: $(all_results.total_relevant_documents)")

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
