println("Running benchmarks for test_queries.jl...")
run(`julia $(@__DIR__)/run_benchmarks.jl $(@__DIR__)/../../docs/build/search_index.js $(@__DIR__)/test_queries.jl all_test_queries`)

println("Running benchmarks for edge_case_queries.jl...")
run(`julia $(@__DIR__)/run_benchmarks.jl $(@__DIR__)/../search_edge_cases/build/search_index.js $(@__DIR__)/edge_case_queries.jl all_edge_case_queries`)
