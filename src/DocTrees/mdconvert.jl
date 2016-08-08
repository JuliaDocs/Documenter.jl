module MarkdownConverter

import ..DocTrees: Metadata, Node, @tags

@tags div strong pre code hr img em span br a ol ul li p table th tr td blockquote

import Base.Markdown:

    Admonition,
    BlockQuote,
    Bold,
    Code,
    Footnote,
    Header,
    HorizontalRule,
    Image,
    Italic,
    LaTeX,
    LineBreak,
    Link,
    List,
    MD,
    Paragraph,
    Table,
    isordered

# Entry point. Node `n` is it's own parent.
mdconvert(n) = mdconvert(n, n)

mdconvert(s::AbstractString, parent) = Node(s)

mdconvert(v::Vector, parent) = [mdconvert(x, parent) for x in v]

function mdconvert(m::MD, parent)
    local metadata = Metadata(filter((k, v) -> !(k in (:config, :results)), m.meta)...)
    div(metadata, mdconvert(m.content, m))
end

mdconvert(b::Bold, parent) = strong(mdconvert(b.text, b))

function mdconvert(c::Code, ::MD)
    local language = isempty(c.language) ? "none" : c.language
    return pre(Metadata(:code => c.language), code[".language-$(language)"](c.code))
end
mdconvert(c::Code, parent) = code(c.code)

mdconvert{N}(h::Header{N}, parent) = Node(Symbol(:h, N), mdconvert(h.text, h))

mdconvert(::HorizontalRule, parent) = hr()

mdconvert(i::Image, parent) = img[:src => i.url, :alt => i.alt]

mdconvert(i::Italic, parent) = em(mdconvert(i.text, i))

mdconvert(b::BlockQuote, parent) = blockquote(mdconvert(b.content, b))

mdconvert(m::LaTeX, ::Paragraph) = span[".inline-math"]("\\($(m.formula)\\)")
mdconvert(m::LaTeX, parent) = div[".display-math"]("\\[$(m.formula)\\]")

mdconvert(::LineBreak, parent) = br()

mdconvert(l::Link, parent) = a[:href => l.url](mdconvert(l.text, l))

function mdconvert(l::List, parent)
    local items = map(li, mdconvert(l.items, l))
    if isordered(l)
        return ol[:start => string(l.ordered)](
            Metadata(:list => l.ordered), items
        )
    else
        return ul(items)
    end
end

mdconvert(t::Paragraph, parent) = p(mdconvert(t.content, t))

function mdconvert(t::Table, parent)
    local align = t.align
    local header = tr(map(column -> th(mdconvert(column, t)), t.rows[1]))
    local rows = Node[]
    for row in t.rows[2:end]
        push!(rows, tr(
                [
                    td[:style => "text-align:$(alignment(align[n]))"](mdconvert(column, t))
                    for (n, column) in enumerate(row)
                ]
            )
        )
    end
    return table(Metadata(:table => align), header, rows)
end
alignment(s::Symbol) = s === :l ? "left" : s === :r ? "right" : s === :c ? "center" : "left"

mdconvert(f::Footnote, parent) = footnote(f.id, f.text, parent)
footnote(id, ::Void, parent) = a[:href => "#footnote-$(id)"](Metadata(:footnote => id), "[$(id)]")
footnote(id, text, parent) = div[".footnote#footnote-$(id)"](Metadata(:footnote => id), mdconvert(text, parent))

mdconvert(a::Admonition, parent) =
    div[".admonition.$(a.category)"](
        Metadata(:admonition => (a.title, a.category)),
        p[".admonition-title"](a.title),
        mdconvert(a.content, a),
    )

end
