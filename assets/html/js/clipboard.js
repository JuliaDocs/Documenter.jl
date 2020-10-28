// libraries: jquery, clipboard
// arguments: $, ClipboardJS

// Copies code block to clipboard.
$(document).ready(function() {
  var clipboard = new ClipboardJS('.copy-button');
  clipboard.on('success', function(e) {
    var previousHTML = e.trigger.innerHTML;
    e.trigger.innerHTML = 'Copied!';

    setTimeout(() => {
      e.trigger.innerHTML = previousHTML;
    }, 2000)
  });
});
