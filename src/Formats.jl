"""
Filetypes used to decide which rendering methods in [`Documenter.Writers`](@ref) are called.

The only supported format is currently `Markdown`.
"""
module Formats

import ..Documenter

using DocStringExtensions

"""
$(SIGNATURES)

Converts a [`Format`](@ref) value to a `MIME` type.
"""
function mimetype(f::Symbol)
    f ≡ :markdown ? MIME"text/plain"() :
    f ≡ :latex    ? MIME"text/latex"() :
    f ≡ :html     ? MIME"text/html"()  :
        error("unexpected format.")
end

function extension(f::Symbol, file)
    path, _ = splitext(file)
    string(path, extension(f))
end

function extension(f::Symbol)
    f ≡ :markdown ? ".md"   :
    f ≡ :latex    ? ".tex"  :
    f ≡ :html     ? ".html" :
        error("unexpected format.")
end

end
