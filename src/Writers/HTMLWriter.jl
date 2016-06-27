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

import ..Writers: render

# TODO

function render(io::IO, ::MIME"text/html", node, page, doc)
    error("HTML rendering is unsupported.")
end

end
