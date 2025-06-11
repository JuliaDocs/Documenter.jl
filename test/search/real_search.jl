using JSON

# Load the real search index from test examples (already built!)
function load_real_search_index()
    # Use the example search index that's already built and tested
    search_index_path = joinpath(@__DIR__, "../examples/builds/html/search_index.js")
    
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
    json_content = content[last(json_start) + 1:end]
    
    # Parse the JSON
    parsed = JSON.parse(json_content)
    return parsed["docs"]  # Return just the docs array
end

# Simple function that uses the existing search.js with real search data
function real_search(query::String)
    # Load the real search index automatically
    search_index_data = load_real_search_index()
    
    # Create a Node.js script that recreates the search logic from search.js
    wrapper_js = """
    const MiniSearch = require('minisearch');
    
    // Same configuration as search.js
    const stopWords = new Set([
        "a", "able", "about", "across", "after", "almost", "also", "am", "among", "an", "and", "are", "as", "at",
        "be", "because", "been", "but", "by", "can", "cannot", "could", "dear", "did", "does", "either", "ever",
        "every", "from", "got", "had", "has", "have", "he", "her", "hers", "him", "his", "how", "however", "i",
        "if", "into", "it", "its", "just", "least", "like", "likely", "may", "me", "might", "most", "must", "my",
        "neither", "no", "nor", "not", "of", "off", "often", "on", "or", "other", "our", "own", "rather", "said",
        "say", "says", "she", "should", "since", "so", "some", "than", "that", "the", "their", "them", "then",
        "there", "these", "they", "this", "tis", "to", "too", "twas", "us", "wants", "was", "we", "were", "what",
        "when", "who", "whom", "why", "will", "would", "yet", "you", "your"
    ]);
    
    const searchIndex = $(JSON.json(search_index_data));
    const data = searchIndex.map((x, key) => ({ ...x, id: key }));
    
    const index = new MiniSearch({
        fields: ["title", "text"],
        storeFields: ["location", "title", "text", "category", "page"],
        processTerm: (term) => {
            let word = stopWords.has(term) ? null : term;
            if (word) {
                word = word.replace(/^[^a-zA-Z0-9@!]+/, "").replace(/[^a-zA-Z0-9@!]+\$/, "");
                word = word.toLowerCase();
            }
            return word ?? null;
        },
        tokenize: (string) => string.split(/[\\s\\-\\.]+/),
        searchOptions: { prefix: true, boost: { title: 100 }, fuzzy: 2 }
    });
    
    index.addAll(data);
    
    const results = index.search("$query", {
        filter: (result) => result.score >= 1,
        combineWith: "AND"
    });
    
    // Extract unique page names from results (same logic as search.js)
    const pages = [...new Set(results.map(r => r.page))];
    console.log(JSON.stringify(pages));
    """;
    
    # Ensure minisearch is available
    node_modules_path = joinpath(@__DIR__, "node_modules")
    if !isdir(node_modules_path)
        cd(@__DIR__) do
            run(`npm install minisearch`)
        end
    end
    
    # Run the wrapper
    result = read(`node -e $wrapper_js`, String)
    return JSON.parse(strip(result))
end