"""
Provides the [`crossref`](@ref) function used to automatically calculate link URLs.
"""
module CrossReferences

import ..Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Documenter,
    Utilities,
    Utilities.@docerror

using DocStringExtensions
using .Utilities: Remotes
import Markdown

"""
$(SIGNATURES)

Traverses a [`Documents.Document`](@ref) and replaces links containg `@ref` URLs with
their real URLs.
"""
function crossref(doc::Documents.Document)
    for (src, page) in doc.blueprint.pages
        empty!(page.globals.meta)
        for element in page.elements
            crossref(page.mapping[element], page, doc)
        end
    end
end

function crossref(elem, page, doc)
    Documents.walk(page.globals.meta, elem) do link
        xref(link, page.globals.meta, page, doc)
    end
end

# Dispatch to `namedxref` / `docsxref`.
# -------------------------------------

function xref(link::Markdown.Link, meta, page, doc)
    # Note: xref will always return `false` to stop `walk`ing down this `link` element.
    slug = xrefname(link.url)
    # If the Link does not match an '@ref' link, we'll silently bail right away -- this is some
    # other link.
    isnothing(slug) && return false
    # If the slug is empty, then this is a "basic" x-ref, without a custom name
    if isempty(slug)
        basicxref(link, meta, page, doc)
        return false
    end
    # If `slug` is a string referncing a known header, we'll go for that
    if Anchors.exists(doc.internal.headers, slug)
        namedxref(link, slug, meta, page, doc)
        return false
    end
    # Next we'll check if name is a "string", in which case it should refer to human readable
    # heading. We'll slugify the string content, just like in basicxref:
    stringmatch = match(r"\"(.+)\"", slug)
    if !isnothing(stringmatch)
        namedxref(link, Utilities.slugify(stringmatch[1]), meta, page, doc)
        return false
    end
    # Finally, we'll assume that the reference is a Julia expression referring to a docstring.
    docref = find_docref(slug, meta, page)
    if haskey(docref, :error)
        # If this is not a valid docref either, we'll call namedxref().
        # This should always throw an error because we already determined that
        # Anchors.exists(doc.internal.headers, slug) is false. But we call it here
        # so that we wouldn't have to duplicate the @docerror call
        namedxref(link, slug, meta, page, doc)
    else
        docsxref(link, slug, meta, page, doc; docref = docref)
    end
    return false
end
xref(other, meta, page, doc) = true # Continue to `walk` through element `other`.

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
            link.url = string(path, Anchors.fragment(anchor))
        else
            @docerror(doc, :cross_references, "'$slug' is not unique in $(Utilities.locrepr(page.source)).")
        end
    else
        @docerror(doc, :cross_references, "reference for '$slug' could not be found in $(Utilities.locrepr(page.source)).")
    end
end

# Cross referencing docstrings.
# -----------------------------

function docsxref(link::Markdown.Link, code, meta, page, doc; docref = find_docref(code, meta, page))
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[link] = link.url

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
        path     = relpath(docsnode.page.build, dirname(page.build))
        slug     = Utilities.slugify(object)
        link.url = string(path, '#', slug)
    else
        @docerror(doc, :cross_references, "no doc found for reference '[`$code`](@ref)' in $(Utilities.locrepr(page.source)).")
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
            return (error = "unable to parse the reference '[`$code`](@ref)' in $(Utilities.locrepr(page.source)).", exception = nothing)
        end
    end
    mod = get(meta, :CurrentModule, Main)

    # Find binding and type signature associated with the link.
    local binding
    try
        binding = Documenter.DocSystem.binding(mod, ex)
    catch err
        return (
            error = "unable to get the binding for '[`$code`](@ref)' in $(Utilities.locrepr(page.source)) from expression '$(repr(ex))' in module $(mod)",
            exception = (err, catch_backtrace()),
        )
        return
    end

    local typesig
    try
        typesig = Core.eval(mod, Documenter.DocSystem.signature(ex, rstrip(code)))
    catch err
        return (
            error = "unable to evaluate the type signature for '[`$code`](@ref)' in $(Utilities.locrepr(page.source)) from expression '$(repr(ex))' in module $(mod)",
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
    # Update issue links starting with a hash, but only if our Remote supports it
    issue_url = Remotes.issueurl(doc.user.remote, num)
    if isnothing(issue_url)
        @docerror(doc, :cross_references, "unable to generate issue reference for '[`#$num`](@ref)' in $(Utilities.locrepr(page.source)).")
    else
        link.url = issue_url
    end
end

end
