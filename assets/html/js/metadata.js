// libraries: jquery
// arguments: $

let meta = $("div[data-docstringscollapsed]").data();

if (meta.docstringscollapsed) {
  $("#documenter-article-toggle-button").click();
}
