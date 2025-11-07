// libraries: jquery
// arguments: $
$(document).ready(function () {
  $(".footnote-ref").hover(
    function () {
      var id = $(this).attr("href");
      var footnoteContent = $(id).clone().find("a").remove().end().html();

      var $preview = $(this).next(".footnote-preview");

      $preview.html(footnoteContent).css({
        display: "block",
        left: "50%",
        transform: "translateX(-50%)",
      });

      repositionPreview($preview, $(this));
    },
    function () {
      var $preview = $(this).next(".footnote-preview");
      $preview.css({
        display: "none",
        left: "",
        transform: "",
        "--arrow-left": "",
      });
    }
  );

  function repositionPreview($preview, $ref) {
    var previewRect = $preview[0].getBoundingClientRect();
    var refRect = $ref[0].getBoundingClientRect();
    var viewportWidth = $(window).width();

    if (previewRect.right > viewportWidth) {
      var excessRight = previewRect.right - viewportWidth;
      $preview.css("left", `calc(50% - ${excessRight + 10}px)`);
    } else if (previewRect.left < 0) {
      var excessLeft = 0 - previewRect.left;
      $preview.css("left", `calc(50% + ${excessLeft + 10}px)`);
    }

    var newPreviewRect = $preview[0].getBoundingClientRect();

    var arrowLeft = refRect.left + refRect.width / 2 - newPreviewRect.left;

    $preview.css("--arrow-left", arrowLeft + "px");
  }
});
