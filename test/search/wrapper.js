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

const searchIndex = __SEARCH_INDEX__;
const data = searchIndex.map((x, key) => ({ ...x, id: key }));

const index = new MiniSearch({
    fields: ["title", "text"],
    storeFields: ["location", "title", "text", "category", "page"],
    processTerm: (term) => {
        let word = stopWords.has(term) ? null : term;
        if (word) {
          // custom trimmer that doesn't strip (@,!,+, -, *,/,^,&, |, %,<, >, =, :, .) which are used in julia macro,function names and identifiers
          word = word
            .replace(/^[^a-zA-Z0-9@!+\-/*^&%|<>._=:]+/, "")
            .replace(/[^a-zA-Z0-9@!+\-/*^&%|<>._=:]+$/, "");
  
          word = word.toLowerCase();
        }
  
        return word ?? null;
    },
    tokenize: (string) => {
        const tokens = [];
        let remaining = string;
  
        // julia specific patterns
        const patterns = [
          // Module qualified names (e.g., Base.sort, Module.Submodule. function)
          /\b[A-Za-z0-9_1*(?:\.[A-Z][A-Za-z0-9_1*)*\.[a-z_][A-Za-z0-9_!]*\b/g,
          // Macro calls (e.g., @time, @async)
          /@[A-Za-z0-9_]*/g,
          // Type parameters (e.g., Array{T,N}, Vector{Int})
          /\b[A-Za-z0-9_]*\{[^}]+\}/g,
          // Function names with module qualification (e.g., Base.+, Base.:^)
          /\b[A-Za-z0-9_]*\.:[A-Za-z0-9_!+\-*/^&|%<>=.]+/g,
          // Operators as complete tokens (e.g., !=, aã, ||, ^, .=, →)
          /[!<>=+\-*/^&|%:.]+/g,
          // Function signatures with type annotations (e.g., f(x::Int))
          /\b[A-Za-z0-9_!]*\([^)]*::[^)]*\)/g,
          // Numbers (integers, floats,scientific notation)
          /\b\d+(?:\.\d+)? (?:[eE][+-]?\d+)?\b/g,
        ];
  
        // apply patterns in order of specificity
        for (const pattern of patterns) {
          pattern.lastIndex = 0; //reset regex state
          let match;
          while ((match = pattern.exec(remaining)) != null) {
            const token = match[0].trim();
            if (token && !tokens.includes(token)) {
              tokens.push(token);
            }
          }
        }
  
        // splitting the content if something remains
        const basicTokens = remaining
          .split(/[\s\-,;()[\]{}]+/)
          .filter((t) => t.trim());
        for (const token of basicTokens) {
          if (token && !tokens.includes(token)) {
            tokens.push(token);
          }
        }
  
        return tokens.filter((token) => token.length > 0);
    },
    searchOptions: { prefix: true, boost: { title: 100 }, fuzzy: 2 }
});

index.addAll(data);

const results = index.search(__QUERY__, {
    filter: (result) => result.score >= 1,
    combineWith: "AND"
});

// Extract unique page names from results (same logic as search.js)
const pages = [...new Set(results.map(r => r.title))];
console.log(JSON.stringify(pages.slice(0,5))); 