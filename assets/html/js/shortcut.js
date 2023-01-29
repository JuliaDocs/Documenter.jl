// libraries: jquery
// arguments: $

let searchbox = $("#documenter-search-query");
let sidebar = $(".docs-sidebar");

$(document).keydown(function (event) {
  if ((event.ctrlKey || event.metaKey) && event.key === "/") {
    if (!sidebar.hasClass("visible")) {
      sidebar.addClass("visible");
    }
    searchbox.focus();
    return false;
  } else if (event.key === "Escape") {
    if (sidebar.hasClass("visible")) {
      sidebar.removeClass("visible");
    }
    searchbox.blur();
    return false;
  }
});
