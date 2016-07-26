"""
Provides the [`render`](@ref) methods to write the documentation as HTML files
(`MIME"text/html"`).
"""
module HTMLWriter

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities

import ..Writers: Writer, render
import ...Utilities.DOM: DOM, Tag, @tags

# TODO

function render(::Writer{Formats.HTML}, doc::Documents.Document)
    error("HTML rendering is unsupported.")
end

"""
Convert a markdown object to a `DOM.Node` object.

The `parent` argument is passed to allow for context-dependant conversions.
"""
mdconvert(md) = mdconvert(md, md)

mdconvert(text::AbstractString, parent) = DOM.Node(text)

mdconvert(vec::Vector, parent) = [mdconvert(x, parent) for x in vec]

mdconvert(md::Markdown.MD, parent) = Tag(:div)(mdconvert(md.content, md))

mdconvert(b::Markdown.BlockQuote, parent) = Tag(:blockquote)(mdconvert(b.content, b))

mdconvert(b::Markdown.Bold, parent) = Tag(:strong)(mdconvert(b.text, parent))

function mdconvert(c::Markdown.Code, parent::Markdown.MD)
    @tags pre code
    language = isempty(c.language) ? "none" : c.language
    pre(code[".language-$(language)"](c.code))
end
mdconvert(c::Markdown.Code, parent) = Tag(:code)(c.code)

mdconvert{N}(h::Markdown.Header{N}, parent) = DOM.Tag(Symbol("h$N"))(mdconvert(h.text, h))

mdconvert(::Markdown.HorizontalRule, parent) = Tag(:hr)()

mdconvert(i::Markdown.Image, parent) = Tag(:img)[:src => i.url, :alt => i.alt]

mdconvert(i::Markdown.Italic, parent) = Tag(:em)(mdconvert(i.text, i))

mdconvert(m::Markdown.LaTeX, ::Markdown.MD)   = Tag(:div)(string("\\[", m.formula, "\\]"))
mdconvert(m::Markdown.LaTeX, parent) = Tag(:span)(string('$', m.formula, '$'))

mdconvert(::Markdown.LineBreak, parent) = Tag(:br)()

mdconvert(link::Markdown.Link, parent) = Tag(:a)[:href => link.url](mdconvert(link.text, link))

mdconvert(list::Markdown.List, parent) = (isordered(list) ? Tag(:ol) : Tag(:ul))(map(Tag(:li), mdconvert(list.items, list)))

mdconvert(paragraph::Markdown.Paragraph, parent) = Tag(:p)(mdconvert(paragraph.content, paragraph))

mdconvert(t::Markdown.Table, parent) = Tag(:table)(
    Tag(:tr)(map(_ -> Tag(:th)(mdconvert(_, t)), t.rows[1])),
    map(_ -> Tag(:tr)(map(__ -> Tag(:td)(mdconvert(__, _)), _)), t.rows[2:end])
)

# Only available on Julia 0.5.
if isdefined(Base.Markdown, :Footnote)
    mdconvert(f::Markdown.Footnote, parent)   = footnote(f.id, f.text, parent)
    footnote(id, text::Void, parent) = Tag(:a)[:href => "#footnote-$(id)"]("[$id]")
    footnote(id, text,       parent) = Tag(:span)["#footnote-$(id)"](mdconvert(text, parent))
end

if isdefined(Base.Markdown, :Admonition)
    function mdconvert(a::Markdown.Admonition, parent)
        @tags div p
        div[".admonition.$(a.category)"](
            p[".admonition-title"](a.title),
            mdconvert(a.content, a),
        )
    end
end

if isdefined(Base.Markdown, :isordered)
    import Base.Markdown: isordered
else
    isordered(a::Markdown.List) = a.ordered::Bool
end

end
