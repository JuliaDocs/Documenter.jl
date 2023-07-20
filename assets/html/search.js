// libraries: jquery, minisearch, lodash
// arguments: $, minisearch, _

$(function () {
  // parseUri 1.2.2
  // (c) Steven Levithan <stevenlevithan.com>
  // MIT License
  function parseUri(str) {
    var o = parseUri.options,
      m = o.parser[o.strictMode ? "strict" : "loose"].exec(str),
      uri = {},
      i = 14;

    while (i--) uri[o.key[i]] = m[i] || "";

    uri[o.q.name] = {};
    uri[o.key[12]].replace(o.q.parser, function ($0, $1, $2) {
      if ($1) uri[o.q.name][$1] = $2;
    });

    return uri;
  }
  parseUri.options = {
    strictMode: false,
    key: [
      "source",
      "protocol",
      "authority",
      "userInfo",
      "user",
      "password",
      "host",
      "port",
      "relative",
      "path",
      "directory",
      "file",
      "query",
      "anchor",
    ],
    q: {
      name: "queryKey",
      parser: /(?:^|&)([^&=]*)=?([^&]*)/g,
    },
    parser: {
      strict:
        /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
      loose:
        /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/,
    },
  };

  $("#search-form").submit(function (e) {
    e.preventDefault();
  });

  let ms_data = documenterSearchIndex["docs"].map((x, key) => {
    x["id"] = key;
    return x;
  });

  // list below is the lunr 2.1.3 list minus the intersect with names(Base)
  // (all, any, get, in, is, only, which) and (do, else, for, let, where, while, with)
  // ideally we'd just filter the original list but it's not available as a variable
  const stopWords = new Set([
    "a",
    "able",
    "about",
    "across",
    "after",
    "almost",
    "also",
    "am",
    "among",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "because",
    "been",
    "but",
    "by",
    "can",
    "cannot",
    "could",
    "dear",
    "did",
    "does",
    "either",
    "ever",
    "every",
    "from",
    "got",
    "had",
    "has",
    "have",
    "he",
    "her",
    "hers",
    "him",
    "his",
    "how",
    "however",
    "i",
    "if",
    "into",
    "it",
    "its",
    "just",
    "least",
    "like",
    "likely",
    "may",
    "me",
    "might",
    "most",
    "must",
    "my",
    "neither",
    "no",
    "nor",
    "not",
    "of",
    "off",
    "often",
    "on",
    "or",
    "other",
    "our",
    "own",
    "rather",
    "said",
    "say",
    "says",
    "she",
    "should",
    "since",
    "so",
    "some",
    "than",
    "that",
    "the",
    "their",
    "them",
    "then",
    "there",
    "these",
    "they",
    "this",
    "tis",
    "to",
    "too",
    "twas",
    "us",
    "wants",
    "was",
    "we",
    "were",
    "what",
    "when",
    "who",
    "whom",
    "why",
    "will",
    "would",
    "yet",
    "you",
    "your",
  ]);

  let index = new minisearch({
    fields: ["title", "text"], // fields to index for full-text search
    storeFields: ["location", "title", "text", "category", "page"], // fields to return with search results
    processTerm: (term) => {
      let word = stopWords.has(term) ? null : term;
      if (word) {
        // custom trimmer that doesn't strip @ and !, which are used in julia macro and function names
        word = word
          .replace(/^[^a-zA-Z0-9@!]+/, "")
          .replace(/[^a-zA-Z0-9@!]+$/, "");
      }

      return word ?? null;
    },
    // add . as a separator, because otherwise "title": "Documenter.Anchors.add!", would not find anything if searching for "add!", only for the entire qualification
    tokenize: (string) => string.split(/[\s\-\.]+/),
    searchOptions: {
      boost: { title: 100 },
      fuzzy: 2,
      processTerm: (term) => {
        let word = stopWords.has(term) ? null : term;
        if (word) {
          word = word
            .replace(/^[^a-zA-Z0-9@!]+/, "")
            .replace(/[^a-zA-Z0-9@!]+$/, "");
        }

        return word ?? null;
      },
      tokenize: (string) => string.split(/[\s\-\.]+/),
    },
  });

  index.addAll(ms_data);

  searchresults = $("#documenter-search-results");
  searchinfo = $("#documenter-search-info");
  searchbox = $("#documenter-search-query");
  searchform = $(".docs-search");
  sidebar = $(".docs-sidebar");

  function update_search(querystring) {
    let results = [];
    results = index.search(querystring, {
      filter: (result) => result.score >= 1,
    });

    searchresults.empty();

    let links = [];
    let count = 0;

    results.forEach(function (result) {
      if (result.location) {
        if (!links.includes(result.location)) {
          searchresults.append(make_search_result(result, querystring));
          count++;
        }

        links.push(result.location);
      }
    });

    searchinfo.text("Number of results: " + count);
  }

  function make_search_result(result, querystring) {
    let display_link =
      result.location.slice(Math.max(0), Math.min(50, result.location.length)) +
      (result.location.length > 30 ? "..." : "");

    let textindex = new RegExp(`\\b${querystring}\\b`, "i").exec(result.text);
    let text =
      textindex !== null
        ? result.text.slice(
            Math.max(textindex.index - 100, 0),
            Math.min(
              textindex.index + querystring.length + 100,
              result.text.length
            )
          )
        : "";

    let display_result = text.length
      ? "..." +
        text.replace(
          new RegExp(`\\b${querystring}\\b`, "i"), // For first occurrence
          '<span class="search-result-highlight p-1">$&</span>'
        ) +
        "..."
      : "";

    let result_div = `
      <a href="${
        documenterBaseURL + "/" + result.location
      }" class="search-result-link px-4 py-2 w-100 is-flex is-flex-direction-column gap-2 my-4">
        <div class="w-100 is-flex is-flex-wrap-wrap is-justify-content-space-between is-align-items-center">
          <div class="search-result-title has-text-weight-semi-bold">${
            result.title
          }</div>
          <div class="property-search-result-badge">${result.category}</div>
        </div>
        <p>
          ${display_result}
        </p>
        <div
          class="has-text-left"
          style="font-size: smaller;"
          title="${result.location}"
        >
          <i class="fas fa-link"></i> ${display_link}
        </div>
      </a>
      <div class="search-divider"></div>
    `;
    return result_div;
  }

  function update_search_box() {
    querystring = searchbox.val();
    update_search(querystring);
  }

  searchbox.keyup(_.debounce(update_search_box, 250));
  searchbox.change(update_search_box);

  // Disable enter-key form submission for the searchbox on the search page
  // and just re-run search rather than refresh the whole page.
  searchform.keypress(function (event) {
    if (event.which == "13") {
      if (sidebar.hasClass("visible")) {
        sidebar.removeClass("visible");
      }
      update_search_box();
      event.preventDefault();
    }
  });

  search_query_uri = parseUri(window.location).queryKey["q"];

  if (search_query_uri !== undefined) {
    search_query = decodeURIComponent(search_query_uri.replace(/\+/g, "%20"));
    searchbox.val(search_query);
  }

  update_search_box();
});
