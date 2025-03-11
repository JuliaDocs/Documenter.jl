# A module that provides several renderers for `Document` objects. The supported
# formats are currently:
#
#   * `:html` -- generates a complete HTML site with navigation and search included.
#   * `:latex` -- generates a PDF using LuaLaTeX.

#
# Format selector definitions.
#

abstract type FormatSelector <: Selectors.AbstractSelector end

abstract type LaTeXFormat <: FormatSelector end
abstract type HTMLFormat <: FormatSelector end

Selectors.order(::Type{LaTeXFormat}) = 2.0
Selectors.order(::Type{HTMLFormat}) = 3.0

Selectors.matcher(::Type{LaTeXFormat}, fmt, _) = isa(fmt, LaTeXWriter.LaTeX)
Selectors.matcher(::Type{HTMLFormat}, fmt, _) = isa(fmt, HTMLWriter.HTML)

Selectors.runner(::Type{LaTeXFormat}, fmt, doc) = LaTeXWriter.render(doc, fmt)
Selectors.runner(::Type{HTMLFormat}, fmt, doc) = HTMLWriter.render(doc, fmt)

"""
Writes a [`Documenter.Document`](@ref) object to `.user.build` directory in
the formats specified in the `.user.format` vector.

Adding additional formats requires adding new `Selector` definitions as follows:

```julia
abstract type CustomFormat <: FormatSelector end

Selectors.order(::Type{CustomFormat}) = 4.0 # or a higher number.
Selectors.matcher(::Type{CustomFormat}, fmt, _) = fmt === :custom
Selectors.runner(::Type{CustomFormat}, _, doc) = CustomWriter.render(doc)

# Definition of `CustomWriter` module below...
```
"""
function render(doc::Documenter.Document)
    # Render each format. Additional formats must define an `order`, `matcher`, `runner`, as
    # well as their own rendering methods in a separate module.
    for each in doc.user.format
        Selectors.dispatch(FormatSelector, each, doc)
    end
    return
end
