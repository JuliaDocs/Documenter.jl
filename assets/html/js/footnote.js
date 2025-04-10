// libraries: jquery
// arguments: $
$(document).ready(function() {

    // Bind hover event with separate enter and leave callbacks
    $('.footnote-ref').hover(
        function() { // mouseenter
            // Retrieve the content from the target footnote element
            var id = $(this).attr('href');
            var footnoteContent = $(id).clone().find('a').remove().end().html();

            // Get the associated preview element (immediately following sibling)
            var $preview = $(this).next('.footnote-preview');

            // Insert content and show the preview
            $preview.html(footnoteContent).css({
                display: 'block',
                left: '50%',
                transform: 'translateX(-50%)'
            });

            // Reposition the preview and adjust the arrow placement
            repositionPreview($preview, $(this));
        },
        function() { // mouseleave
            // Hide the preview and reset any inline styles
            var $preview = $(this).next('.footnote-preview');
            $preview.css({
                display: 'none',
                left: '',
                transform: '',
                '--arrow-left': ''
            });
        }
    );

    // Function to reposition the tooltip preview within the viewport and adjust the arrow
    function repositionPreview($preview, $ref) {
        // First, measure current dimensions
        var previewRect = $preview[0].getBoundingClientRect();
        var refRect = $ref[0].getBoundingClientRect();
        var viewportWidth = $(window).width();

        // Adjust if preview overflows to the right
        if (previewRect.right > viewportWidth) {
            var excessRight = previewRect.right - viewportWidth;
            $preview.css('left', `calc(50% - ${excessRight + 10}px)`);
        } 
        // Adjust if preview overflows to the left
        else if (previewRect.left < 0) {
            var excessLeft = 0 - previewRect.left;
            $preview.css('left', `calc(50% + ${excessLeft + 10}px)`);
        }

        // After repositioning, re-measure the preview element
        var newPreviewRect = $preview[0].getBoundingClientRect();

        // Calculate the distance (in pixels) from the left edge of the preview to the center of the reference element
        var arrowLeft = (refRect.left + (refRect.width / 2)) - newPreviewRect.left;

        // Set the CSS custom property for the arrow's horizontal position
        $preview.css('--arrow-left', arrowLeft + 'px');
    }

});
