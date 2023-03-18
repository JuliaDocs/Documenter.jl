// libraries: jquery
// arguments: $

var is_expanded = true;

$(document).on("click", ".docstring header", function () {
  if ($(this).siblings("section").is(":visible")) {
    $(this)
      .find(".docstring-article-toggle-button")
      .removeClass("fa-chevron-up")
      .addClass("fa-chevron-down");
    $(this).find(".docstring-article-toggle-button").prop("title", "Expand article");
  } else {
    $(this)
      .find(".docstring-article-toggle-button")
      .removeClass("fa-chevron-down")
      .addClass("fa-chevron-up");
    $(this).find(".docstring-article-toggle-button").prop("title", "Collapse article");
  }
  $(this).siblings("section").slideToggle();
});

$(document).on("click", ".docs-article-toggle-button", function () {
  if (is_expanded) {
    $(this).removeClass("fa-chevron-up").addClass("fa-chevron-down");
    $(".docstring-article-toggle-button").removeClass("fa-chevron-up").addClass("fa-chevron-down");
    $(this).prop("title", "Expand all Articles");
    $(".docstring-article-toggle-button").prop("title", "Expand article");
    $(".docstring section").slideUp();
    is_expanded = false;
  } else {
    $(this).prop("title", "Collapse all Articles");
    $(".docstring-article-toggle-button").prop("title", "Collapse article");
    $(this).removeClass("fa-chevron-down").addClass("fa-chevron-up");
    $(".docstring-article-toggle-button").removeClass("fa-chevron-down").addClass("fa-chevron-up");
    $(".docstring section").slideDown();
    is_expanded = true;
  }
});
