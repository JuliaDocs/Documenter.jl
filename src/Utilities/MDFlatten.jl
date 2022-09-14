"""
Provides the [`mdflatten`](@ref) function that can "flatten" Markdown objects into
a string, with formatting etc. stripped.

Note that the tests in `test/mdflatten.jl` should be considered to be the spec
for the output (number of newlines, indents, formatting, etc.).
"""
module MDFlatten

export mdflatten

import ..Utilities

import Markdown:
    MD, BlockQuote, Bold, Code, Header, HorizontalRule,
    Image, Italic, LaTeX, LineBreak, Link, List, Paragraph, Table,
    Footnote, Admonition
using MarkdownAST: MarkdownAST, Node

"""
Convert a Markdown object to a `String` of only text (i.e. not formatting info).

It drop most of the extra information (e.g. language of a code block, URLs)
and formatting (e.g. emphasis, headers). This "flattened" representation can
then be used as input for search engines.
"""
function mdflatten(md)
    io = IOBuffer()
    mdflatten(io, md)
    String(take!(io))
end

mdflatten(io, md) = mdflatten(io, md, md)
mdflatten(io, md::MD, parent) = mdflatten(io, md.content, md)
mdflatten(io, vec::Vector, parent) = map(x -> mdflatten(io, x, parent), vec)
function mdflatten(io, vec::Vector, parent::MD)
    # this special case separates top level blocks with newlines
    for md in vec
        mdflatten(io, md, parent)
        print(io, "\n\n")
    end
end

# Block level MD nodes
mdflatten(io, h::Header{N}, parent) where {N} = mdflatten(io, h.text, h)
mdflatten(io, p::Paragraph, parent) = mdflatten(io, p.content, p)
mdflatten(io, bq::BlockQuote, parent) = mdflatten(io, bq.content, bq)
mdflatten(io, ::HorizontalRule, parent) = nothing
function mdflatten(io, list::List, parent)
    for (idx, li) in enumerate(list.items)
        for (jdx, x) in enumerate(li)
            mdflatten(io, x, list)
            jdx == length(li) || print(io, '\n')
        end
        idx == length(list.items) || print(io, '\n')
    end
end
function mdflatten(io, t::Table, parent)
    for (idx, row) = enumerate(t.rows)
        for (jdx, x) in enumerate(row)
            mdflatten(io, x, t)
            jdx == length(row) || print(io, ' ')
        end
        idx == length(t.rows) || print(io, '\n')
    end
end

# Inline nodes
mdflatten(io, text::AbstractString, parent) = print(io, text)
mdflatten(io, link::Link, parent) = mdflatten(io, link.text, link)
mdflatten(io, b::Bold, parent) = mdflatten(io, b.text, b)
mdflatten(io, i::Italic, parent) = mdflatten(io, i.text, i)
mdflatten(io, i::Image, parent) = print(io, "(Image: $(i.alt))")
mdflatten(io, m::LaTeX, parent) = print(io, replace(m.formula, r"[^()+\-*^=\w\s]" => ""))
mdflatten(io, ::LineBreak, parent) = print(io, '\n')

# Is both inline and block
mdflatten(io, c::Code, parent) = print(io, c.code)

# Special (inline) "node" -- due to JuliaMark's interpolations
mdflatten(io, expr::Union{Symbol,Expr}, parent) = print(io, expr)

mdflatten(io, f::Footnote, parent) = footnote(io, f.id, f.text, f)
footnote(io, id, text::Nothing, parent) = print(io, "[$id]")
function footnote(io, id, text, parent)
    print(io, "[$id]: ")
    mdflatten(io, text, parent)
end

function mdflatten(io, a::Admonition, parent)
    println(io, "$(a.category): $(a.title)")
    mdflatten(io, a.content, a)
end

# mdflatten for MarkdownAST trees
mdflatten(io, node::Node) = mdflatten(io, node, node.element)
# TODO: remove mdflatten_children
mdflatten(io, children::MarkdownAST.NodeChildren) = mdflatten_children(io, children.parent)

function mdflatten_children(io, node::Node)
    # this special case separates top level blocks with newlines
    newlines = isa(node.element, MarkdownAST.Document)
    for child in node.children
        mdflatten(io, child)
        newlines && print(io, "\n\n")
    end
end

mdflatten(io, node::Node, e::MarkdownAST.AbstractElement) = @warn("Unimplemented mdflatted element: $(typeof(e))")

# Most block and inline (container) elements just reduce down to printing out their
# child nodes.
mdflatten(io, node::Node, ::Union{
    MarkdownAST.Document,
    MarkdownAST.Heading,
    MarkdownAST.Paragraph,
    MarkdownAST.BlockQuote,
    MarkdownAST.ThematicBreak,
    MarkdownAST.Link,
    MarkdownAST.Strong,
    MarkdownAST.Emph,
}) = mdflatten_children(io, node)

mdflatten(io, node::Node, ::MarkdownAST.ThematicBreak) = mdflatten_children(io, node)

function mdflatten(io, node::Node, list::MarkdownAST.List)
    for (idx, li) in enumerate(node.children)
        for (jdx, x) in enumerate(li.children)
            mdflatten(io, x)
            jdx == length(li.children) || print(io, '\n')
        end
        idx == length(node.children) || print(io, '\n')
    end
end
function mdflatten(io, node::Node, t::MarkdownAST.Table)
    rows = collect(Iterators.flatten(thtb.children for thtb in node.children))
    for (idx, row) = enumerate(rows)
        for (jdx, x) in enumerate(row.children)
            mdflatten_children(io, x)
            jdx == length(row.children) || print(io, ' ')
        end
        idx == length(rows) || print(io, '\n')
    end
end

# Inline nodes
mdflatten(io, node::Node, e::MarkdownAST.Text) = print(io, e.text)
function mdflatten(io, node::Node, e::MarkdownAST.Image)
    print(io, "(Image: ")
    mdflatten_children(io, node)
    print(io, ")")
end
mdflatten(io, node::Node, m::Union{MarkdownAST.InlineMath, MarkdownAST.DisplayMath}) = print(io, replace(m.math, r"[^()+\-*^=\w\s]" => ""))
mdflatten(io, node::Node, e::MarkdownAST.LineBreak) = print(io, '\n')

# Is both inline and block
mdflatten(io, node::Node, c::Union{MarkdownAST.Code, MarkdownAST.CodeBlock}) = print(io, c.code)

# Special (inline) "node" -- due to JuliaMark's interpolations
mdflatten(io, node::Node, value::MarkdownAST.JuliaValue) = print(io, value.ref)

mdflatten(io, node::Node, f::MarkdownAST.FootnoteLink) = print(io, "[$(f.id)]")
function mdflatten(io, node::Node, f::MarkdownAST.FootnoteDefinition)
    print(io, "[$(f.id)]: ")
    mdflatten_children(io, node)
end

function mdflatten(io, node::Node, a::MarkdownAST.Admonition)
    println(io, "$(a.category): $(a.title)")
    mdflatten_children(io, node)
end

end
