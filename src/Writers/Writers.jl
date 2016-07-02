"""
Provides a rendering function, [`render`](@ref), for writing each supported
[`Formats.Format`](@ref) to file.

Note that currently `Formats.Markdown` is the **only** supported format.

"""
module Writers

import ..Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities

using Compat

"""
A parametric type that allows us to use multiple dispatch to pick the appropriate
writer for each output format.

The parameter `f` should be an instance of the [`Formats.Format`](@ref) enumeration.
"""
immutable Writer{f} end
Writer(f::Formats.Format) = Writer{f}()

"""
Writes a [`Documents.Document`](@ref) object to `.user.build` directory in
the format specified in `.user.format`.

The method should be overloaded in each writer as

    render(::Writer{format}, doc)

where `format` is one of the values of the [`Formats.Format`](@ref) enumeration.
"""
render(doc::Documents.Document) = render(Writer(doc.user.format), doc)

include("MarkdownWriter.jl")
include("HTMLWriter.jl")
include("LaTeXWriter.jl")

end
