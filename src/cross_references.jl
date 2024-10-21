"""
$(SIGNATURES)

Traverses a [`Documenter.Document`](@ref) and process internal links and
references.

- Links containing `@ref` URLs are replaced with their real URLs. This
  delegates to [`xref`](@ref), which in turn delegates to the
  [`XRefResolvers.XRefResolverPipeline`](@ref).
- Links to local (`.md`) documents are rewritten to link to the corresponding
  path in the output build.
- For links to local files or images, check that the linked files exist.
"""
function crossref(doc::Documenter.Document)
    for (src, page) in doc.blueprint.pages
        empty!(page.globals.meta)
        crossref(doc, page, page.mdast)
    end
    return
end

function crossref(doc::Documenter.Document, page, mdast::MarkdownAST.Node)
    meta = page.globals.meta
    for node in AbstractTrees.PreOrderDFS(mdast)
        if node.element isa Documenter.MetaNode
            merge!(meta, node.element.dict)
        elseif node.element isa Documenter.DocsNode
            # the docstring AST trees are not part of the tree of the page, so we need to explicitly
            # call crossref() on them to update the links there. We also need up update
            # the CurrentModule meta key as needed, to make sure we find the correct
            # relative refs within docstrings
            tmp = get(page.globals.meta, :CurrentModule, nothing)
            for (docstr, docmeta) in zip(node.element.mdasts, node.element.metas)
                mod = get(docmeta, :module, nothing)
                isnothing(mod) || (meta[:CurrentModule] = mod)
                crossref(doc, page, docstr)
            end
            if isnothing(tmp)
                delete!(meta, :CurrentModule)
            else
                meta[:CurrentModule] = tmp
            end
        elseif node.element isa MarkdownAST.Link
            link_url = node.element.destination
            if Documenter.isabsurl(link_url) || startswith(link_url, "mailto:")
                # Absolute / external links simply get left alone
            else
                if occursin(XREF_REGEX, link_url)
                    xref(node, meta, page, doc)
                else
                    local_links!(node, meta, page, doc)
                end
            end
        elseif node.element isa MarkdownAST.Image
            # Images must be either be …
            if Documenter.isabsurl(node.element.destination)
                # … absolute / external links (no further processing) …
            else
                # … or local links (no at-ref syntax for those at the moment)
                local_links!(node, meta, page, doc)
            end
        end
    end
    return
end

function local_links!(node::MarkdownAST.Node, meta, page, doc)
    @assert node.element isa Union{MarkdownAST.Link, MarkdownAST.Image}
    link_url = node.element.destination
    @assert !Documenter.isabsurl(link_url)
    @assert !startswith(link_url, "mailto:")

    # For any local link, we check that it is actually pointing to a file.
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
                link = node
            )
            return
        end
        node.element = Documenter.PageLink(page, fragment)
        return
    elseif Sys.iswindows() && ':' in path
        @docerror(
            doc, :cross_references,
            "invalid local link/image: colons not allowed in paths on Windows in $(Documenter.locrepr(page.source))",
            link = node
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
            link = node
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
                    link = node
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
            link = node
        )
        return
    end
end

function splitfragment(s)
    xs = split(s, '#', limit = 2)
    return xs[1], get(xs, 2, "")
end

# Dispatch pipeline for @ref links
# --------------------------------

module XRefResolvers
    import ..Documenter  # import for docstrings only
    import ..Documenter.Remotes #  import for docstrings only
    import ..Documenter.Selectors

    """The default pipeline for resolving `@ref` links.

    The steps for trying to resolve links are:

    - [`XRefResolvers.Header`](@ref) for links like `[Section Header](@ref)`
    - [`XRefResolvers.Issue`](@ref) for links like `[#11](@ref)`
    - [`XRefResolvers.Docs`](@ref) for links like ```[`Documenter.makedocs`](@ref)```

    Each step may or may not be able to resolve the link. Processing continues until the
    link is resolved or the end of the pipeline is reached. If the link is still unresolved
    after the last step, [`Documenter.xref`](@ref) issues an error that includes any
    accumulated error messages from the steps. Failure to resolve an `@ref` link will fail
    [`Documenter.makedocs`](@ref) if it is not called with `warnonly=true`.

    The default pipeline could be extended by plugins using the general [`Selectors`](@ref)
    machinery.

    Each pipeline step receives the following arguments:

    * `node`: the `MarkdownAST.Node` representing the link. To resolve the `@ref` URL, any
      pipeline step can modify the node.
    * `slug`: the "slug" for the link, see [`Documenter.xref`](@ref)
    * `meta`: a dictionary of metadata, see [`@meta` block](@ref)
    * `page`: the [`Documenter.Page`](@ref) object containing the `node`
    * `doc`: the [`Documenter.Document`](@ref) instance representing the full site
    * `errors`: a list of strings of error messages accumulated in the
      `XRefResolverPipeline`. If a pipeline step indicates that it might be able to resolve
      a `@ref` link ([`Selectors.matcher`](@ref) is `true`), but then encounters an error in
      [`Selectors.runner`](@ref) that prevents resolution, it should push an error message
      to the list of `errors` to explain the failure. These accumulated errors will be shown
      if (and only if) the entire pipeline fails to resolve the link.

    The [`Selectors.matcher`](@ref) of any custom pipeline step should use
    [`Documenter.xref_unresolved`](@ref) to check whether the link was already resolved in an
    earlier pipeline step.
    """
    abstract type XRefResolverPipeline <: Selectors.AbstractSelector end

    Selectors.strict(::Type{T}) where {T <: XRefResolverPipeline} = false

    """Resolve `@ref` links for headers.

    This runs if the `slug` corresponds to a known local section title, and resolves the
    `node` to link to that section.
    """
    abstract type Header <: XRefResolverPipeline end

    """Resolve `@ref` links for issues.

    This runs if the `slug` is `"#"` followed by one or more digits and tries to link to an
    issue number using [`Remotes.issueurl`](@ref).
    """
    abstract type Issue <: XRefResolverPipeline end

    """Resolve `@ref` links for docstrings.

    This runs unconditionally (if no previous step was able to resolve the link), and
    tries to find a code binding for the given `slug`, linking to its docstring.
    """
    abstract type Docs <: XRefResolverPipeline end

end

Selectors.order(::Type{XRefResolvers.Header}) = 1.0
Selectors.order(::Type{XRefResolvers.Issue}) = 2.0
Selectors.order(::Type{XRefResolvers.Docs}) = 3.0


"""
$(SIGNATURES)

checks whether `node` is a link with an `@ref` URL. Any step in the
[`XRefResolvers.XRefResolverPipeline`](@ref) should use this to determine whether the `node`
still needs to be resolved.
"""
function xref_unresolved(node)
    return (node.element isa MarkdownAST.Link) &&
        occursin(XREF_REGEX, node.element.destination)
end


function Selectors.matcher(::Type{XRefResolvers.Header}, node, slug, meta, page, doc, errors)
    return (xref_unresolved(node) && anchor_exists(doc.internal.headers, slug))
end

function Selectors.runner(::Type{XRefResolvers.Header}, node, slug, meta, page, doc, errors)
    return namedxref(node, slug, meta, page, doc, errors)
end


function Selectors.matcher(::Type{XRefResolvers.Issue}, node, slug, meta, page, doc, errors)
    return (xref_unresolved(node) && occursin(r"#[0-9]+", slug))
end

function Selectors.runner(::Type{XRefResolvers.Issue}, node, slug, meta, page, doc, errors)
    return issue_xref(node, lstrip(slug, '#'), meta, page, doc, errors)
end


function Selectors.matcher(::Type{XRefResolvers.Docs}, node, slug, meta, page, doc, errors)
    return xref_unresolved(node)
end

function Selectors.runner(::Type{XRefResolvers.Docs}, node, slug, meta, page, doc, errors)
    return docsxref(node, slug, meta, page, doc, errors)
end


# Finalizer (not used) …
Selectors.runner(::Type{XRefResolvers.XRefResolverPipeline}, args...) = nothing
# – in principle, this finalizer could do the final `@docerror`, but it's just a little more
# robust to do it in `xref` after the `dispatch`. That way, it doesn't break if some plugin
# does something unexpected with `Selectors.strict`.


"""
$(SIGNATURES)

Resolve a `MarkdownAST.Link` node with an `@ref` URL.

This delegates to [`XRefResolvers.XRefResolverPipeline`](@ref). In addition to forwarding
the `node`, `meta`, `page`, and `doc` arguments, it also passes a `slug` to the pipeline
that any pipeline step can use to easily resolve the link target. This `slug` is obtained as
follows:

- For, e.g, ```[`Documenter.makedocs`](@ref)``` or `[text](@ref Documenter.makedocs)`, the
  `slug` is `"Documenter.makedocs"`
- For, e.g, ```[Hosting Documentation](@ref)``` or `[text](@ref "Hosting Documentation")`,
  the `slug` is sluggified version of the given section title, `"Hosting-Documentation"` in
  this case.
"""
function xref(node::MarkdownAST.Node, meta, page, doc)
    @assert node.element isa MarkdownAST.Link
    link = node.element
    slug = xrefname(link.destination)
    @assert !isnothing(slug)
    if isempty(slug)
        # obtain a slug from the link text
        if length(node.children) == 1 && isa(first(node.children).element, MarkdownAST.Code)
            slug = first(node.children).element.code
        else
            # TODO: remove this hack (replace with mdflatten?)
            md = _link_node_as_md(node)
            text = strip(sprint(Markdown.plain, Markdown.Paragraph(md.content[1].content[1].text)))
            slug = Documenter.slugify(text)
        end
    else
        # explicit slugs that are enclosed in quotes must be further sluggified
        stringmatch = match(r"\"(.+)\"", slug)
        if !isnothing(stringmatch)
            slug = Documenter.slugify(stringmatch[1])
        end
    end
    errors = String[]
    Selectors.dispatch(
        XRefResolvers.XRefResolverPipeline, node, slug, meta, page, doc, errors
    )
    # finalizer
    if xref_unresolved(node)
        md_str = strip(Markdown.plain(_link_node_as_md(node)))
        msg = "Cannot resolve @ref for md$(repr(md_str)) in $(Documenter.locrepr(page.source))."
        if (length(errors) > 0)
            msg *= ("\n" * join([string("- ", err) for err in errors], "\n"))
        end
        @docerror(doc, :cross_references, msg)
    end
    return nothing
end


# Helper to convert MarkdownAST link node to a Markdown.MD object
function _link_node_as_md(node::MarkdownAST.Node)
    @assert node.element isa MarkdownAST.Link
    document = MarkdownAST.@ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            MarkdownAST.copy_tree(node)
        end
    end
    return convert(Markdown.MD, document)
end


"""
Parse the `link.url` field of an `@ref` link. Returns `nothing` if it's not an `@ref`,
an empty string the reference link has no label, or a whitespace-stripped version the
label.
"""
function xrefname(link_url::AbstractString)
    m = match(XREF_REGEX, link_url)
    isnothing(m) && return nothing
    return isnothing(m[1]) ? "" : strip(m[1])
end

"""Regular expression for an `@ref` link url.

This is used by the [`XRefResolvers.XRefResolverPipeline`](@ref), respectively
[`xref_unresolved`](@ref): as long as the url of the link node still matches `XREF_REGEX`,
the reference remains unresolved and needs further processing in subsequent steps of the
pipeline.
"""
const XREF_REGEX = r"^\s*@ref(\s.*)?$"


# Cross referencing headers.
# --------------------------

function namedxref(node::MarkdownAST.Node, slug, meta, page, doc, errors)
    @assert node.element isa MarkdownAST.Link
    headers = doc.internal.headers
    @assert anchor_exists(headers, slug)
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[node.element] = node.element.destination
    # Error checking: `slug` should exist and be unique.
    # TODO: handle non-unique slugs.
    if anchor_isunique(headers, slug)
        # Replace the `@ref` url with a path to the referenced header.
        anchor = Documenter.anchor(headers, slug)
        pagekey = relpath(anchor.file, doc.user.build)
        page = doc.blueprint.pages[pagekey]
        node.element = Documenter.PageLink(page, anchor_label(anchor))
    else
        push!(errors, "Header with slug '$slug' is not unique in $(Documenter.locrepr(page.source)).")
    end
    return
end

# Cross referencing docstrings.
# -----------------------------

function docsxref(node::MarkdownAST.Node, code, meta, page, doc, errors)
    @assert node.element isa MarkdownAST.Link
    # Add the link to list of local uncheck links.
    doc.internal.locallinks[node.element] = node.element.destination
    if haskey(meta, :CurrentModule)
        # CurrentModule can be set manually for `.md` pages. For a @ref that's
        # inside a docstring, CurrentModule is automatically set to the module
        # containing that docstring.
        modules = [meta[:CurrentModule], Main]
    else
        modules = [Main]
    end
    for (attempt, mod) in enumerate(modules)
        docref = find_docref(code, mod, page)
        if haskey(docref, :error)
            # We'll bail if the parsing of the docref wasn't successful
            msg = "Exception trying to find docref for `$code`: $(docref.error)"
            @debug msg exception = docref.exception  # shows the full backtrace
            push!(errors, msg)
        else
            binding, typesig = docref
            # Try to find a valid object that we can cross-reference.
            object = find_object(doc, binding, typesig)
            if object !== nothing
                if (attempt == 1) || startswith(code, string(binding.mod))
                    # Replace the `@ref` url with a path to the referenced docs.
                    docsnode = doc.internal.objects[object]
                    slug = Documenter.slugify(object)
                    pagekey = relpath(docsnode.page.build, doc.user.build)
                    page = doc.blueprint.pages[pagekey]
                    node.element = Documenter.PageLink(page, slug)
                    break  # stop after first mod with binding we can link to
                else
                    # In the "fallback" attempt 2 in Main we abort if `code` is
                    # not a fully qualified name (it must start with
                    # `binding.mod`)
                    @assert mod == Main
                    msg = "Fallback resolution in $mod for `$code` -> `$(binding.mod).$(binding.var)` is only allowed for fully qualified names"
                    push!(errors, msg)
                end
            else
                msg = "No docstring found in doc for binding `$(binding.mod).$(binding.var)`."
                push!(errors, msg)
            end
        end
    end
    return
end

function find_docref(code, mod, page)
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
            return (error = "unable to parse the reference `$code` in $(Documenter.locrepr(page.source)).", exception = nothing)
        end
    end

    # Find binding and type signature associated with the link.
    local binding
    try
        binding = Documenter.DocSystem.binding(mod, ex)
    catch err
        return (
            error = "unable to get the binding for `$code` in module $(mod)",
            exception = (err, catch_backtrace()),
        )
        return
    end

    local typesig
    try
        typesig = Core.eval(mod, Documenter.DocSystem.signature(ex, rstrip(code)))
    catch err
        return (
            error = "unable to evaluate the type signature for `$code` in $(Documenter.locrepr(page.source)) in module $(mod)",
            exception = (err, catch_backtrace()),
        )
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
find_object(::Union{Function, DataType}, binding, ::Union{Union, Type{Union{}}}) = Documenter.Object(binding, Union{})
find_object(other, binding, typesig) = Documenter.Object(binding, typesig)

getsig(λ::Union{Function, DataType}, typesig) = Base.tuple_type_tail(which(λ, typesig).sig)


# Issues/PRs cross referencing.
# -----------------------------

function issue_xref(node::MarkdownAST.Node, num, meta, page, doc, errors)
    @assert node.element isa MarkdownAST.Link
    # Update issue links starting with a hash, but only if our Remote supports it
    issue_url = isnothing(doc.user.remote) ? nothing : Remotes.issueurl(doc.user.remote, num)
    if isnothing(issue_url)
        push!(errors, "unable to generate issue reference for '[`#$num`](@ref)' in $(Documenter.locrepr(page.source)).")
    else
        node.element.destination = issue_url
    end
    return
end
