"""
Filetypes used to decide which rendering methods in [`Lapidary.Writers`]({ref}) are called.

The only supported format is currently `Markdown`.
"""
module Formats

using Compat

import ..Lapidary

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
Converts a [`Format`]({ref}) value to a `MIME` type.
"""
function mimetype(f::Format)
    f ≡ Markdown ? MIME"text/plain"() :
    f ≡ LaTeX    ? MIME"text/latex"() :
    f ≡ HTML     ? MIME"text/html"()  :
        error("unexpected format.")
end

end
