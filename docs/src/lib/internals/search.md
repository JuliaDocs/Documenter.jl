# Search 

## Overview

The search system provides full-text search functionality for documentation sites through a two-phase architecture. 
During build time, a Julia-based indexer processes all documentation content and generates a searchable index. 
At runtime, a JavaScript client-side interface performs real-time search operations against this pre-built index using a Web Worker for performance optimization.

## Architecture

The search implementation consists of three primary components operating in sequence:

1. **Build-time Index Generation** - Julia code in `src/html/HTMLWriter.jl` processes documentation content during site generation.
2. **Client-side Search Interface** - JavaScript code in `assets/html/js/search.js` handles user interactions and search execution. 
3. **Web Worker Processing** - Background thread execution prevents UI blocking during search operations.

## Index Generation Process

### 1. SearchRecord Structure

The core data structure is the `SearchRecord` struct defined in `src/html/HTMLWriter.jl`:

```julia
struct SearchRecord
    src::String          # URL/path to the document
    page::Documenter.Page # Reference to the page object
    fragment::String     # URL fragment (for anchored content)
    category::String     # Content category (page, section, docstring, etc.)
    title::String        # Display title for search results
    page_title::String   # Title of the containing page
    text::String         # Searchable text content
end
```

### 2. Index Generation Pipeline

The indexer processes documentation content through a multi-stage pipeline during HTML generation:

1. **AST Traversal** - The system walks each page's markdown abstract syntax tree structure at `src/html/HTMLWriter.jl` in the function `function domify(dctx::DCtx)`
2. **Record Instantiation** - Each content node generates a `SearchRecord` via the `searchrecord()` function at `src/html/HTMLWriter.jl`
3. **Content Classification** - The categorization system assigns content types
4. **Text Normalization** - The `mdflatten()` function extracts plain text from markdown structures for indexing.
5. **Deduplication Pass** - Records sharing identical locations undergo merging to optimize index size.
6. **JavaScript Serialization** - The processed index outputs as JavaScript object notation for client consumption.

### 3. Index Output

The search index is written to `search_index.js` in the following format:

```javascript
var documenterSearchIndex = {"docs": [
  {
    "location": "page.html#fragment",
    "page": "Page Title", 
    "title": "Content Title",
    "category": "section",
    "text": "Searchable content text..."
  }
  // ... more records
]}
```

### 4. Content Filtering

The indexer excludes specific node types from search index generation (`src/html/HTMLWriter.jl`):
- `MetaNode` - Metadata annotation blocks containing non-searchable directives
- `DocsNodesBlock` - Internal documentation node structures  
- `SetupNode` - Configuration and setup directive blocks

## Client-Side Search Implementation

### 1. Search Architecture

The client-side implementation employs a multi-threaded Web Worker architecture for computational isolation:

- **Main Thread** - Manages user interface event handling, result filtering, and DOM manipulation operations
- **Web Worker Thread** - Executes search algorithms using the MiniSearch library without blocking the user interface

### 2. MiniSearch Configuration

The search system uses MiniSearch with the following configuration (`assets/html/js/search.js`):

```javascript
let index = new MiniSearch({
  fields: ["title", "text"],           // Fields to index
  storeFields: ["location", "title", "text", "category", "page"], // Fields to return
  processTerm: (term) => {
    // Custom term processing with stop words removal
    // Preserves Julia-specific symbols (@, !)
  },
  tokenize: (string) => string.split(/[\s\-\.]+/), // Custom tokenizer
  searchOptions: {
    prefix: true,       // Enable prefix matching
    boost: { title: 100 }, // Boost title matches
    fuzzy: 2           // Enable fuzzy matching
  }
});
```

### 3. Stop Words

The search engine implements a stop words filter (`assets/html/js/search.js`) derived from the Lunr 2.1.3 library, with Julia-language-specific modifications that preserve semantically important Julia symbols and keywords from filtration.

### 4. Search Workflow

#### Main Thread Execution Flow:
1. **Input Event Processing** - User keystrokes in search input trigger `input` event listeners
2. **Worker Thread Communication** - Available worker threads receive search requests via `postMessage` API
3. **Result Set Processing** - Worker thread responses undergo filtering and DOM rendering
4. **Browser State Management** - Search queries and active filters update browser URL parameters

#### Web Worker Execution Flow:
1. **Query Reception** - Main thread search requests arrive through message passing interface
2. **Search Algorithm Execution** - MiniSearch performs full-text search with minimum score threshold of 1
3. **Result Set Generation** - Search matches generate HTML markup limited to 200 results per content category
4. **Response Transmission** - Formatted search results return to main thread via message passing

### 5. Result Rendering

The search result rendering system generates structured output elements (`assets/html/js/search.js`):
- **Title Component** - Content titles with syntax highlighting and category classification badges
- **Text Snippet Component** - Extracted text excerpts with search term highlighting via HTML markup
- **Navigation Link Component** - Direct URL references to specific content locations within documentation
- **Context Metadata Component** - Hierarchical page information and document location path data

### 6. Content Filtering System

The search interface implements dynamic category-based result filtering:
- Filter options generate automatically from indexed content categories
- User filtering operates on content type classifications (page, section, docstring, etc.)
- Client-side filtering execution provides immediate response without server requests

## Performance Optimizations

### 1. Web Worker Usage
- Offloads search computation from main thread
- Maintains UI responsiveness during search operations
- Handles concurrent search requests efficiently

### 2. Result Limiting
- Pre-filters to 200 unique results per category
- Prevents excessive DOM manipulation
- Reduces memory usage for large documentation sites

### 3. Index Deduplication
- Merges duplicate entries at build time
- Reduces index size and network transfer
- Improves search performance

### 4. Progressive Loading
- Search index loads asynchronously
- Fallback handling for missing dependencies
- Graceful degradation without search functionality

## Configuration Options

### Build-Time Settings

```julia
# In make.jl
makedocs(
    # ... other options
    format = Documenter.HTML(
        # Search-related settings
        search_size_threshold_warn = 200_000  # Warn if index > 200KB
    )
)
```

### Size Thresholds
- Warning threshold: 200KB by default
- Large indices may impact page load performance
- Automatic warnings during build process

## Integration Points

### 1. Asset Management
- Search JavaScript is bundled with other Documenter assets
- MiniSearch library loaded from CDN (`__MINISEARCH_VERSION__` placeholder)
- Dependencies managed through `JSDependencies.jl`

### 2. Theme Integration  
- Search UI styled using Bulma CSS framework
- Responsive design for mobile devices
- Dark/light theme support

### 3. URL Routing
- Search queries persist in URL parameters (`?q=search_term`)
- Filter states maintained in URL (`?filter=section`)
- Browser history integration for navigation

## Testing and Benchmarking

### 1. Test Infrastructure
- Real search testing: `test/search/real_search.jl`
- Benchmark suite: `test/search/run_benchmarks.jl`
- Edge case testing: `test/search_edge_cases/`

### 2. Search Validation
The testing system provides:
- Index generation validation
- Search result accuracy verification  
- Performance benchmarking capabilities
- Edge case handling verification


