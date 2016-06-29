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

import ..Writers: render

# TODO

function render(io::IO, ::MIME"text/latex", node, page, doc)
    error("LaTeX rendering is unsupported.")
end

end
