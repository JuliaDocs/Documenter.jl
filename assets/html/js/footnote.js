// libraries: jquery
// arguments: $
$(document).ready(function () {
  // Gap between the reference and the preview, and the minimum distance the preview keeps
  // from the edges of the viewport.
  var MARGIN = 10;
  // Grace period that lets the pointer travel from the reference to the preview.
  var HIDE_DELAY = 200;

  var hideTimer = null;
  var $visible = null;

  function show($ref) {
    clearTimeout(hideTimer);
    var $preview = $ref.next(".footnote-preview");
    if ($visible && $visible[0] !== $preview[0]) {
      hideNow();
    }
    var content = $($ref.attr("href")).clone().find("a").remove().end().html();
    $preview
      .empty()
      .append($("<div>", { class: "footnote-preview-content" }).html(content))
      .css("display", "block");
    $visible = $preview;
    reposition();
  }

  function hideNow() {
    if (!$visible) return;
    $visible
      .removeClass("is-above")
      .css({ display: "", top: "", left: "", "--arrow-left": "" })
      .empty();
    $visible = null;
  }

  function hideSoon() {
    clearTimeout(hideTimer);
    hideTimer = setTimeout(hideNow, HIDE_DELAY);
  }

  // The preview is positioned with `position: fixed` so that it is never clipped by an
  // ancestor that scrolls or hides its overflow, such as a table or a code block.
  function reposition() {
    if (!$visible) return;
    var $preview = $visible;
    var $content = $preview.children(".footnote-preview-content");
    var $ref = $preview.prev(".footnote-ref");
    var refRect = $ref[0].getBoundingClientRect();
    var viewportWidth = document.documentElement.clientWidth;
    var viewportHeight = document.documentElement.clientHeight;

    // Measure the unconstrained size first, to decide whether the preview fits below.
    $preview.css({ top: 0, left: 0 });
    $content.css("max-height", "");
    var spaceBelow = viewportHeight - refRect.bottom - 2 * MARGIN;
    var spaceAbove = refRect.top - 2 * MARGIN;
    var above =
      $preview[0].offsetHeight > spaceBelow && spaceAbove > spaceBelow;

    // Cap the content, not the box itself, so that the arrow is not clipped away.
    var padding = $preview[0].offsetHeight - $content[0].offsetHeight;
    var space = (above ? spaceAbove : spaceBelow) - padding;
    $content.css("max-height", Math.max(space, 0));

    var width = $preview[0].offsetWidth;
    var height = $preview[0].offsetHeight;

    var left = refRect.left + refRect.width / 2 - width / 2;
    left = Math.min(left, viewportWidth - width - MARGIN);
    left = Math.max(left, MARGIN);

    $preview.toggleClass("is-above", above).css({
      left: left,
      top: above ? refRect.top - height - MARGIN : refRect.bottom + MARGIN,
      "--arrow-left": refRect.left + refRect.width / 2 - left + "px",
    });
  }

  $(document)
    .on("mouseenter", ".footnote-ref", function () {
      show($(this));
    })
    .on("mouseleave", ".footnote-ref", hideSoon)
    .on("mouseenter", ".footnote-preview", function () {
      clearTimeout(hideTimer);
    })
    .on("mouseleave", ".footnote-preview", hideSoon);

  $(window).on("scroll resize", reposition);
});
