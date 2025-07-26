using Statistics
using Dates
using PrettyTables
using Crayons
using JSON

include(joinpath(@__DIR__, "test_queries.jl"))
include(joinpath(@__DIR__, "edge_case_queries.jl"))
include(joinpath(@__DIR__, "evaluate.jl"))
include(joinpath(@__DIR__, "real_search.jl"))

# Function to load reference benchmark values
function load_reference_values()
    reference_file = joinpath(@__DIR__, "search_benchmark_reference.json")
    if isfile(reference_file)
        return JSON.parsefile(reference_file)
    else
        return Dict()
    end
end

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

function run_benchmarks(search_index_path::String, overall_queries_name::String)
    println("Running search benchmarks...")

    # Load reference values
    reference_values = load_reference_values()

    # Test navigational queries
    navigational_results = evaluate_all(real_search, navigational_queries, search_index_path)

    # Test informational queries
    informational_results = evaluate_all(real_search, informational_queries, search_index_path)

    # Test api lookup cases
    api_lookup_results = evaluate_all(real_search, api_lookup_queries, search_index_path)

    # Test edge case cases
    edge_case_results = evaluate_all(real_search, edge_case_queries, search_index_path)

    # Test special symbol cases
    special_symbol_results = evaluate_all(real_search, special_symbol_queries, search_index_path)

    # Test dedicated edge cases
    dedicated_edge_case_results = evaluate_all(real_search, edge_case_queries, search_index_path)

    # Overall results
    overall_queries = getfield(Main, Symbol(overall_queries_name))
    all_results = evaluate_all(real_search, overall_queries, search_index_path)

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

    # Calculate differences from reference values
    precision_ref = get(reference_values, "average_precision", 0.0)
    recall_ref = get(reference_values, "average_recall", 0.0)
    f1_ref = get(reference_values, "average_f1_score", 0.0)

    precision_diff = precision_val - precision_ref
    recall_diff = recall_val - recall_ref
    f1_diff = f1_val - f1_ref

    # Function to get color for differences
    function get_color_for_diff(diff)
        if diff > 0
            return crayon"green"
        elseif diff < 0
            return crayon"red"
        else
            return crayon"default"
        end
    end

    summary_data = [
        "Average Precision" precision_val precision_ref string(round(precision_diff, digits = 1));
        "Average Recall" recall_val recall_ref string(round(recall_diff, digits = 1));
        "Average F1 Score" f1_val f1_ref string(round(f1_diff, digits = 1));
        "Total Relevant Found" all_results.total_relevant_found "" "";
        "Total Documents Retrieved" all_results.total_documents_retrieved "" "";
        "Total Relevant Documents" all_results.total_relevant_documents "" ""
    ]

    # Create highlighters for each percentage metric
    precision_highlighter = Highlighter((data, i, j) -> i == 1 && j == 2, get_color_for_percentage(precision_val))
    recall_highlighter = Highlighter((data, i, j) -> i == 2 && j == 2, get_color_for_percentage(recall_val))
    f1_highlighter = Highlighter((data, i, j) -> i == 3 && j == 2, get_color_for_percentage(f1_val))
    diff_highlighter = Highlighter(
        (data, i, j) -> j == 4 && i in 1:3,
        (data, i, j) -> get_color_for_diff(parse(Float64, data[i, 4]))
    )

    pretty_table(
        summary_data, header = ["Metric", "Value", "Reference", "Diff"], alignment = :l,
        header_crayon = crayon"bold blue",
        highlighters = (
            precision_highlighter,
            recall_highlighter,
            f1_highlighter,
            Highlighter((data, i, j) -> j == 4 && i in 1:3, get_color_for_diff(parse(Float64, summary_data[1, 4]))),
            Highlighter((data, i, j) -> j == 4 && i in 1:3, get_color_for_diff(parse(Float64, summary_data[2, 4]))),
            Highlighter((data, i, j) -> j == 4 && i in 1:3, get_color_for_diff(parse(Float64, summary_data[3, 4]))),
        )
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
        write_detailed_results(dedicated_edge_case_results, "Dedicated Edge Case Queries", io)
        write_detailed_results(all_results, "Overall Results", io)
    end

    println("\nDetailed results have been written to: $results_file")

    return all_results
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) != 2
        println("Usage: julia run_benchmarks.jl <path_to_search_index.js> <overall_queries_name>")
        exit(1)
    end
    search_index_path = ARGS[1]
    overall_queries_name = ARGS[2]
    run_benchmarks(search_index_path, overall_queries_name)
end
