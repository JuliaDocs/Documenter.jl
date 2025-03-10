// libraries: jquery
// arguments: $

$(document).ready(function () {
  let meta = $("div[data-docstringscollapsed]").data();

  if (meta?.docstringscollapsed) {
    $("#documenter-article-toggle-button").trigger({
      type: "click",
      noToggleAnimation: true,
    });

    setTimeout(function () {
      if (window.location.hash) {
        const targetId = window.location.hash.substring(1);
        const targetElement = document.getElementById(targetId);

        if (targetElement) {
          targetElement.scrollIntoView({
            behavior: "smooth",
            block: "center",
          });
        }
      }
    }, 100);
  }
});
