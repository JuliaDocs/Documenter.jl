"""
Filetypes used to decide which rendering methods in [`Documenter.Writers`](@ref) are called.

The only supported format is currently `Markdown`.
"""
module Formats

import ..Documenter

using Compat, DocStringExtensions

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

# `fmt` -- convert a format spec to a vector of symbols.
const DEPRECATION_MAPPING = Dict(
    Markdown => :markdown,
    LaTeX    => :latex,
    HTML     => :html,
)
function _fmt(f::Format)
    s = DEPRECATION_MAPPING[f]
    Base.depwarn("`$(f)` is deprecated use `:$(s)` for `format = ...`.", :fmt)
    return s
end
fmt(f::Format) = [_fmt(f)]
fmt(v::Vector{Format}) = map(_fmt, v)
fmt(s::Symbol) = [s]
fmt(v::Vector{Symbol}) = v

end
