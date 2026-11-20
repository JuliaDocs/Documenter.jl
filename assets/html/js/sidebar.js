// libraries: jquery
// arguments: $

// Manages the showing and hiding of the sidebar.
$(document).ready(function () {
  var sidebar = $("#documenter .docs-sidebar");
  var sidebar_button = $("#documenter-sidebar-button");
  sidebar_button.click(function (ev) {
    ev.preventDefault();
    sidebar.toggleClass("visible");
    if (sidebar.hasClass("visible")) {
      // Makes sure that the current menu item is visible in the sidebar.
      $("#documenter .docs-menu a.is-active").focus();
    }
  });
  $("#documenter .docs-main").bind("click", function (ev) {
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

// Dynamically update --topmenu-height so that the sidebar, content wrapper, and
// sticky navbar all stay correctly positioned when top menu items wrap to a new line.
$(document).ready(function () {
  var topMenu = $("#documenter .docs-top-menu");
  if (topMenu.length === 0) return;
  var documenter = document.getElementById("documenter");
  function updateTopMenuHeight() {
    var height = topMenu[0].offsetHeight + "px";
    documenter.style.setProperty("--topmenu-height", height);
    // Offset anchor-scroll targets so the fixed top menu doesn't cover them
    document.documentElement.style.scrollPaddingTop = height;
  }
  updateTopMenuHeight();
  $(window).resize(updateTopMenuHeight);
  $(window).on("orientationchange", updateTopMenuHeight);
  // Re-scroll to the hash anchor now that scroll-padding-top is set.
  // The browser may have already scrolled to the anchor before JS ran,
  // causing the header to be hidden under the fixed top menu.
  if (location.hash) {
    var target = document.getElementById(
      decodeURIComponent(location.hash.substring(1)),
    );
    if (target) target.scrollIntoView();
  }
});

// Lays out long top-menu dropdowns in multiple columns so that they fit in the
// viewport. The number of rows is computed from the available height when the
// dropdown is opened; the grid then grows horizontally to hold all columns.
$(document).ready(function () {
  function layoutDropdown() {
    var menu = $(this).children(".docs-top-dropdown-menu").get(0);
    if (!menu || menu.children.length === 0) return;
    // Reset to a single column to measure the natural layout.
    menu.style.gridAutoFlow = "";
    menu.style.gridTemplateRows = "";
    menu.style.left = "";
    $(menu.children).removeClass(
      "docs-top-dropdown-sep is-col-top is-col-bottom",
    );
    var rect = menu.getBoundingClientRect();
    if (rect.height === 0) return; // not displayed
    var items = menu.children;
    var n = items.length;
    var itemHeight = items[0].getBoundingClientRect().height;
    var style = window.getComputedStyle(menu);
    var padding =
      parseFloat(style.paddingTop) +
      parseFloat(style.paddingBottom) +
      parseFloat(style.borderTopWidth) +
      parseFloat(style.borderBottomWidth);
    var available = window.innerHeight - rect.top - 16 - padding;
    var maxRows = Math.max(1, Math.floor(available / itemHeight));
    if (n > maxRows) {
      // Balance the items across the minimal number of columns.
      var cols = Math.ceil(n / maxRows);
      var rows = Math.ceil(n / cols);
      menu.style.gridAutoFlow = "column";
      menu.style.gridTemplateRows = "repeat(" + rows + ", auto)";
      // Mark the items of every column but the last, so that CSS can draw a
      // separator line on their right, inset at the top and bottom.
      for (var i = 0; i < (cols - 1) * rows; i++) {
        var item = $(items[i]).addClass("docs-top-dropdown-sep");
        if (i % rows === 0) item.addClass("is-col-top");
        if (i % rows === rows - 1) item.addClass("is-col-bottom");
      }
    }
    // Shift the dropdown left if it would overflow the right edge of the viewport.
    rect = menu.getBoundingClientRect();
    var overflow = rect.right - document.documentElement.clientWidth;
    if (overflow > 0) {
      menu.style.left = -Math.min(overflow, rect.left) + "px";
    }
  }
  $("#documenter .docs-top-dropdown").on("mouseenter focusin", layoutDropdown);
});

// Scroll the navigation bar to the currently selected menu item
$(document).ready(function () {
  var sidebar = $("#documenter .docs-menu").get(0);
  var active = $("#documenter .docs-menu .is-active").get(0);
  if (typeof active !== "undefined") {
    sidebar.scrollTop = active.offsetTop - sidebar.offsetTop - 15;
  }
});
