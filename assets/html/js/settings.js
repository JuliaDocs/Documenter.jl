// libraries: jquery
// arguments: $

// Modal settings dialog
$(document).ready(() => {
  var settings = $("#documenter-settings");
  $("#documenter-settings-button").click(() => {
    settings.toggleClass("is-active");
  });
  // Close the dialog if X is clicked
  $("#documenter-settings button.delete").click(() => {
    settings.removeClass("is-active");
  });
  // Close dialog if ESC is pressed
  $(document).keyup((e) => {
    if (e.keyCode === 27) settings.removeClass("is-active");
  });
});
