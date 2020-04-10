"""
Provides types and functions to work with Markdown syntax trees.

The module is similar to the [Markdown standard library](https://docs.julialang.org/en/v1/stdlib/Markdown/),
but aims to be stricter and provide a more well-defined API.

!!! note
    Markdown2 does not provide a parser, just a data structure to represent Markdown ASTs.

# Markdown nodes

The types in this module represent the different types of nodes you can have in a Markdown
abstract syntax tree (AST). Currently it supports all the nodes necessary to represent Julia
flavored Markdown. But having this as a separate module from the Markdown standard library
allows us to consistently extend the node type we support (e.g. to support the raw HTML
nodes from [CommonMark](https://spec.commonmark.org/0.29/#raw-html), or strikethrough text
from [GitHub Flavored Markdown](https://github.github.com/gfm/#strikethrough-extension-)).

Markdown nodes split into to two different classes: [block nodes and inline
nodes](https://spec.commonmark.org/0.29/#blocks-and-inlines). Generally, the direct children
of a particular node can only be either inline or block (e.g. paragraphs contain inline
nodes, admonitions contain block nodes as direct children).

In Markdown2, this is represented using a simple type hierarchy. All Markdown nodes are
subtypes of either the [`MarkdownBlockNode`](@ref) or the [`MarkdownInlineNode`](@ref)
abstract type. Both of these abstract types themselves are a subtype of the
[`MarkdownNode`](@ref).

# Additional methods

* The `Base.convert(::Type{Markdown2.MD}, md::Markdown.MD)` method can be used to convert
  the Julia Markdown standard libraries ASTs into Markdown2 ASTs.
* The [`walk`](@ref) function can be used for walking over a [`Markdown2.MD`](@ref) tree.
"""
module Markdown2
using DocStringExtensions
import Markdown


# Abstract type hierarchy for Markdown nodes
# ==========================================
"""
    abstract type MarkdownNode

Supertype for all Markdown nodes.
"""
abstract type MarkdownNode end

"""
    abstract type MarkdownBlockNode <: MarkdownNode

Supertype for all block-level Markdown nodes.
"""
abstract type MarkdownBlockNode <: MarkdownNode end

"""
    abstract type MarkdownInlineNode <: MarkdownNode

Supertype for all inline Markdown nodes.
"""
abstract type MarkdownInlineNode <: MarkdownNode end

# Concrete types representing markdown nodes
# ==========================================
"""
    struct MD

The root node of a Markdown document. Its children are a list of top-level block-type nodes.
Note that `MD` is not a subtype of `MarkdownNode`.
"""
struct MD
    nodes :: Vector{MarkdownBlockNode}

    MD(content::AbstractVector) = new(content)
end
MD() = MD([])

# Forward some array methods
Base.push!(md::MD, x) = push!(md.nodes, x)
Base.getindex(md::MD, args...) = md.nodes[args...]
Base.setindex!(md::MD, args...) = setindex!(md.nodes, args...)
Base.lastindex(md::MD) = endof(md.nodes)
Base.length(md::MD) = length(md.nodes)
Base.isempty(md::MD) = isempty(md.nodes)


# Block nodes
# -----------
"""
    struct ThematicBreak <: MarkdownBlockNode

A block node represeting a thematic break (a `<hr>` tag).
"""
struct ThematicBreak <: MarkdownBlockNode end

struct Heading <: MarkdownBlockNode
    level :: Int
    nodes :: Vector{MarkdownInlineNode}

    function Heading(level::Integer, nodes::Vector{MarkdownInlineNode})
        @assert 1 <= level <= 6 # TODO: error message
        new(level, nodes)
    end
end

struct CodeBlock <: MarkdownBlockNode
    language :: String
    code :: String
end

#struct HTMLBlock <: MarkdownBlockNode end # the parser in Base does not support this currently
#struct LinkDefinition <: MarkdownBlockNode end # the parser in Base does not support this currently

"""
    struct Paragraph <: MarkdownBlockNode

Represents a paragraph block-type node. Its children are inline nodes.
"""
struct Paragraph <: MarkdownBlockNode
    nodes :: Vector{MarkdownInlineNode}
end

## Container blocks
struct BlockQuote <: MarkdownBlockNode
    nodes :: Vector{MarkdownBlockNode}
end

"""
    struct List <: MarkdownBlockNode

If `.orderedstart` is `nothing` then the list is unordered. Otherwise is specifies the first
number in the list.
"""
struct List <: MarkdownBlockNode
    tight :: Bool
    orderedstart :: Union{Int, Nothing}
    items :: Vector{Vector{MarkdownBlockNode}} # TODO: Better types?
end

# Non-Commonmark extensions
struct DisplayMath <: MarkdownBlockNode
    formula :: String
end

struct Footnote <: MarkdownBlockNode
    id :: String
    nodes :: Vector{MarkdownBlockNode} # Footnote is a container block
end

struct Table <: MarkdownBlockNode
    align :: Vector{Symbol}
    cells :: Array{Vector{MarkdownInlineNode}, 2} # TODO: better type?
    # Note: Table is _not_ a container type -- the cells can only contan inlines.
end

struct Admonition <: MarkdownBlockNode
    category :: String
    title :: String
    nodes :: Vector{MarkdownBlockNode} # Admonition is a container block
end

# Inline nodes
# ------------

struct Text <: MarkdownInlineNode
    text :: String
end

struct CodeSpan <: MarkdownInlineNode
    code :: String
end

struct Emphasis <: MarkdownInlineNode
    nodes :: Vector{MarkdownInlineNode}
end

struct Strong <: MarkdownInlineNode
    nodes :: Vector{MarkdownInlineNode}
end

struct Link <: MarkdownInlineNode
    destination :: String
    #title :: String # the parser in Base does not support this currently
    nodes :: Vector{MarkdownInlineNode}
end

struct Image <: MarkdownInlineNode
    destination :: String
    description :: String
    #title :: String # the parser in Base does not support this currently
    #nodes :: Vector{MarkdownInlineNode} # the parser in Base does not parse the description currently
end
#struct InlineHTML <: MarkdownInlineNode end # the parser in Base does not support this currently
struct LineBreak <: MarkdownInlineNode end

# Non-Commonmark extensions
struct InlineMath <: MarkdownInlineNode
    formula :: String
end

struct FootnoteReference <: MarkdownInlineNode
    id :: String
end


# Conversion methods
# ==================
"""
    convert(::Type{MD}, md::Markdown.MD) -> Markdown2.MD

Converts a Markdown standard library AST into a Markdown2 AST.
"""
function Base.convert(::Type{MD}, md::Markdown.MD)
    nodes = map(_convert_block, md.content)
    MD(nodes)
end

_convert_block(xs::Vector) = MarkdownBlockNode[_convert_block(x) for x in xs]
_convert_block(b::Markdown.HorizontalRule) = ThematicBreak()
function _convert_block(b::Markdown.Header{N}) where N
    text = _convert_inline(b.text)
    # Empty headings have just an empty String as text
    nodes = isa(text, AbstractVector) ? text : MarkdownInlineNode[text]
    Heading(N, nodes)
end
_convert_block(b::Markdown.Code) = CodeBlock(b.language, b.code)
_convert_block(b::Markdown.Paragraph) = Paragraph(_convert_inline(b.content))
_convert_block(b::Markdown.BlockQuote) = BlockQuote(_convert_block(b.content))
function _convert_block(b::Markdown.List)
    tight = all(isequal(1), length.(b.items))
    orderedstart = (b.ordered == -1) ? nothing : b.ordered
    List(tight, orderedstart, _convert_block.(b.items))
end

# Non-Commonmark extensions
_convert_block(b::Markdown.LaTeX) = DisplayMath(b.formula)
_convert_block(b::Markdown.Footnote) = Footnote(b.id, _convert_block(b.text))
function _convert_block(b::Markdown.Table)
    @assert all(isequal(length(b.align)), length.(b.rows)) # TODO: error
    cells = [_convert_inline(b.rows[i][j]) for i = 1:length(b.rows), j = 1:length(b.align)]
    Table(
        b.align,
        [_convert_inline(b.rows[i][j]) for i = 1:length(b.rows), j = 1:length(b.align)]
    )
end
_convert_block(b::Markdown.Admonition) = Admonition(b.category, b.title, _convert_block(b.content))

# Fallback
function _convert_block(x)
    @debug "Strange inline Markdown node (typeof(x) = $(typeof(x))), falling back to repr()" x
    Paragraph([Text(repr(x))])
end

_convert_inline(xs::Vector) = MarkdownInlineNode[_convert_inline(x) for x in xs]
_convert_inline(s::String) = Text(s)
function _convert_inline(s::Markdown.Code)
    @assert isempty(s.language) # TODO: error
    CodeSpan(s.code)
end
_convert_inline(s::Markdown.Bold) = Strong(_convert_inline(s.text))
_convert_inline(s::Markdown.Italic) = Emphasis(_convert_inline(s.text))
function _convert_inline(s::Markdown.Link)
    text = _convert_inline(s.text)
    # Autolinks (the `<URL>` syntax) yield Link objects where .text is just a String
    nodes = isa(text, AbstractVector) ? text : [text]
    Link(s.url, nodes)
end
_convert_inline(s::Markdown.Image) = Image(s.url, s.alt)
# struct InlineHTML <: MarkdownInlineNode end # the parser in Base does not support this currently
_convert_inline(::Markdown.LineBreak) = LineBreak()

# Non-Commonmark extensions
_convert_inline(s::Markdown.LaTeX) = InlineMath(s.formula)
function _convert_inline(s::Markdown.Footnote)
    @assert s.text === nothing # footnote references should not have any content, TODO: error
    FootnoteReference(s.id)
end

# Fallback
function _convert_inline(x)
    @debug "Strange inline Markdown node (typeof(x) = $(typeof(x))), falling back to repr()" x
    Text(repr(x))
end


# walk() function
# ===============
"""
    walk(f, element)

Calls `f(element)` on `element` and any of its child elements. The elements are assumed to
be [`Markdown2`](@ref) elements.
"""
function walk end

function walk(f, node::T) where {T <: Union{MarkdownNode, MD}}
    f(node) || return
    if :nodes in fieldnames(T)
        walk(f, node.nodes)
    end
    return
end

function walk(f, nodes::Vector)
    for node in nodes
        walk(f, node)
    end
end

function walk(f, list::List)
    f(list) || return
    for item in list.items
        walk(f, item)
    end
end

function walk(f, table::Table)
    f(table) || return
    for cell in table.cells
        walk(f, cell)
    end
end
end
