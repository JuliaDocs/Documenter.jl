"""
Filetypes used to decide which rendering methods in [`Documenter.Writers`](@ref) are called.

The only supported format is currently `Markdown`.
"""
module Formats

import ..Documenter

using Compat

"""
Represents the output format. Possible values are `Markdown`, `LaTeX`, and `HTML`.
"""
@enum(
    Format,
    Markdown,
    LaTeX,
    HTML,
)

"""
Converts a [`Format`](@ref) value to a `MIME` type.
"""
function mimetype(f::Format)
    f ≡ Markdown ? MIME"text/plain"() :
    f ≡ LaTeX    ? MIME"text/latex"() :
    f ≡ HTML     ? MIME"text/html"()  :
        error("unexpected format.")
end

function extension(f::Format, file)
    path, _ = splitext(file)
    string(path, extension(f))
end

function extension(f::Format)
    f ≡ Markdown ? ".md"   :
    f ≡ LaTeX    ? ".tex"  :
    f ≡ HTML     ? ".html" :
        error("unexpected format.")
end

end
