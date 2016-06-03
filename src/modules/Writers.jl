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


## Documentation Nodes.

function render(io::IO, mime::MIME"text/plain", node::Expanders.DocsNodes, page, doc)
    for node in node.nodes
        render(io, mime, node, page, doc)
    end
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.DocsNode, page, doc)
    # Docstring header based on the name of the binding and it's category.
    anchor = "<a id='$(node.anchor.id)' href='#$(node.anchor.id)'>#</a>"
    header = "**`$(node.object.binding)`** &mdash; *$(Utilities.doccat(node.object))*."
    println(io, anchor, "\n", header, "\n\n")
    # Body. May contain several concatenated docstrings.
    renderdoc(io, mime, node.docstr, page, doc)
end

function renderdoc(io::IO, mime::MIME"text/plain", md::Markdown.MD, page, doc)
    if haskey(md.meta, :results)
        # The `:results` field contains a vector of `Docs.DocStr` objects associated with
        # each markdown object. The `DocStr` contains data such as file and line info that
        # we need for generating correct source links.
        for (markdown, result) in zip(md.content, md.meta[:results])
            render(io, mime, dropheaders(markdown), page, doc)
            # When a source link is available then print the link.
            Utilities.unwrap(Utilities.url(doc.internal.remote, result)) do url
                link = "<a target='_blank' href='$url' class='documenter-source'>source</a><br>"
                println(io, "\n", link, "\n")
            end
        end
    else
        # Docstrings with no `:results` metadata won't contain source locations so we don't
        # try to print them out. Just print the basic docstring.
        render(io, mime, dropheaders(md), page, doc)
    end
end

function renderdoc(io::IO, mime::MIME"text/plain", other, page, doc)
    # TODO: properly support non-markdown docstrings at some point.
    render(io, mime, other, page, doc)
end


## Index, Contents, and Eval Nodes.

function render(io::IO, ::MIME"text/plain", index::Documents.IndexNode, page, doc)
    Documents.populate!(index, doc)
    for (object, doc, page, mod, cat) in index.elements
        url = string(page, "#", Utilities.slugify(object))
        println(io, "- [`", object.binding, "`](", url, ")")
    end
    println(io)
end

function render(io::IO, ::MIME"text/plain", contents::Documents.ContentsNode, page, doc)
    Documents.populate!(contents, doc)
    for (count, path, anchor) in contents.elements
        header = anchor.object
        url    = string(path, '#', anchor.id, '-', anchor.nth)
        link   = Markdown.Link(header.text, url)
        level  = Utilities.header_level(header)
        print(io, "    "^(level - 1), "- ")
        Markdown.plaininline(io, link)
        println(io)
    end
    println(io)
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.EvalNode, page, doc)
    render(io, mime, node.result, page, doc)
end


## Basic Nodes. AKA: any other content that hasn't been handled yet.

function render(io::IO, ::MIME"text/plain", other, page, doc)
    println(io)
    Markdown.plain(io, other)
    println(io)
end

render(io::IO, ::MIME"text/plain", str::AbstractString, page, doc) = print(io, str)

# Metadata Nodes get dropped from the final output for every format but are needed throughout
# rest of the build and so we just leave them in place and print a blank line in their place.
render(io::IO, ::MIME"text/plain", node::Expanders.MetaNode, page, doc) = println(io, "\n")


## Markdown Utilities.

# Remove all header nodes from a markdown object and replace them with bold font.
# Only for use in `text/plain` output, since we'll use some css to make these less obtrusive
# in the HTML rendering instead of using this hack.
function dropheaders(md::Markdown.MD)
    out = Markdown.MD()
    out.meta = md.meta
    out.content = map(dropheaders, md.content)
    out
end
dropheaders(h::Markdown.Header) = Markdown.Paragraph(Markdown.Bold(h.text))
dropheaders(v::Vector) = map(dropheaders, v)
dropheaders(other) = other


# LaTeX Output.
# -------------

# TODO

# HTML Output.
# ------------

# TODO


end
