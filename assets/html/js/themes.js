// libraries: jquery
// arguments: $

// Theme picker setup
$(document).ready(function () {
  // onchange callback
  $("#documenter-themepicker").change(function themepick_callback(ev) {
    var themename = $("#documenter-themepicker option:selected").attr("value");
    if (themename === "auto") {
      // set_theme(window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      window.localStorage.removeItem("documenter-theme");
    } else {
      // set_theme(themename);
      window.localStorage.setItem("documenter-theme", themename);
    }
    // We re-use the global function from themeswap.js to actually do the swapping.
    set_theme_from_local_storage();
  });

  // Make sure that the themepicker displays the correct theme when the theme is retrieved
  // from localStorage
  if (typeof window.localStorage !== "undefined") {
    var theme = window.localStorage.getItem("documenter-theme");
    if (theme !== null) {
      $("#documenter-themepicker option").each(function (i, e) {
        e.selected = e.value === theme;
      });
    }
  }
});
