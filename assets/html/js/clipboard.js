// libraries: jquery, clipboard
// arguments: $, ClipboardJS

// Copies code block to clipboard.
$(document).ready(function() {
  var clipboard = new ClipboardJS('.copy-button');
  var btns = document.querySelectorAll('.copy-button');
  clipboard.on('success', function(e) {
    showTooltip(e.trigger, 'Copied!');
  })

  for (var i = 0; i < btns.length; i++) {
    btns[i].addEventListener('mouseleave', clearTooltip);
    btns[i].addEventListener('blur', clearTooltip);
  }

  function clearTooltip(e) {
    e.currentTarget.setAttribute('class', 'copy-button button');
    e.currentTarget.removeAttribute('aria-label');
  }

  function showTooltip(elem, msg) {
    elem.setAttribute('class', 'copy-button button tooltipped tooltipped-s');
    elem.setAttribute('aria-label', msg);
  }
});
