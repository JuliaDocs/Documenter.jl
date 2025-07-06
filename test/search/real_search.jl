using JSON

# Load the real search index from test examples (already built!)
function load_real_search_index()
    # Use the example search index that's already built and tested
    search_index_path = joinpath(@__DIR__, "../../docs/build/search_index.js")

    if !isfile(search_index_path)
        error("Search index not found at: $search_index_path")
    end

    # Read and parse the JavaScript file
    content = read(search_index_path, String)

    # Find the JSON data after "var documenterSearchIndex = "
    json_start = findfirst("var documenterSearchIndex = ", content)
    if json_start === nothing
        error("Invalid search index format: missing variable declaration")
    end

    # Extract JSON content (everything after the variable declaration)
    json_content = content[(last(json_start) + 1):end]

    # Parse the JSON
    parsed = JSON.parse(json_content)
    return parsed["docs"]  # Return just the docs array
end

# Simple function that uses the existing search.js with real search data
function real_search(query::String)
    # Load the real search index automatically
    search_index_data = load_real_search_index()

    # Read the JS wrapper and inject data
    wrapper_js = read(joinpath(@__DIR__, "wrapper.js"), String)
    wrapper_js = replace(wrapper_js, "__SEARCH_INDEX__" => JSON.json(search_index_data))
    wrapper_js = replace(wrapper_js, "__QUERY__" => "\"" * query * "\"")


    # Write the wrapper to a temporary file and run it
    return mktemp(@__DIR__) do path, io
        write(io, wrapper_js)
        close(io)
        cd(@__DIR__) do
            result = read(`node $path`, String)
            return JSON.parse(strip(result))
        end
    end
end
