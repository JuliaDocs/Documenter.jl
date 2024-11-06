"""
Provides the [`mdflatten`](@ref) function that can "flatten" Markdown objects into
a string, with formatting etc. stripped.

Note that the tests in `test/mdflatten.jl` should be considered to be the spec
for the output (number of newlines, indents, formatting, etc.).
"""
module MDFlatten

export mdflatten

using MarkdownAST: MarkdownAST, Node

"""
Convert a Markdown object to a `String` of only text (i.e. not formatting info).

It drop most of the extra information (e.g. language of a code block, URLs)
and formatting (e.g. emphasis, headers). This "flattened" representation can
then be used as input for search engines.
"""
mdflatten(node) = sprint(mdflatten, node)

mdflatten(io, node::Node) = mdflatten(io, node, node.element)
mdflatten(io, nodes::Vector{T}) where {T <: Node} = foreach(n -> mdflatten(io, n), nodes)
function mdflatten(io, children::MarkdownAST.NodeChildren)
    # this special case separates top level blocks with newlines
    newlines = isa(children.parent.element, MarkdownAST.Document)
    for child in children
        mdflatten(io, child)
        newlines && print(io, "\n\n")
    end
    return
end

mdflatten(io, node::Node, e::MarkdownAST.AbstractElement) = error("Unimplemented element for mdflatten: $(typeof(e))")

# Most block and inline (container) elements just reduce down to printing out their
# child nodes.
function mdflatten(io, node::Node, ::T) where {
        T <: Union{
            MarkdownAST.Document, MarkdownAST.Heading, MarkdownAST.Paragraph,
            MarkdownAST.BlockQuote, MarkdownAST.Link, MarkdownAST.Strong, MarkdownAST.Emph,
        },
    }
    return mdflatten(io, node.children)
end

function mdflatten(io, node::Node, list::MarkdownAST.List)
    for (idx, li) in enumerate(node.children)
        for (jdx, x) in enumerate(li.children)
            mdflatten(io, x)
            jdx == length(li.children) || print(io, '\n')
        end
        idx == length(node.children) || print(io, '\n')
    end
    return
end
function mdflatten(io, node::Node, t::MarkdownAST.Table)
    rows = collect(Iterators.flatten(thtb.children for thtb in node.children))
    for (idx, row) in enumerate(rows)
        for (jdx, x) in enumerate(row.children)
            mdflatten(io, x.children)
            jdx == length(row.children) || print(io, ' ')
        end
        idx == length(rows) || print(io, '\n')
    end
    return
end

# Inline nodes
mdflatten(io, node::Node, e::MarkdownAST.Text) = print(io, e.text)
function mdflatten(io, node::Node, e::MarkdownAST.Image)
    print(io, "(Image: ")
    mdflatten(io, node.children)
    print(io, ")")
    return
end
mdflatten(io, node::Node, m::Union{MarkdownAST.InlineMath, MarkdownAST.DisplayMath}) = print(io, replace(m.math, r"[^()+\-*^=\w\s]" => ""))
mdflatten(io, node::Node, e::MarkdownAST.LineBreak) = print(io, '\n')
mdflatten(io, node::Node, ::MarkdownAST.ThematicBreak) = nothing

# Is both inline and block
mdflatten(io, node::Node, c::Union{MarkdownAST.Code, MarkdownAST.CodeBlock}) = print(io, c.code)

# Special (inline) "node" -- due to JuliaMark's interpolations
mdflatten(io, node::Node, value::MarkdownAST.JuliaValue) = print(io, value.ref)

mdflatten(io, node::Node, f::MarkdownAST.FootnoteLink) = print(io, "[$(f.id)]")
function mdflatten(io, node::Node, f::MarkdownAST.FootnoteDefinition)
    print(io, "[$(f.id)]: ")
    return mdflatten(io, node.children)
end

function mdflatten(io, node::Node, a::MarkdownAST.Admonition)
    println(io, "$(a.category): $(a.title)")
    return mdflatten(io, node.children)
end

end
