// libraries: jquery, minisearch
// arguments: $, minisearch

let results = [];
let timer = undefined;

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

let filters = [...new Set(ms_data.map((x) => x.category))];
var modal_filters = make_modal_body_filters(filters);
var filter_results = [];

$(document).on("keyup", ".documenter-search-input", function (event) {
  debounce(() => update_search(filter_results), 300);
});

$(document).on("click", ".search-filter", function () {
  if ($(this).hasClass("search-filter-selected")) {
    $(this).removeClass("search-filter-selected");
  } else {
    $(this).addClass("search-filter-selected");
  }

  debounce(() => get_filters(), 300);
});

function debounce(callback, timeout = 300) {
  clearTimeout(timer);
  timer = setTimeout(callback, timeout);
}

function update_search(selected_filters = []) {
  let initial_search_body = `
      <div class="has-text-centered my-5 py-5">No recent searches!</div>
    `;

  let querystring = $(".documenter-search-input").val();

  if (querystring.trim()) {
    results = index.search(querystring, {
      filter: (result) => {
        if (selected_filters.length === 0) {
          return result.score >= 1;
        } else {
          return (
            result.score >= 1 && selected_filters.includes(result.category)
          );
        }
      },
    });

    let search_result_container = ``;
    let search_divider = `<div class="search-divider w-100"></div>`;

    if (results.length) {
      let links = [];
      let count = 0;
      let search_results = "";

      results.forEach(function (result) {
        if (result.location) {
          if (!links.includes(result.location)) {
            search_results += make_search_result(result, querystring);
            count++;
          }

          links.push(result.location);
        }
      });

      let result_count = `<div class="is-size-6">${count} result(s)</div>`;

      search_result_container = `
            <div class="is-flex is-flex-direction-column gap-2 is-align-items-flex-start">
                ${modal_filters}
                ${search_divider}
                ${result_count}
                <div class="is-clipped w-100 is-flex is-flex-direction-column gap-4 is-align-items-flex-start has-text-justified mt-1">
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

    $(".search-modal-card-body").html(search_result_container);
  } else {
    filter_results = [];
    modal_filters = make_modal_body_filters(filters, filter_results);
    $(".search-modal-card-body").html(initial_search_body);
  }
}

function make_modal_body_filters(filters, selected_filters = []) {
  let str = ``;

  filters.forEach((val) => {
    if (selected_filters.includes(val)) {
      str += `<a href="javascript:;" class="search-filter search-filter-selected"><span>${val}</span></a>`;
    } else {
      str += `<a href="javascript:;" class="search-filter"><span>${val}</span></a>`;
    }
  });

  let filter_html = `
        <div class="is-flex gap-2 is-flex-wrap-wrap is-justify-content-flex-start is-align-items-center search-filters">
            <span class="is-size-6">Filters:</span>
            ${str}
        </div>
    `;

  return filter_html;
}

function make_search_result(result, querystring) {
  let search_divider = `<div class="search-divider w-100"></div>`;
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
      }" class="search-result-link w-100 is-flex is-flex-direction-column gap-2 p-4">
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
      ${search_divider}
    `;

  return result_div;
}

function get_filters() {
  let ele = $(".search-filters .search-filter-selected").get();
  filter_results = ele.map((x) => $(x).text().toLowerCase());
  modal_filters = make_modal_body_filters(filters, filter_results);
  update_search(filter_results);
}
