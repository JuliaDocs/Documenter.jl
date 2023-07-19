// libraries: jquery, headroom, headroom-jquery
// arguments: $, Headroom

// Manages the top navigation bar (hides it when the user starts scrolling down on the
// mobile).
window.Headroom = Headroom; // work around buggy module loading?
$(document).ready(function () {
  $("#documenter .docs-navbar").headroom({
    tolerance: { up: 10, down: 10 },
  });
});
