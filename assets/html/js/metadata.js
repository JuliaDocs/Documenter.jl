// libraries: jquery
// arguments: $

$(document).ready(() => {
  const meta = $("div[data-docstringscollapsed]").data();
  if (!meta?.docstringscollapsed) {
    $("#documenter-article-toggle-button").trigger({
      type: "click",
    });
  }
});
