"""
Provides the [`render`](@ref) methods to write the documentation as LaTeX files
(`MIME"text/latex"`).
"""
module LaTeXWriter

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

function render(::Writer{Formats.LaTeX}, doc::Documents.Document)
    error("LaTeX rendering is unsupported.")
end

end
