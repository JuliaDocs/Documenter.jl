"""
Provides the [`crossref`](@ref) function used to automatically calculate link URLs.
"""
module CrossReferences

import ..Documenter:
    Anchors,
    Builder,
    Expanders,
    Documenter

using DocStringExtensions
using .Documenter: Remotes, @docerror
import Markdown
import AbstractTrees, MarkdownAST

"""
$(SIGNATURES)

Traverses a [`Documenter.Document`](@ref) and replaces links containing `@ref` URLs with
their real URLs.
"""
function crossref(doc::Documenter.Document)
    for (src, page) in doc.blueprint.pages
        empty!(page.globals.meta)
        crossref(doc, page, page.mdast)
    end
end

function crossref(doc::Documenter.Document, page, mdast::MarkdownAST.Node)
    for node in AbstractTrees.PreOrderDFS(mdast)
        if node.element isa Documenter.MetaNode
            merge!(page.globals.meta, node.element.dict)
        elseif node.element isa Documenter.DocsNode
            # the docstring AST trees are not part of the tree of the page, so we need to explicitly
            # call crossref() on them to update the links there. We also need up update
            # the CurrentModule meta key as needed, to make sure we find the correct
            # relative refs within docstrings
            tmp = get(page.globals.meta, :CurrentModule, nothing)
            for (docstr, meta) in zip(node.element.mdasts, node.element.metas)
                mod = get(meta, :module, nothing)
                isnothing(mod) || (page.globals.meta[:CurrentModule] = mod)
                crossref(doc, page, docstr)
            end
            if isnothing(tmp)
                delete!(page.globals.meta, :CurrentModule)
            else
                page.globals.meta[:CurrentModule] = tmp
            end
        elseif node.element isa MarkdownAST.Link
            xref(node, page.globals.meta, page, doc)
        elseif node.element isa MarkdownAST.Image
            # Images must be either local or absolute links (no at-ref syntax for those at the moment)
            local_links!(node, page.globals.meta, page, doc)
        end
    end
end

function local_links!(node::MarkdownAST.Node, meta, page, doc)
    @assert node.element isa Union{MarkdownAST.Link, MarkdownAST.Image}
    link_url = node.element.destination
    # If the link is an absolute URL, then there's nothing we need to do. We'll just
    # keep the Link object as is, and it should become an external hyperlink in the writer.
    Documenter.isabsurl(link_url) && return
    # Similarly, mailto: links get passed on
    startswith(link_url, "mailto:") && return

    # Anything else, however, is assumed to be a local URL, and we check that it is
    # actually pointing to a file.
    path, fragment = splitfragment(link_url)
    # Links starting with a # are references within the same file -- so there's not much
    # for us to do here, except to just construct the PageLink object. Note that we do
    # not verify that the fragments are valid -- there might be reasons why people want to
    # use custom fragments, in particular in the HTML output.
    if isempty(path)
        if node.element isa MarkdownAST.Image
            @docerror(
                doc, :cross_references,
                "invalid local image: path missing in $(Documenter.locrepr(page.source))",
                link=node
            )
            return
        end
        node.element = Documenter.PageLink(page, fragment)
        return
    elseif Sys.iswindows() && ':' in path
        @docerror(
            doc, :cross_references,
            "invalid local link/image: colons not allowed in paths on Windows in $(Documenter.locrepr(page.source))",
            link=node
        )
        return
    end
    # This path should be relative to doc.user.build, which is kinda line doc.user.source,
    # since most non-md files get copied to doc.user.build.
    path = normpath(joinpath(dirname(Documenter.pagekey(doc, page)), path))
    if startswith(path, "..")
        @docerror(
            doc, :cross_references,
            "invalid local link/image: path pointing to a file outside of build directory in $(Documenter.locrepr(page.source))",
            link=node
        )
        return
    elseif path in keys(doc.blueprint.pages)
        node.element = Documenter.PageLink(doc.blueprint.pages[path], fragment)
        return
    elseif isfile(joinpath(doc.user.root, doc.user.build, path))
        if endswith(path, ".md")
            @warn "referring to a MD file that is not included in documentation build" path node
        end
        if node.element isa MarkdownAST.Image
            if !isempty(fragment)
                @docerror(
                    doc, :cross_references,
                    "invalid local image: path contains a fragment in $(Documenter.locrepr(page.source))",
                    link=node
                )
            end
            node.element = Documenter.LocalImage(path)
        else
            node.element = Documenter.LocalLink(path, fragment)
        end
        return
    else
        @docerror(
            doc, :cross_references,
            "invalid local link/image: file does not exist in $(Documenter.locrepr(page.source))",
            link=node
        )
        return
    end
end

function splitfragment(s)
    xs = split(s, '#', limit=2)
    xs[1], get(xs, 2, "")
end

# Dispatch to `namedxref` / `docsxref`.
# -------------------------------------

function xref(node::MarkdownAST.Node, meta, page, doc)
    @assert node.element isa MarkdownAST.Link
    link = node.element

    slug = xrefname(link.destination)
    # If the Link does not match an '@ref' link, then this should either be a local link
    # pointing to an existing file in src/ or an absolute URL.
    if isnothing(slug)
        local_links!(node::MarkdownAST.Node, meta, page, doc)
        return
    end
    # If the slug is empty, then this is a "basic" x-ref, without a custom name
    if isempty(slug)
        basicxref(node, meta, page, doc)
        return
    end
    # If `slug` is a string referencing a known header, we'll go for that
    if Anchors.exists(doc.internal.headers, slug)
        namedxref(node, slug, meta, page, doc)
        return
    end
    # Next we'll check if name is a "string", in which case it should refer to human readable
    # heading. We'll slugify the string content, just like in basicxref:
    stringmatch = match(r"\"(.+)\"", slug)
    if !isnothing(stringmatch)
        namedxref(node, Documenter.slugify(stringmatch[1]), meta, page, doc)
        return
    end
    # Finally, we'll assume that the reference is a Julia expression referring to a docstring.
    docref = find_docref(slug, meta, page)
    if haskey(docref, :error)
        # If this is not a valid docref either, we'll call namedxref().
        # This should always throw an error because we already determined that
        # Anchors.exists(doc.internal.headers, slug) is false. But we call it here
        # so that we wouldn't have to duplicate the @docerror call
        namedxref(node, slug, meta, page, doc)
    else
        docsxref(node, slug, meta, page, doc; docref = docref)
    end
end

"""
Parse the `link.url` field of an at-ref link. Returns `nothing` if it's not an at-ref,
an empty string the reference link has no label, or a whitespace-stripped version the
label.
"""
function xrefname(link_url)
    m = match(XREF_REGEX, link_url)
    isnothing(m) && return nothing
    return isnothing(m[1]) ? "" : strip(m[1])
end
const XREF_REGEX = r"^\s*@ref(\s.*)?$"

function basicxref(node::MarkdownAST.Node, meta, page, doc)
    @assert node.element isa MarkdownAST.Link
    if length(node.children) == 1 && isa(first(node.children).element, MarkdownAST.Code)
        docsxref(node, first(node.children).element.code, meta, page, doc)
    else
        # No `name` was provided, since given a `@ref`, so slugify the `.text` instead.
        # TODO: remove this hack (replace with mdflatten?)
        ast = MarkdownAST.@ast MarkdownAST.Document() do
            MarkdownAST.Paragraph() do
                MarkdownAST.copy_tree(node)
            end
        end
        md = convert(Markdown.MD, ast)
        text = strip(sprint(Markdown.plain, Markdown.Paragraph(md.content[1].content[1].text)))
        if occursin(r"#[0-9]+", text)
            issue_xref(node, lstrip(text, '#'), meta, page, doc)
        else
            name = Documenter.slugify(text)
            namedxref(node, name, meta, page, doc)
        end
    end
end

# Cross referencing headers.
# --------------------------

function namedxref(node::MarkdownAST.Node, slug, meta, page, doc)
    @assert node.element isa MarkdownAST.Link
    headers = doc.internal.headers
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[node.element] = node.element.destination
    # Error checking: `slug` should exist and be unique.
    # TODO: handle non-unique slugs.
    if Anchors.exists(headers, slug)
        if Anchors.isunique(headers, slug)
            # Replace the `@ref` url with a path to the referenced header.
            anchor = Anchors.anchor(headers, slug)
            pagekey = relpath(anchor.file, doc.user.build)
            page = doc.blueprint.pages[pagekey]
            node.element = Documenter.PageLink(page, Anchors.label(anchor))
        else
            @docerror(doc, :cross_references, "'$slug' is not unique in $(Documenter.locrepr(page.source)).")
        end
    else
        @docerror(doc, :cross_references, "reference for '$slug' could not be found in $(Documenter.locrepr(page.source)).")
    end
end

# Cross referencing docstrings.
# -----------------------------

function docsxref(node::MarkdownAST.Node, code, meta, page, doc; docref = find_docref(code, meta, page))
    @assert node.element isa MarkdownAST.Link
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[node.element] = node.element.destination

    # We'll bail if the parsing of the docref wasn't successful
    if haskey(docref, :error)
        @docerror(doc, :cross_references, docref.error, exception = docref.exception)
        return
    end
    binding, typesig = docref

    # Try to find a valid object that we can cross-reference.
    object = find_object(doc, binding, typesig)
    if object !== nothing
        # Replace the `@ref` url with a path to the referenced docs.
        docsnode = doc.internal.objects[object]
        slug = Documenter.slugify(object)
        pagekey = relpath(docsnode.page.build, doc.user.build)
        page = doc.blueprint.pages[pagekey]
        node.element = Documenter.PageLink(page, slug)
    else
        @docerror(doc, :cross_references, "no doc found for reference '[`$code`](@ref)' in $(Documenter.locrepr(page.source)).")
    end
end

function find_docref(code, meta, page)
    # Parse the link text and find current module.
    keyword = Symbol(strip(code))
    local ex
    if haskey(Docs.keywords, keyword)
        ex = QuoteNode(keyword)
    else
        try
            ex = Meta.parse(code)
        catch err
            isa(err, Meta.ParseError) || rethrow(err)
            return (error = "unable to parse the reference '[`$code`](@ref)' in $(Documenter.locrepr(page.source)).", exception = nothing)
        end
    end
    mod = get(meta, :CurrentModule, Main)

    # Find binding and type signature associated with the link.
    local binding
    try
        binding = Documenter.DocSystem.binding(mod, ex)
    catch err
        return (
            error = "unable to get the binding for '[`$code`](@ref)' in $(Documenter.locrepr(page.source)) from expression '$(repr(ex))' in module $(mod)",
            exception = (err, catch_backtrace()),
        )
        return
    end

    local typesig
    try
        typesig = Core.eval(mod, Documenter.DocSystem.signature(ex, rstrip(code)))
    catch err
        return (
            error = "unable to evaluate the type signature for '[`$code`](@ref)' in $(Documenter.locrepr(page.source)) from expression '$(repr(ex))' in module $(mod)",
            exception = (err, catch_backtrace()),
        )
        return
    end

    return (binding = binding, typesig = typesig)
end

"""
$(SIGNATURES)

Find the included `Object` in the `doc` matching `binding` and `typesig`. The matching
heuristic isn't too picky about what matches and will only fail when no `Binding`s matching
`binding` have been included.
"""
function find_object(doc::Documenter.Document, binding, typesig)
    object = Documenter.Object(binding, typesig)
    if haskey(doc.internal.objects, object)
        # Exact object matching the requested one.
        return object
    else
        objects = get(doc.internal.bindings, binding, Documenter.Object[])
        if isempty(objects)
            # No bindings match the requested object == FAILED.
            return nothing
        elseif length(objects) == 1
            # Only one possible choice. Use it even if the signature doesn't match.
            return objects[1]
        else
            candidate = find_object(binding, typesig)
            if candidate in objects
                # We've found an actual match out of the possible choices! Use it.
                return candidate
            else
                # No match in the possible choices. Use the one that was first included.
                return objects[1]
            end
        end
    end
end
function find_object(binding, typesig)
    if Documenter.DocSystem.defined(binding)
        local λ = Documenter.DocSystem.resolve(binding)
        return find_object(λ, binding, typesig)
    else
        return Documenter.Object(binding, typesig)
    end
end
function find_object(λ::Union{Function, DataType}, binding, typesig)
    if hasmethod(λ, typesig)
        signature = getsig(λ, typesig)
        return Documenter.Object(binding, signature)
    else
        return Documenter.Object(binding, typesig)
    end
end
find_object(::Union{Function, DataType}, binding, ::Union{Union,Type{Union{}}}) = Documenter.Object(binding, Union{})
find_object(other, binding, typesig) = Documenter.Object(binding, typesig)

getsig(λ::Union{Function, DataType}, typesig) = Base.tuple_type_tail(which(λ, typesig).sig)


# Issues/PRs cross referencing.
# -----------------------------

function issue_xref(node::MarkdownAST.Node, num, meta, page, doc)
    @assert node.element isa MarkdownAST.Link
    # Update issue links starting with a hash, but only if our Remote supports it
    issue_url = isnothing(doc.user.remote) ? nothing : Remotes.issueurl(doc.user.remote, num)
    if isnothing(issue_url)
        @docerror(doc, :cross_references, "unable to generate issue reference for '[`#$num`](@ref)' in $(Documenter.locrepr(page.source)).")
    else
        node.element.destination = issue_url
    end
end

end
