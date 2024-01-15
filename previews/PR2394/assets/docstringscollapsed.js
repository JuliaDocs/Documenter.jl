// Should be loaded if `DocStringsCollapse = true` in `@meta` block of page, and
// clicks the button to toggle docstrings after the page loads.
function clickToggleButton() {
  var toggleButton = document.getElementById(
    "documenter-article-toggle-button",
  );
  if (toggleButton) {
    toggleButton.click();
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", clickToggleButton);
} else {
  clickToggleButton();
}
