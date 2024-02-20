// libraries: jquery
// arguments: $

$(document).ready(function () {
  let meta = $("div[data-docstringscollapsed]").data();

  // Check if metadata object exists
  if (meta) {
    if (meta.docstringscollapsed) {
      $("#documenter-article-toggle-button").trigger({
        type: "click",
        noToggleAnimation: true,
      });
    }
  }
});
