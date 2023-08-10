// libraries: jquery
// arguments: $

// Manages the showing and hiding of the sidebar.
$(document).ready(function () {
  var sidebar = $("#documenter > .docs-sidebar");
  var sidebar_button = $("#documenter-sidebar-button");
  sidebar_button.click(function (ev) {
    ev.preventDefault();
    sidebar.toggleClass("visible");
    if (sidebar.hasClass("visible")) {
      // Makes sure that the current menu item is visible in the sidebar.
      $("#documenter .docs-menu a.is-active").focus();
    }
  });
  $("#documenter > .docs-main").bind("click", function (ev) {
    if ($(ev.target).is(sidebar_button)) {
      return;
    }
    if (sidebar.hasClass("visible")) {
      sidebar.removeClass("visible");
    }
  });
});

// Resizes the package name / sitename in the sidebar if it is too wide.
// Inspired by: https://github.com/davatron5000/FitText.js
$(document).ready(function () {
  e = $("#documenter .docs-autofit");
  function resize() {
    var L = parseInt(e.css("max-width"), 10);
    var L0 = e.width();
    if (L0 > L) {
      var h0 = parseInt(e.css("font-size"), 10);
      e.css("font-size", (L * h0) / L0);
      // TODO: make sure it survives resizes?
    }
  }
  // call once and then register events
  resize();
  $(window).resize(resize);
  $(window).on("orientationchange", resize);
});

// Scroll the navigation bar to the currently selected menu item
$(document).ready(function () {
  var sidebar = $("#documenter .docs-menu").get(0);
  var active = $("#documenter .docs-menu .is-active").get(0);
  if (typeof active !== "undefined") {
    sidebar.scrollTop = active.offsetTop - sidebar.offsetTop - 15;
  }
});
