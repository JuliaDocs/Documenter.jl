// libraries: jquery
// arguments: $

// Modal settings dialog
$(document).ready(function () {
  var settings = $("#documenter-settings");
  $("#documenter-settings-button").click(function () {
    settings.toggleClass("is-active");
  });
  // Close the dialog if X is clicked
  $("#documenter-settings button.delete").click(function () {
    settings.removeClass("is-active");
  });
  // Close dialog if ESC is pressed
  $(document).keyup(function (e) {
    if (e.keyCode == 27) settings.removeClass("is-active");
  });
});
