"""
Provides the [`render`](@ref) methods to write the documentation as HTML files
(`MIME"text/html"`).
"""
module HTMLWriter

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities

import ..Writers: Writer, render

# TODO

function render(::Writer{Formats.HTML}, doc::Documents.Document)
    error("HTML rendering is unsupported.")
end

end
