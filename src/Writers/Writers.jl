"""
A module that provides several renderers for `Document` objects. The supported
formats are currently:

  * `:markdown` -- the default format.
  * `:html` -- generates a complete HTML site with navigation and search included.
  * `:latex` -- generates a PDF using LuaLaTeX.

"""
module Writers

import ..Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Selectors,
    Documenter,
    Utilities

using Compat

#
# Format selector definitions.
#

abstract type FormatSelector <: Selectors.AbstractSelector end

abstract type MarkdownFormat <: FormatSelector end
abstract type LaTeXFormat    <: FormatSelector end
abstract type HTMLFormat     <: FormatSelector end

Selectors.order(::Type{MarkdownFormat}) = 1.0
Selectors.order(::Type{LaTeXFormat})    = 2.0
Selectors.order(::Type{HTMLFormat})     = 3.0

Selectors.matcher(::Type{MarkdownFormat}, fmt, _) = fmt === :markdown
Selectors.matcher(::Type{LaTeXFormat},    fmt, _) = fmt === :latex
Selectors.matcher(::Type{HTMLFormat},     fmt, _) = fmt === :html

Selectors.runner(::Type{MarkdownFormat}, _, doc) = MarkdownWriter.render(doc)
Selectors.runner(::Type{LaTeXFormat},    _, doc) = LaTeXWriter.render(doc)
Selectors.runner(::Type{HTMLFormat},     _, doc) = HTMLWriter.render(doc)

"""
Writes a [`Documents.Document`](@ref) object to `.user.build` directory in
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
function render(doc::Documents.Document)
    # Render each format. Additional formats must define an `order`, `matcher`, `runner`, as
    # well as their own rendering methods in a separate module.
    for each in doc.user.format
        Selectors.dispatch(FormatSelector, each, doc)
    end
    # Revert all local links to their original URLs.
    for (link, url) in doc.internal.locallinks
        link.url = url
    end
end

include("MarkdownWriter.jl")
include("HTMLWriter.jl")
include("LaTeXWriter.jl")

end
