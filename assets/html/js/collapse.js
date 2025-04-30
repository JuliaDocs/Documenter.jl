// libraries: jquery
// arguments: $

let timer = 0;
var isExpanded = true;

$(document).on(
  "click",
  ".docstring .docstring-article-toggle-button",
  function () {
    let articleToggleTitle = "Expand docstring";
    const parent = $(this).parent();

    debounce(() => {
      if (parent.siblings("section").is(":visible")) {
        parent
          .find("a.docstring-article-toggle-button")
          .removeClass("fa-chevron-down")
          .addClass("fa-chevron-right");
      } else {
        parent
          .find("a.docstring-article-toggle-button")
          .removeClass("fa-chevron-right")
          .addClass("fa-chevron-down");

        articleToggleTitle = "Collapse docstring";
      }

      parent
        .children(".docstring-article-toggle-button")
        .prop("title", articleToggleTitle);
      parent.siblings("section").slideToggle();
    });
  }
);

$(document).on("click", ".docs-article-toggle-button", function (event) {
  let articleToggleTitle = "Expand docstring";
  let navArticleToggleTitle = "Expand all docstrings";
  let animationSpeed = event.noToggleAnimation ? 0 : 400;

  debounce(() => {
    if (isExpanded) {
      $(this).removeClass("fa-chevron-up").addClass("fa-chevron-down");
      $("a.docstring-article-toggle-button")
        .removeClass("fa-chevron-down")
        .addClass("fa-chevron-right");

      isExpanded = false;

      $(".docstring section").slideUp(animationSpeed);
    } else {
      $(this).removeClass("fa-chevron-down").addClass("fa-chevron-up");
      $("a.docstring-article-toggle-button")
        .removeClass("fa-chevron-right")
        .addClass("fa-chevron-down");

      isExpanded = true;
      articleToggleTitle = "Collapse docstring";
      navArticleToggleTitle = "Collapse all docstrings";

      $(".docstring section").slideDown(animationSpeed);
    }

    $(this).prop("title", navArticleToggleTitle);
    $(".docstring-article-toggle-button").prop("title", articleToggleTitle);
  });
});

function debounce(callback, timeout = 300) {
  if (Date.now() - timer > timeout) {
    callback();
  }

  clearTimeout(timer);

  timer = Date.now();
}
