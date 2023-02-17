let searchbox = document.querySelector("#documenter-search-query");
let sidebar = document.querySelector(".docs-sidebar");

document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key === "/") {
    if (!sidebar.classList.contains("visible")) {
      sidebar.classList.add("visible");
    }
    searchbox.focus();
    return false;
  } else if (event.key === "Escape") {
    if (sidebar.classList.contains("visible")) {
      sidebar.classList.remove("visible");
    }
    searchbox.blur();
    return false;
  }
});
