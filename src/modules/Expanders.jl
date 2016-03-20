"""
Defines node "expanders" that transform nodes from the parsed markdown files.
"""
module Expanders

import ..Lapidary:

    Anchors,
    Builder,
    Documents,
    Formats,
    Utilities

using Compat

# Basic driver definitions.
# -------------------------

"""
    expand(ex, doc)

Expands each node of a [`Documents.Document`]({ref}) using the expanders provided by `ex`.
"""
function expand(ex::Builder.ExpandTemplates, doc::Documents.Document)
    for (src, page) in doc.internal.pages
        empty!(page.globals.meta)
        for element in page.elements
            expand(ex.expanders, element, page, doc)
        end
    end
end

function expand(pipeline, elem, page, doc)
    expand(Builder.car(pipeline), elem, page, doc)::Bool && return
    expand(Builder.cdr(pipeline), elem, page, doc)
end
expand(::Builder.Expander, elem, page, doc) = false

# Default to mapping each element to itself.
expand(::Tuple{}, elem, page, doc) = (page.mapping[elem] = elem; true)

# Implementations.
# ----------------

const NAMEDHEADER_REGEX = r"^{ref#([^{}]+)}$"

function namedheader(h::Markdown.Header)
    isa(h.text, Vector) &&
    length(h.text) === 1 &&
    isa(h.text[1], Markdown.Link) &&
    ismatch(NAMEDHEADER_REGEX, h.text[1].url)
end

function expand(::Builder.TrackHeaders, header::Base.Markdown.Header, page, doc)
    # Get the header slug.
    text =
        if namedheader(header)
            url = header.text[1].url
            header.text = header.text[1].text
            match(NAMEDHEADER_REGEX, url)[1]
        else
            sprint(Markdown.plain, Markdown.Paragraph(header.text))
        end
    slug = Utilities.slugify(text)
    # Add the header to the document's header map.
    anchor = Anchors.add!(doc.internal.headers, header, slug, page.build)
    # Map the header element to the generated anchor and the current anchor count.
    page.mapping[header] = anchor
    return true
end

immutable MetaNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.MetaBlocks, x::Base.Markdown.Code, page, doc)
    startswith(x.code, "{meta}") || return false
    meta = page.globals.meta
    for (ex, str) in Utilities.parseblock(x.code; skip = 1)
        Utilities.isassign(ex) && (meta[ex.args[1]] = eval(current_module(), ex.args[2]))
    end
    page.mapping[x] = MetaNode(copy(meta))
    return true
end

immutable DocsNode
    docstr :: Any
    anchor :: Anchors.Anchor
    object :: Utilities.Object
    page   :: Documents.Page
end
immutable DocsNodes
    nodes :: Vector{DocsNode}
end
function expand(::Builder.DocsBlocks, x::Base.Markdown.Code, page, doc)
    startswith(x.code, "{docs}") || return false
    failed = false
    nodes  = DocsNode[]
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    for (ex, str) in Utilities.parseblock(x.code; skip = 1)
        # Find the documented object and it's docstring.
        object   = eval(curmod, Utilities.object(ex, str))
        docstr   = eval(curmod, Utilities.docs(ex, str))
        slug     = Utilities.slugify(string(object))

        # Remove docstrings that are not from the user-specified list of modules.
        filtered = Utilities.filterdocs(docstr, doc.user.modules)

        # Error Checking.
        let name = strip(str),
            nodocs = Utilities.nodocs(docstr),
            dupdoc = haskey(doc.internal.objects, object),
            nuldoc = isnull(filtered)

            nodocs && Utilities.warn(page.source, "No docs found for '$name'.")
            dupdoc && Utilities.warn(page.source, "Duplicate docs found for '$name'.")
            nuldoc && Utilities.warn(page.source, "No docs for '$object' from provided modules.")

            # When an warning is raise here we discard all found docs from the `{docs}` and
            # just map the element `x` back to itself and move on to the next element.
            (failed = failed || nodocs || dupdoc || nuldoc) && continue
        end

        # Update `doc` with new object and anchor.
        docstr   = get(filtered)
        anchor   = Anchors.add!(doc.internal.docs, object, slug, page.build)
        docsnode = DocsNode(docstr, anchor, object, page)
        doc.internal.objects[object] = docsnode
        push!(nodes, docsnode)
    end
    page.mapping[x] = failed ? x : DocsNodes(nodes)
    return true
end

immutable EvalNode
    code   :: Base.Markdown.Code
    result :: Any
end
function expand(::Builder.EvalBlocks, x::Base.Markdown.Code, page, doc)
    startswith(x.code, "{eval}") || return false
    sandbox = Module(:EvalBlockSandbox)
    cd(dirname(page.build)) do
        result = nothing
        for (ex, str) in Utilities.parseblock(x.code; skip = 1)
            result = eval(sandbox, ex)
        end
        page.mapping[x] = EvalNode(x, result)
    end
    return true
end

immutable IndexNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.IndexBlocks, x::Base.Markdown.Code, page, doc)
    startswith(x.code, "{index}") || return false
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    dict   = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(x.code; skip = 1)
        Utilities.isassign(ex) && (dict[ex.args[1]] = eval(curmod, ex.args[2]))
    end
    page.mapping[x] = IndexNode(dict)
    return true
end

immutable ContentsNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.ContentsBlocks, x::Base.Markdown.Code, page, doc)
    startswith(x.code, "{contents}") || return false
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    dict   = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(x.code; skip = 1)
        Utilities.isassign(ex) && (dict[ex.args[1]] = eval(curmod, ex.args[2]))
    end
    page.mapping[x] = ContentsNode(dict)
    return true
end

end
