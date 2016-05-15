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

# Driver method for document rendering.
# -------------------------------------

"""
Writes a [`Documents.Document`](@ref) object to `build` directory in specified file format.
"""
function render(doc::Documents.Document)
    mime = Formats.mimetype(doc.user.format)
    for (src, page) in doc.internal.pages
        open(page.build, "w") do io
            for elem in page.elements
                node = page.mapping[elem]
                render(io, mime, node, page, doc)
            end
        end
    end
end

# Markdown Output.
# ----------------

function render(io::IO, mime::MIME"text/plain", vec::Vector, page, doc)
    for each in vec
        render(io, mime, each, page, doc)
    end
end

function render(io::IO, mime::MIME"text/plain", anchor::Anchors.Anchor, page, doc)
    println(io, "\n<a id='", anchor.id, "-", anchor.nth, "'></a>")
    render(io, mime, anchor.object, page, doc)
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.DocsNodes, page, doc)
    for doc in node.nodes
        render(io, mime, doc, page, doc)
    end
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.DocsNode, page, doc)
    println(
        io,
        """
        <a id='$(node.anchor.id)' href='#$(node.anchor.id)'>#</a>
        **`$(node.object.binding)`** &mdash; *$(Utilities.doccat(node.object))*.

        """
    )
    render(io, mime, dropheaders(source_urls(node.docstr)), page, doc)
end

function source_urls(docstr::Base.Markdown.MD)
    if haskey(docstr.meta, :results)
        out = []
        for (md, result) in zip(docstr.content, docstr.meta[:results])
            push!(out, md)
            url = Utilities.url(
                result.data[:module],
                result.data[:path],
                linerange(result.text, result.data[:linenumber]),
            )
            isnull(url) || push!(
                out, "\n<a target='_blank' href='$(get(url))' class='documenter-source'>source</a><br>\n"
            )
        end
        out
    else
        docstr
    end
end
source_urls(other) = other

function linerange(text, from)
    lines = sum([isodd(n) ? newlines(s) : 0 for (n, s) in enumerate(text)])
    lines > 0 ? string(from, '-', from + lines + 1) : string(from)
end

newlines(s::AbstractString) = count(c -> c === '\n', s)
newlines(other) = 0

function render(io::IO, ::MIME"text/plain", index::Expanders.IndexNode, page, doc)
    pages   = get(index.dict, :Pages, [])
    mapping = Dict()
    for (object, docsnode) in doc.internal.objects
        build = docsnode.page.build
        path = relpath(build, dirname(index.dict[:build]))
        push!(get!(mapping, path, []), (path, object))
    end
    pages = isempty(pages) ? sort!(collect(keys(mapping))) : pages
    for page in pages
        if haskey(mapping, page)
            docs = mapping[page]
            for (path, object) in sort!(docs, by = t -> string(t[2]))
                url = string(path, "#", Utilities.slugify(object))
                println(io, "- [`", object.binding, "`](", url, ")")
            end
        end
    end
end

function render(io::IO, ::MIME"text/plain", contents::Expanders.ContentsNode, page, doc)
    pages = get(contents.dict, :Pages, [])
    depth = get(contents.dict, :Depth, 2)
    mapping = Dict()
    for (id, filedict) in doc.internal.headers.map
        for (file, anchors) in filedict
            for anchor in anchors
                path = relpath(anchor.file, dirname(contents.dict[:build]))
                if Utilities.header_level(anchor.object) ≤ depth
                    push!(get!(mapping, path, []), (anchor.order, path, anchor))
                end
            end
        end
    end
    pages = isempty(pages) ? sort!(collect(keys(mapping))) : pages
    for page in pages
        if haskey(mapping, page)
            headers = mapping[page]
            for (count, path, anchor) in sort!(headers, by = first)
                header = anchor.object
                url    = string(path, '#', anchor.id, '-', anchor.nth)
                link   = Markdown.Link(header.text, url)
                level  = Utilities.header_level(header)
                print(io, "    "^(level - 1), "- ")
                Markdown.plaininline(io, link)
                println(io)
            end
        end
    end
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.EvalNode, page, doc)
    render(io, mime, node.result, page, doc)
end

function render(io::IO, ::MIME"text/plain", other, page, doc)
    println(io)
    Markdown.plain(io, other)
    println(io)
end

render(io::IO, ::MIME"text/plain", str::AbstractString, page, doc) = print(io, str)

render(io::IO, ::MIME"text/plain", node::Expanders.MetaNode, page, doc) = println(io, "\n")

# LaTeX Output.
# -------------

# TODO

# HTML Output.
# ------------

# TODO

# Utilities.
# ----------

function dropheaders(md::Markdown.MD)
    out = Markdown.MD()
    out.meta = md.meta
    out.content = map(dropheaders, md.content)
    out
end
dropheaders(h::Markdown.Header) = Markdown.Paragraph(Markdown.Bold(h.text))
dropheaders(v::Vector) = map(dropheaders, v)
dropheaders(other) = other

end
