println("Running all benchmarks...")

println("\nRunning benchmarks for default search index...")
run(`julia $(@__DIR__)/run_benchmarks.jl $(@__DIR__)/../../docs/build/search_index.js all_test_queries`)

println("\nRunning benchmarks for edge case search index...")
run(`julia $(@__DIR__)/run_benchmarks.jl $(@__DIR__)/../search_edge_cases/build/search_index.js edge_case_queries`)

println("\nAll benchmarks complete.")