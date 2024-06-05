// libraries: jquery
// arguments: $

$(document).ready(function() {
    $('.footnote-ref').hover(function() {
        var id = $(this).attr('href');
        var footnoteContent = $(id).clone().find('a').remove().end().html();
        $(this).next('.footnote-preview').html(footnoteContent);
    });
});