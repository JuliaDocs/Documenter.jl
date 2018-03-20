"""
Provides the [`crossref`](@ref) function used to automatically calculate link URLs.
"""
module CrossReferences

import ..Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities,
    Walkers

using Compat, DocStringExtensions
import Compat.Markdown

"""
$(SIGNATURES)

Traverses a [`Documents.Document`](@ref) and replaces links containg `@ref` URLs with
their real URLs.
"""
function crossref(doc::Documents.Document)
    for (src, page) in doc.internal.pages
        empty!(page.globals.meta)
        for element in page.elements
            crossref(page.mapping[element], page, doc)
        end
    end
end

function crossref(elem, page, doc)
    Walkers.walk(page.globals.meta, elem) do link
        xref(link, page.globals.meta, page, doc)
    end
end

# Dispatch to `namedxref` / `docsxref`.
# -------------------------------------

const NAMED_XREF = r"^@ref (.+)$"

function xref(link::Markdown.Link, meta, page, doc)
    link.url == "@ref"             ? basicxref(link, meta, page, doc) :
    occursin(NAMED_XREF, link.url) ? namedxref(link, meta, page, doc) : nothing
    return false # Stop `walk`ing down this `link` element.
end
xref(other, meta, page, doc) = true # Continue to `walk` through element `other`.

function basicxref(link::Markdown.Link, meta, page, doc)
    if length(link.text) === 1 && isa(link.text[1], Markdown.Code)
        docsxref(link, link.text[1].code, meta, page, doc)
    elseif isa(link.text, Vector)
        # No `name` was provided, since given a `@ref`, so slugify the `.text` instead.
        text = strip(sprint(Markdown.plain, Markdown.Paragraph(link.text)))
        if occursin(r"#[0-9]+", text)
            issue_xref(link, lstrip(text, '#'), meta, page, doc)
        else
            name = Utilities.slugify(text)
            namedxref(link, name, meta, page, doc)
        end
    end
end

# Cross referencing headers.
# --------------------------

function namedxref(link::Markdown.Link, meta, page, doc)
    # Extract the `name` from the `(@ref ...)`.
    slug = match(NAMED_XREF, link.url)[1]
    if isempty(slug)
        text = sprint(Markdown.plaininline, link)
        push!(doc.internal.errors, :cross_references)
        Utilities.warn(page.source, "'$text' missing a name after '#'.")
    else
        if Anchors.exists(doc.internal.headers, slug)
            namedxref(link, slug, meta, page, doc)
        elseif length(link.text) === 1 && isa(link.text[1], Markdown.Code)
            docsxref(link, slug, meta, page, doc)
        else
            namedxref(link, slug, meta, page, doc)
        end
    end
end

function namedxref(link::Markdown.Link, slug, meta, page, doc)
    headers = doc.internal.headers
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[link] = link.url
    # Error checking: `slug` should exist and be unique.
    # TODO: handle non-unique slugs.
    if Anchors.exists(headers, slug)
        if Anchors.isunique(headers, slug)
            # Replace the `@ref` url with a path to the referenced header.
            anchor   = Anchors.anchor(headers, slug)
            path     = relpath(anchor.file, dirname(page.build))
            link.url = string(path, '#', slug, '-', anchor.nth)
        else
            push!(doc.internal.errors, :cross_references)
            Utilities.warn(page.source, "'$slug' is not unique.")
        end
    else
        push!(doc.internal.errors, :cross_references)
        Utilities.warn(page.source, "Reference for '$slug' could not be found.")
    end
end

# Cross referencing docstrings.
# -----------------------------

function docsxref(link::Markdown.Link, code, meta, page, doc)
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[link] = link.url
    # Parse the link text and find current module.
    keyword = Symbol(strip(code))
    local ex
    if haskey(Docs.keywords, keyword)
        ex = QuoteNode(keyword)
    else
        try
            ex = Meta.parse(code)
        catch err
            !isa(err, Meta.ParseError) && rethrow(err)
            push!(doc.internal.errors, :cross_references)
            Utilities.warn(page.source, "Unable to parse the reference '[`$code`](@ref)'.")
            return
        end
    end
    mod = get(meta, :CurrentModule, Main)

    # Find binding and type signature associated with the link.
    local binding
    try
        binding = Documenter.DocSystem.binding(mod, ex)
    catch err
        push!(doc.internal.errors, :cross_references)
        Utilities.warn(page.source, "Unable to get the binding for '[`$code`](@ref)'.", err, ex, mod)
        return
    end

    local typesig
    try
        typesig = eval(mod, Documenter.DocSystem.signature(ex, rstrip(code)))
    catch err
        push!(doc.internal.errors, :cross_references)
        Utilities.warn(page.source, "Unable to evaluate the type signature for '[`$code`](@ref)'.", err, ex, mod)
        return
    end

    # Try to find a valid object that we can cross-reference.
    object = find_object(doc, binding, typesig)
    if object !== nothing
        # Replace the `@ref` url with a path to the referenced docs.
        docsnode = doc.internal.objects[object]
        path     = relpath(docsnode.page.build, dirname(page.build))
        slug     = Utilities.slugify(object)
        link.url = string(path, '#', slug)
    else
        push!(doc.internal.errors, :cross_references)
        Utilities.warn(page.source, "No doc found for reference '[`$code`](@ref)'.")
    end
end

"""
$(SIGNATURES)

Find the included `Object` in the `doc` matching `binding` and `typesig`. The matching
heuristic isn't too picky about what matches and will only fail when no `Binding`s matching
`binding` have been included.
"""
function find_object(doc::Documents.Document, binding, typesig)
    object = Utilities.Object(binding, typesig)
    if haskey(doc.internal.objects, object)
        # Exact object matching the requested one.
        return object
    else
        objects = get(doc.internal.bindings, binding, Utilities.Object[])
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
        return Utilities.Object(binding, typesig)
    end
end
function find_object(λ::Union{Function, DataType}, binding, typesig)
    if hasmethod(λ, typesig)
        signature = getsig(λ, typesig)
        return Utilities.Object(binding, signature)
    else
        return Utilities.Object(binding, typesig)
    end
end
find_object(::Union{Function, DataType}, binding, ::Union{Union,Type{Union{}}}) = Utilities.Object(binding, Union{})
find_object(other, binding, typesig) = Utilities.Object(binding, typesig)

getsig(λ::Union{Function, DataType}, typesig) = Base.tuple_type_tail(which(λ, typesig).sig)


# Issues/PRs cross referencing.
# -----------------------------

function issue_xref(link::Markdown.Link, num, meta, page, doc)
    link.url = isempty(doc.internal.remote) ? link.url :
        "https://github.com/$(doc.internal.remote)/issues/$num"
end

end
