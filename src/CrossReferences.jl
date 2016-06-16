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

using Compat

"""
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
        deprecate_link_syntax!(link)
        xref(link, page.globals.meta, page, doc)
    end
end

function deprecate_link_syntax!(link::Markdown.Link)
    if link.url == "{ref}"
        warn("autolink syntax '{ref}' is deprecated use '@ref' instead.")
        link.url = "@ref"
    elseif ismatch(OLD_NAMED_XREF, link.url)
        id = match(OLD_NAMED_XREF, link.url)[1]
        warn("named autolink syntax '$(link.url)' is deprecated use '@ref $id' instead.")
        link.url = "@ref $id"
    end
    nothing
end
deprecate_link_syntax!(other) = nothing

# Dispatch to `namedxref` / `docsxref`.
# -------------------------------------

const NAMED_XREF = r"^@ref (.+)$"
const OLD_NAMED_XREF = r"^{ref#([^{}]*)}$"

function xref(link::Markdown.Link, meta, page, doc)
    link.url == "@ref"            ? basicxref(link, meta, page, doc) :
    ismatch(NAMED_XREF, link.url) ? namedxref(link, meta, page, doc) : nothing
    return false # Stop `walk`ing down this `link` element.
end
xref(other, meta, page, doc) = true # Continue to `walk` through element `other`.

function basicxref(link::Markdown.Link, meta, page, doc)
    if length(link.text) === 1 && isa(link.text[1], Base.Markdown.Code)
        docsxref(link, meta, page, doc)
    elseif isa(link.text, Vector)
        # No `name` was provided, since given a `@ref`, so slugify the `.text` instead.
        text = strip(sprint(Markdown.plain, Markdown.Paragraph(link.text)))
        if ismatch(r"#[0-9]+", text)
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
    # Extract the `name` from the `{ref#...}`.
    slug = match(NAMED_XREF, link.url)[1]
    if isempty(slug)
        text = sprint(Markdown.plaininline, link)
        Utilities.warn(page.source, "'$text' missing a name after '#'.")
    else
        namedxref(link, slug, meta, page, doc)
    end
end

function namedxref(link::Markdown.Link, slug, meta, page, doc)
    headers = doc.internal.headers
    # Error checking: `slug` should exist and be unique.
    # TODO: handle non-unique slugs.
    if Anchors.exists(headers, slug)
        if Anchors.isunique(headers, slug)
            # Replace the `@ref` url with a path to the referenced header.
            anchor   = get(Anchors.anchor(headers, slug))
            path     = relpath(anchor.file, dirname(page.build))
            path     = Formats.extension(doc.user.format, path)
            link.url = string(path, '#', slug, '-', anchor.nth)
        else
            Utilities.warn(page.source, "'$slug' is not unique.")
        end
    else
        Utilities.warn(page.source, "Reference for '$slug' could no be found.")
    end
end

# Cross referencing docstrings.
# -----------------------------

function docsxref(link::Markdown.Link, meta, page, doc)
    code   = link.text[1].code
    curmod = get(meta, :CurrentModule, current_module())
    object = eval(curmod, Utilities.object(parse(code), code))
    if haskey(doc.internal.objects, object)
        # Replace the `@ref` url with a path to the referenced docs.
        docsnode = doc.internal.objects[object]
        path     = relpath(docsnode.page.build, dirname(page.build))
        path     = Formats.extension(doc.user.format, path)
        slug     = Utilities.slugify(object)
        link.url = string(path, '#', slug)
        # Fixup keyword ref text since they have a leading ':' char.
        if object.binding.mod === Utilities.Keywords
            link.text[1].code = lstrip(code, ':')
        end
    else
        Utilities.warn(page.source, "No doc found for reference '[`$code`](@ref)'.")
    end
end

# Issues/PRs cross referencing.
# -----------------------------

function issue_xref(link::Markdown.Link, num, meta, page, doc)
    link.url = isempty(doc.internal.remote) ? link.url :
        "https://github.com/$(doc.internal.remote)/issues/$num"
end

end
