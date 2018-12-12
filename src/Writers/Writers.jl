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
    Documenter,
    Utilities

import .Utilities: Selectors

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

Selectors.matcher(::Type{MarkdownFormat}, fmt, _) = isa(fmt, MarkdownWriter.Markdown)
Selectors.matcher(::Type{LaTeXFormat},    fmt, _) = isa(fmt, LaTeXWriter.LaTeX)
Selectors.matcher(::Type{HTMLFormat},     fmt, _) = isa(fmt, HTMLWriter.HTML)

Selectors.runner(::Type{MarkdownFormat}, fmt, doc) = MarkdownWriter.render(doc, fmt)
Selectors.runner(::Type{LaTeXFormat},    fmt, doc) = LaTeXWriter.render(doc, fmt)
Selectors.runner(::Type{HTMLFormat},     fmt, doc) = HTMLWriter.render(doc, fmt)

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
        if isa(each, MarkdownWriter.Markdown) && !backends_enabled[:markdown]
            @warn """Deprecated format

            The Markdown/MkDocs backend must now be imported from a separate package.
            Add DocumenterMarkdown to your documentation dependencies and add

                using DocumenterMarkdown

            to your make.jl script, and use

                makedocs(
                    format = Markdown(),
                    ...
                )

            in the call to `makedocs`.
            Built-in support for markdown outpu will be removed completely in a future
            Documenter version, causing builds to fail completely.

            See the Output Backends section in the manual for more information.
            """
        elseif isa(each, LaTeXWriter.LaTeX) && !backends_enabled[:latex]
            @warn """Deprecated format

            The LaTeX/PDF backend must now be imported from a separate package.
            Add DocumenterLaTeX to your documentation dependencies and add

                using DocumenterLaTeX

            to your make.jl script, and use

                makedocs(
                    format = LaTeX(),
                    ...
                )

            in the call to `makedocs`.
            Built-in support for LaTeX/PDF output will be removed completely in a future
            Documenter version, causing builds to fail completely.

            See the Output Backends section in the manual for more information.
            """
        end
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

# This is hack to enable shell packages that would behave as in the supplementary Writer
# modules have been moved out of Documenter.
#
# External packages DocumenterMarkdown and DocumenterLaTeX can use the enable_backend
# function to mark that a certain backend is loaded in backends_enabled. That is used to
# determine whether a deprecation warning should be printed in the render method above.
#
# enable_backend() is not part of the API and will be removed as soon as LaTeXWriter and
# MarkdownWriter are actually moved out into a separate module (TODO).
backends_enabled = Dict(
    :markdown => false,
    :latex => false
)

function enable_backend(backend::Symbol)
    global backends_enabled
    if backend in keys(backends_enabled)
        backends_enabled[backend] = true
    else
        @error "Unknown backend. Expected one of:" keys(backends_enabled)
        throw(ArgumentError("Unknown backend $backend."))
    end
end

end
