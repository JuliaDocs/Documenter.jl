// libraries: jquery
// arguments: $

var isExpanded = true;
let timer = undefined;

$(document).on("click", ".docstring header", function () {
  let articleToggleTitle = "Expand docstring";

  debounce(() => {
    if ($(this).siblings("section").is(":visible")) {
      $(this)
        .find(".docstring-article-toggle-button")
        .removeClass("fa-chevron-down")
        .addClass("fa-chevron-right");
    } else {
      $(this)
        .find(".docstring-article-toggle-button")
        .removeClass("fa-chevron-right")
        .addClass("fa-chevron-down");

      articleToggleTitle = "Collapse docstring";
    }

    $(this)
      .find(".docstring-article-toggle-button")
      .prop("title", articleToggleTitle);
    $(this).siblings("section").slideToggle();
  }, 300);
});

$(document).on("click", ".docs-article-toggle-button", function () {
  let articleToggleTitle = "Expand docstring";
  let navArticleToggleTitle = "Expand all docstrings";

  debounce(() => {
    if (isExpanded) {
      $(this).removeClass("fa-chevron-up").addClass("fa-chevron-down");
      $(".docstring-article-toggle-button")
        .removeClass("fa-chevron-down")
        .addClass("fa-chevron-right");

      isExpanded = false;

      $(".docstring section").slideUp();
    } else {
      $(this).removeClass("fa-chevron-down").addClass("fa-chevron-up");
      $(".docstring-article-toggle-button")
        .removeClass("fa-chevron-right")
        .addClass("fa-chevron-down");

      isExpanded = true;
      articleToggleTitle = "Collapse docstring";
      navArticleToggleTitle = "Collapse all docstrings";

      $(".docstring section").slideDown();
    }

    $(this).prop("title", navArticleToggleTitle);
    $(".docstring-article-toggle-button").prop("title", articleToggleTitle);
  }, 300);
});

function debounce(callback, timeout = 300) {
  clearTimeout(timer);
  timer = setTimeout(callback, timeout);
}
