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
        open(Formats.extension(doc.user.format, page.build), "w") do io
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

"""Wrap a string `str` in a `<span class="<cls>">`."""
span(cls,str) = "<span class=\"$(cls)\">$(str)</span>"

"""
Converts the function argument tuple `(name, type)` into a string.

The tuple comes from the second return element of the `Base.arg_decl_parts(::Method)`
and it seems they are always both `::String` (`::ASCIIString` in 0.4).
It also appears that if the type is not declared for the method, `arg_decl_parts`
returns an empty string.

The returned string is `name::type` or just `name`, if the type is not declared.

If the keyword argument `html` is true (default), then it also puts `<span>`s
around the characters for code highlighting.
"""
function join_decl(decl; html::Bool=true)
    n, t = decl
    if html
        isempty(t) ? span(:n,n) : span(:n,n) * span(:p,"::") * span(:n,t)
    else
        isempty(t) ? n : "$(n)::$(t)"
    end
end

function render(io::IO, mime::MIME"text/plain", node::Expanders.DocsNode, page, doc)
    # Docstring header based on the name of the binding and it's category.
    anchor = "<a id='$(node.anchor.id)' href='#$(node.anchor.id)'>#</a>"
    header = "**`$(node.object.binding)`** &mdash; *$(Utilities.doccat(node.object))*."
    println(io, anchor, "\n", header, "\n\n")
    # Body. May contain several concatenated docstrings.
    renderdoc(io, mime, node.docstr, page, doc)

    # Table of methods.
    # If DocsNode.methods is nulled, then we assume that we should not render a
    # table. However, if the list of methods is there but has no elements then
    # we output an appropriate note saying that the name has no methods associated
    # with it.
    Utilities.unwrap(node.methods) do methodnodes
        name = node.object.binding.var # name of the method without the modules

        # We filter out the methods that are marked `visible`
        ms = [m.method for m in filter(m -> m.visible, methodnodes)]

        println(io, "<strong>Methods</strong>\n")

        # We print a small notice of the methods table is completely empty,
        # and an unordered list of methods if there are some to display.
        if isempty(methodnodes)
            println(io, "This function has no methods.\n")
        elseif isempty(ms)
            println(io, "This function has no methods to display.\n")
        else
            # A regexp to match filenames with an absolute path
            r = Regex("$(Pkg.dir())/([A-Za-z0-9]+)/(.*)")

            print(io, """
            <ul class="documenter-methodtable">
            """)

            for m in ms
                tv, decls, file, line = Base.arg_decl_parts(m)
                decls = decls[2:end]
                file = string(file)
                url = get(Utilities.url(doc.internal.remote, m.module, file, line), "")
                file_match = match(r, file)
                if file_match !== nothing
                    file = file_match.captures[2]
                end
                # We'll generate the HTML now.
                #
                # We also apply code highlighting that tries to be consistent with
                # how the code blocks are highlighted in mkdocs. In a nutshell, all
                # characters have to be wrapped in <span>s with specific classes.
                # The classes seem to have the following semantics:
                #
                #   - p   punctuation, e.g. {} () :: ,.
                #   - k   keyword, e.g. type, return
                #   - nf  function name, in a function definition
                #   - n   name (generally, as used in code)
                #
                # TODO: the type expressions (in typevars or after ::) are colored
                #       as normal names, but it would be nice to have them properly
                #       highlighted (e.g. if there's a string in the type name,
                #       like in MIME"text/html")
                #
                tvars = isempty(tv) ? "" :
                    span(:p,"{") * join([span(:n,t) for t in tv], span(:p,", ")) * span(:p,"}")
                # If the list of arguments is too long (which can happen quite easily
                # due to long type names), we will display them in a multiline block
                # instead.
                args_raw = join([join_decl(d, html=false) for d in decls], span(:p,", "))
                args,preclass = if length(args_raw) <= 50
                    join([join_decl(d) for d in decls], span(:p,", ")),
                    " class=\"documenter-inline\""
                else
                    "\n" * join([(" "^4)*join_decl(d) for d in decls], span(:p,",\n")) * "\n",
                    ""
                end
                print(io, """
                <li>
                    <pre$(preclass)>$(span(:nf,name))$(tvars)$(span(:p,"("))$(args)$(span(:p,")"))</pre>
                    defined at
                    <a target="_blank" href="$(url)">$(file):$(line)</a>
                </li>
                """)
            end
            print(io, "</ul>\n\n")
        end

        # we print a small notice if we are not displaying all the methods
        nh = length(methodnodes)-length(ms) # number of hidden methods
        if nh > 0
            println(io, "_Hiding $(nh) method$(nh==1?"":"s") defined outside of this package._\n")
        end
    end
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

function render(io::IO, ::MIME"text/latex", node, page, doc)
    error("LaTeX rendering is unsupported.")
end

# HTML Output.
# ------------

# TODO

function render(io::IO, ::MIME"text/html", node, page, doc)
    error("HTML rendering is unsupported.")
end

end
