// libraries: jquery
// arguments: $

///////////////////////////////////

// to open and scroll to
function openTarget() {
  const hash = decodeURIComponent(location.hash.substring(1));
  if (hash) {
    const target = document.getElementById(hash);
    if (target) {
      const details = target.closest("details");
      if (details) details.open = true;
    }
  }
}
openTarget(); // onload
window.addEventListener("hashchange", openTarget);
window.addEventListener("load", openTarget);

//////////////////////////////////////
// for the global expand/collapse butter

function accordion() {
  document.body
    .querySelectorAll("details.docstring")
    .forEach((e) => e.setAttribute("open", "true"));
}

function noccordion() {
  document.body
    .querySelectorAll("details.docstring")
    .forEach((e) => e.removeAttribute("open"));
}

function expandAll() {
  let me = document.getElementById("documenter-article-toggle-button");
  me.setAttribute("open", "true");
  $(me).removeClass("fa-chevron-down").addClass("fa-chevron-up");
  $(me).prop("title", "Collapse all docstrings");
  accordion();
}

function collapseAll() {
  let me = document.getElementById("documenter-article-toggle-button");
  me.removeAttribute("open");
  $(me).removeClass("fa-chevron-up").addClass("fa-chevron-down");
  $(me).prop("title", "Expand all docstrings");
  noccordion();
}

$(document).on("click", ".docs-article-toggle-button", function () {
  var isExpanded = this.hasAttribute("open");
  if (isExpanded) {
    collapseAll();
    isExpanded = false;
  } else {
    expandAll();
    isExpanded = true;
  }
});
