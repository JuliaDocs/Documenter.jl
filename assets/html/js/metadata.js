// libraries: jquery
// arguments: $

$(document).ready(function () {
  let meta = $('div[data-docstringscollapsed]').data();

  if (meta?.docstringscollapsed) {
    $('#documenter-article-toggle-button').trigger({
      type: 'click',
      noToggleAnimation: true,
    });
  }
});
