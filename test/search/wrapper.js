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
            word = word.replace(/^[^a-zA-Z0-9@!]+/, "").replace(/[^a-zA-Z0-9@!]+$/, "");
            word = word.toLowerCase();
        }
        return word ?? null;
    },
    tokenize: (string) => string.split(/[\s\-\.]+/),
    searchOptions: { prefix: true, boost: { title: 100 }, fuzzy: 2 }
});

index.addAll(data);

const results = index.search(__QUERY__, {
    filter: (result) => result.score >= 1,
    combineWith: "AND"
});

// Extract unique page names from results (same logic as search.js)
const pages = [...new Set(results.map(r => r.page))];
console.log(JSON.stringify(pages)); 