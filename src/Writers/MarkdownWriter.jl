"""
A module for rendering `Document` objects to markdown.
"""
module MarkdownWriter

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities

import Compat
import Compat.Markdown

function render(doc::Documents.Document)
    copy_assets(doc)
    mime = Formats.mimetype(:markdown)
    for (src, page) in doc.internal.pages
        open(Formats.extension(:markdown, page.build), "w") do io
            for elem in page.elements
                node = page.mapping[elem]
                render(io, mime, node, page, doc)
            end
        end
    end
end

function copy_assets(doc::Documents.Document)
    Utilities.log(doc, "copying assets to build directory.")
    assets = joinpath(doc.internal.assets, "mkdocs")
    if isdir(assets)
        builddir = joinpath(doc.user.build, "assets")
        isdir(builddir) || mkdir(builddir)
        for each in readdir(assets)
            src = joinpath(assets, each)
            dst = joinpath(builddir, each)
            ispath(dst) && Utilities.warn("Overwriting '$dst'.")
            Compat.cp(src, dst; force = true)
        end
    else
        error("assets directory '$(abspath(assets))' is missing.")
    end
end

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

function render(io::IO, mime::MIME"text/plain", node::Documents.DocsNodes, page, doc)
    for node in node.nodes
        render(io, mime, node, page, doc)
    end
end

function render(io::IO, mime::MIME"text/plain", node::Documents.DocsNode, page, doc)
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
            url = Utilities.url(doc.internal.remote, doc.user.repo, result)
            if url !== nothing
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
    for (object, _, page, mod, cat) in index.elements
        page = Formats.extension(:markdown, page)
        url = string(page, "#", Utilities.slugify(object))
        println(io, "- [`", object.binding, "`](", url, ")")
    end
    println(io)
end

function render(io::IO, ::MIME"text/plain", contents::Documents.ContentsNode, page, doc)
    for (count, path, anchor) in contents.elements
        path = Formats.extension(:markdown, path)
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

function render(io::IO, mime::MIME"text/plain", node::Documents.EvalNode, page, doc)
    node.result === nothing ? nothing : render(io, mime, node.result, page, doc)
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
render(io::IO, ::MIME"text/plain", node::Documents.MetaNode, page, doc) = println(io, "\n")

function render(io::IO, ::MIME"text/plain", raw::Documents.RawNode, page, doc)
    raw.name === :html ? println(io, "\n", raw.text, "\n") : nothing
end


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
dropheaders(h::Markdown.Header) = Markdown.Paragraph([Markdown.Bold(h.text)])
dropheaders(v::Vector) = map(dropheaders, v)
dropheaders(other) = other

end
