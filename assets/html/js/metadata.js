// libraries: jquery
// arguments: $

$(document).ready(function () {
  let meta = $("div[data-docstringscollapsed]").data();
  console.log(meta);
  if (!meta.docstringscollapsed) {
    $("#documenter-article-toggle-button").trigger({
      type: "click",
    });
  }
});
