// libraries: jquery
// arguments: $

/*
To get an in-depth about the thought process you can refer: https://hetarth02.hashnode.dev/series/gsoc

PSEUDOCODE:

Searching happens automatically as the user types or adjusts the selected filters.
To preserve responsiveness, as much as possible of the slow parts of the search are done
in a web worker. Searching and result generation are done in the worker, and filtering and
DOM updates are done in the main thread. The filters are in the main thread as they should
be very quick to apply. This lets filters be changed without re-searching with minisearch
(which is possible even if filtering is on the worker thread) and also lets filters be
changed _while_ the worker is searching and without message passing (neither of which are
possible if filtering is on the worker thread)

SEARCH WORKER:

Import minisearch

Build index

On message from main thread
  run search
  find the first 200 unique results from each category, and compute their divs for display
    note that this is necessary and sufficient information for the main thread to find the
    first 200 unique results from any given filter set
  post results to main thread

MAIN:

Launch worker

Declare nonconstant globals (worker_is_running,  last_search_text, unfiltered_results)

On text update
  if worker is not running, launch_search()

launch_search
  set worker_is_running to true, set last_search_text to the search text
  post the search query to worker

on message from worker
  if last_search_text is not the same as the text in the search field,
    the latest search result is not reflective of the latest search query, so update again
    launch_search()
  otherwise
    set worker_is_running to false

  regardless, display the new search results to the user
  save the unfiltered_results as a global
  update_search()

on filter click
  adjust the filter selection
  update_search()

update_search
  apply search filters by looping through the unfiltered_results and finding the first 200
    unique results that match the filters

  Update the DOM
*/

/////// SEARCH WORKER ///////

function worker_function(documenterSearchIndex, documenterBaseURL, filters) {
  importScripts(
    "https://cdn.jsdelivr.net/npm/minisearch@6.1.0/dist/umd/index.min.js"
  );

  let data = documenterSearchIndex.map((x, key) => {
    x["id"] = key; // minisearch requires a unique for each object
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

  let index = new MiniSearch({
    fields: ["title", "text"], // fields to index for full-text search
    storeFields: ["location", "title", "text", "category", "page"], // fields to return with results
    processTerm: (term) => {
      let word = stopWords.has(term) ? null : term;
      if (word) {
        // custom trimmer that doesn't strip @ and !, which are used in julia macro and function names
        word = word
          .replace(/^[^a-zA-Z0-9@!]+/, "")
          .replace(/[^a-zA-Z0-9@!]+$/, "");

        word = word.toLowerCase();
      }

      return word ?? null;
    },
    // add . as a separator, because otherwise "title": "Documenter.Anchors.add!", would not
    // find anything if searching for "add!", only for the entire qualification
    tokenize: (string) => string.split(/[\s\-\.]+/),
    // options which will be applied during the search
    searchOptions: {
      prefix: true,
      boost: { title: 100 },
      fuzzy: 2,
    },
  });

  index.addAll(data);

  /**
   *  Used to map characters to HTML entities.
   * Refer: https://github.com/lodash/lodash/blob/main/src/escape.ts
   */
  const htmlEscapes = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  };

  /**
   * Used to match HTML entities and HTML characters.
   * Refer: https://github.com/lodash/lodash/blob/main/src/escape.ts
   */
  const reUnescapedHtml = /[&<>"']/g;
  const reHasUnescapedHtml = RegExp(reUnescapedHtml.source);

  /**
   * Escape function from lodash
   * Refer: https://github.com/lodash/lodash/blob/main/src/escape.ts
   */
  function escape(string) {
    return string && reHasUnescapedHtml.test(string)
      ? string.replace(reUnescapedHtml, (chr) => htmlEscapes[chr])
      : string || "";
  }

  /**
   * RegX escape function from MDN
   * Refer: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions#escaping
   */
  function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // $& means the whole matched string
  }

  /**
   * Make the result component given a minisearch result data object and the value
   * of the search input as queryString. To view the result object structure, refer:
   * https://lucaong.github.io/minisearch/modules/_minisearch_.html#searchresult
   *
   * @param {object} result
   * @param {string} querystring
   * @returns string
   */
  function make_search_result(result, querystring) {
    let search_divider = `<div class="search-divider w-100"></div>`;
    let display_link =
      result.location.slice(Math.max(0), Math.min(50, result.location.length)) +
      (result.location.length > 30 ? "..." : ""); // To cut-off the link because it messes with the overflow of the whole div

    if (result.page !== "") {
      display_link += ` (${result.page})`;
    }
    searchstring = escapeRegExp(querystring);
    let textindex = new RegExp(`${searchstring}`, "i").exec(result.text);
    let text =
      textindex !== null
        ? result.text.slice(
            Math.max(textindex.index - 100, 0),
            Math.min(
              textindex.index + querystring.length + 100,
              result.text.length
            )
          )
        : ""; // cut-off text before and after from the match

    text = text.length ? escape(text) : "";

    let display_result = text.length
      ? "..." +
        text.replace(
          new RegExp(`${escape(searchstring)}`, "i"), // For first occurrence
          '<span class="search-result-highlight py-1">$&</span>'
        ) +
        "..."
      : ""; // highlights the match

    let in_code = false;
    if (!["page", "section"].includes(result.category.toLowerCase())) {
      in_code = true;
    }

    // We encode the full url to escape some special characters which can lead to broken links
    let result_div = `
        <a href="${encodeURI(
          documenterBaseURL + "/" + result.location
        )}" class="search-result-link w-100 is-flex is-flex-direction-column gap-2 px-4 py-2">
          <div class="w-100 is-flex is-flex-wrap-wrap is-justify-content-space-between is-align-items-flex-start">
            <div class="search-result-title has-text-weight-bold ${
              in_code ? "search-result-code-title" : ""
            }">${escape(result.title)}</div>
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
        ${search_divider}
      `;

    return result_div;
  }

  self.onmessage = function (e) {
    let query = e.data;
    let results = index.search(query, {
      filter: (result) => {
        // Only return relevant results
        return result.score >= 1;
      },
      combineWith: "AND",
    });

    // Pre-filter to deduplicate and limit to 200 per category to the extent
    // possible without knowing what the filters are.
    let filtered_results = [];
    let counts = {};
    for (let filter of filters) {
      counts[filter] = 0;
    }
    let present = {};

    for (let result of results) {
      cat = result.category;
      cnt = counts[cat];
      if (cnt < 200) {
        id = cat + "---" + result.location;
        if (present[id]) {
          continue;
        }
        present[id] = true;
        filtered_results.push({
          location: result.location,
          category: cat,
          div: make_search_result(result, query),
        });
      }
    }

    postMessage(filtered_results);
  };
}

/////// SEARCH MAIN ///////

function runSearchMainCode() {
  // `worker = Threads.@spawn worker_function(documenterSearchIndex)`, but in JavaScript!
  const filters = [
    ...new Set(documenterSearchIndex["docs"].map((x) => x.category)),
  ];
  const worker_str =
    "(" +
    worker_function.toString() +
    ")(" +
    JSON.stringify(documenterSearchIndex["docs"]) +
    "," +
    JSON.stringify(documenterBaseURL) +
    "," +
    JSON.stringify(filters) +
    ")";
  const worker_blob = new Blob([worker_str], { type: "text/javascript" });
  const worker = new Worker(URL.createObjectURL(worker_blob));

  // Whether the worker is currently handling a search. This is a boolean
  // as the worker only ever handles 1 or 0 searches at a time.
  var worker_is_running = false;

  // The last search text that was sent to the worker. This is used to determine
  // if the worker should be launched again when it reports back results.
  var last_search_text = "";

  // The results of the last search. This, in combination with the state of the filters
  // in the DOM, is used compute the results to display on calls to update_search.
  var unfiltered_results = [];

  // Which filter is currently selected
  var selected_filter = "";

  document.addEventListener("reset-filter", function () {
    selected_filter = "";
    update_search();
  });

  //update the url with search query
  function updateSearchURL(query) {
    const url = new URL(window.location);

    if (query && query.trim() !== "") {
      url.searchParams.set("q", query);
    } else {
      // remove the 'q' param if it exists
      if (url.searchParams.has("q")) {
        url.searchParams.delete("q");
      }
    }

    // Add or remove the filter parameter based on selected_filter
    if (selected_filter && selected_filter.trim() !== "") {
      url.searchParams.set("filter", selected_filter);
    } else {
      // remove the 'filter' param if it exists
      if (url.searchParams.has("filter")) {
        url.searchParams.delete("filter");
      }
    }

    // Only update history if there are parameters, otherwise use the base URL
    if (url.search) {
      window.history.replaceState({}, "", url);
    } else {
      window.history.replaceState({}, "", url.pathname + url.hash);
    }
  }

  $(document).on("input", ".documenter-search-input", function (event) {
    if (!worker_is_running) {
      launch_search();
    }
  });

  function launch_search() {
    worker_is_running = true;
    last_search_text = $(".documenter-search-input").val();
    updateSearchURL(last_search_text);
    worker.postMessage(last_search_text);
  }

  worker.onmessage = function (e) {
    if (last_search_text !== $(".documenter-search-input").val()) {
      launch_search();
    } else {
      worker_is_running = false;
    }

    unfiltered_results = e.data;
    update_search();
  };

  $(document).on("click", ".search-filter", function () {
    let search_input = $(".documenter-search-input");
    let cursor_position = search_input[0].selectionStart;

    if ($(this).hasClass("search-filter-selected")) {
      selected_filter = "";
    } else {
      selected_filter = $(this).text().toLowerCase();
    }

    // This updates search results and toggles classes for UI:
    update_search();

    search_input.focus();
    search_input.setSelectionRange(cursor_position, cursor_position);
  });

  /**
   * Make/Update the search component
   */
  function update_search() {
    let querystring = $(".documenter-search-input").val();
    updateSearchURL(querystring);

    if (querystring.trim()) {
      if (selected_filter == "") {
        results = unfiltered_results;
      } else {
        results = unfiltered_results.filter((result) => {
          return selected_filter == result.category.toLowerCase();
        });
      }

      let search_result_container = ``;
      let modal_filters = make_modal_body_filters();
      let search_divider = `<div class="search-divider w-100"></div>`;

      if (results.length) {
        let links = [];
        let count = 0;
        let search_results = "";

        for (var i = 0, n = results.length; i < n && count < 200; ++i) {
          let result = results[i];
          if (result.location && !links.includes(result.location)) {
            search_results += result.div;
            count++;
            links.push(result.location);
          }
        }

        if (count == 1) {
          count_str = "1 result";
        } else if (count == 200) {
          count_str = "200+ results";
        } else {
          count_str = count + " results";
        }
        let result_count = `<div class="is-size-6">${count_str}</div>`;

        search_result_container = `
              <div class="is-flex is-flex-direction-column gap-2 is-align-items-flex-start">
                  ${modal_filters}
                  ${search_divider}
                  ${result_count}
                  <div class="is-clipped w-100 is-flex is-flex-direction-column gap-2 is-align-items-flex-start has-text-justified mt-1">
                    ${search_results}
                  </div>
              </div>
          `;
      } else {
        search_result_container = `
            <div class="is-flex is-flex-direction-column gap-2 is-align-items-flex-start">
                ${modal_filters}
                ${search_divider}
                <div class="is-size-6">0 result(s)</div>
              </div>
              <div class="has-text-centered my-5 py-5">No result found!</div>
        `;
      }

      if ($(".search-modal-card-body").hasClass("is-justify-content-center")) {
        $(".search-modal-card-body").removeClass("is-justify-content-center");
      }

      $(".search-modal-card-body").html(search_result_container);
    } else {
      if (!$(".search-modal-card-body").hasClass("is-justify-content-center")) {
        $(".search-modal-card-body").addClass("is-justify-content-center");
      }

      $(".search-modal-card-body").html(`
        <div class="has-text-centered my-5 py-5">Type something to get started!</div>
      `);
    }
  }

  //url param checking
  function checkURLForSearch() {
    const urlParams = new URLSearchParams(window.location.search);
    const searchQuery = urlParams.get("q");
    const filterParam = urlParams.get("filter");

    // Set the selected filter if present in URL
    if (filterParam) {
      selected_filter = filterParam.toLowerCase();
    }

    // Trigger input event if there's a search query to perform the search
    if (searchQuery) {
      $(".documenter-search-input").val(searchQuery).trigger("input");
    }
  }
  setTimeout(checkURLForSearch, 100);

  /**
   * Make the modal filter html
   *
   * @returns string
   */
  function make_modal_body_filters() {
    let str = filters
      .map((val) => {
        if (selected_filter == val.toLowerCase()) {
          return `<a href="javascript:;" class="search-filter search-filter-selected"><span>${val}</span></a>`;
        } else {
          return `<a href="javascript:;" class="search-filter"><span>${val}</span></a>`;
        }
      })
      .join("");

    return `
          <div class="is-flex gap-2 is-flex-wrap-wrap is-justify-content-flex-start is-align-items-center search-filters">
              <span class="is-size-6">Filters:</span>
              ${str}
          </div>`;
  }
}

function waitUntilSearchIndexAvailable() {
  // It is possible that the documenter.js script runs before the page
  // has finished loading and documenterSearchIndex gets defined.
  // So we need to wait until the search index actually loads before setting
  // up all the search-related stuff.
  if (typeof documenterSearchIndex !== "undefined") {
    runSearchMainCode();
  } else {
    console.warn("Search Index not available, waiting");
    setTimeout(waitUntilSearchIndexAvailable, 1000);
  }
}

// The actual entry point to the search code
waitUntilSearchIndexAvailable();
