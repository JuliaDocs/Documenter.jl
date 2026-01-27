"""
Defines the `Documenter.jl` build "pipeline" named [`DocumentPipeline`](@ref).

Each stage of the pipeline performs an action on a [`Document`](@ref Documenter.Document) object.
These actions may involve creating directory structures, expanding templates, running
doctests, etc.
"""
module Builder
    import ..Documenter
    import ..Documenter.Selectors

    """
    The default document processing "pipeline", which consists of the following actions:

    - [`SetupBuildDirectory`](@ref)
    - [`Doctest`](@ref)
    - [`ExpandTemplates`](@ref)
    - [`CheckDocument`](@ref)
    - [`Populate`](@ref)
    - [`RenderDocument`](@ref)

    """
    abstract type DocumentPipeline <: Selectors.AbstractSelector end

    """
    Creates the correct directory layout within the `build` folder and parses markdown files.
    """
    abstract type SetupBuildDirectory <: DocumentPipeline end

    """
    Runs all the doctests in all docstrings and Markdown files.
    """
    abstract type Doctest <: DocumentPipeline end

    """
    Executes a sequence of actions on each node of the parsed markdown files in turn.
    """
    abstract type ExpandTemplates <: DocumentPipeline end

    """
    Finds and sets URLs for each `@ref` link in the document to the correct destinations.
    """
    abstract type CrossReferences <: DocumentPipeline end

    """
    Checks that all documented objects are included in the document and runs doctests on all
    valid Julia code blocks.
    """
    abstract type CheckDocument <: DocumentPipeline end

    """
    Populates the `ContentsNode`s and `IndexNode`s with links.
    """
    abstract type Populate <: DocumentPipeline end

    """
    Writes the document tree to the `build` directory.
    """
    abstract type RenderDocument <: DocumentPipeline end
end

Selectors.order(::Type{Builder.SetupBuildDirectory}) = 1.0
Selectors.order(::Type{Builder.Doctest}) = 1.1
Selectors.order(::Type{Builder.ExpandTemplates}) = 2.0
Selectors.order(::Type{Builder.CrossReferences}) = 3.0
Selectors.order(::Type{Builder.CheckDocument}) = 4.0
Selectors.order(::Type{Builder.Populate}) = 5.0
Selectors.order(::Type{Builder.RenderDocument}) = 6.0

Selectors.matcher(::Type{T}, doc::Documenter.Document) where {T <: Builder.DocumentPipeline} = true

Selectors.strict(::Type{T}) where {T <: Builder.DocumentPipeline} = false

function Selectors.runner(::Type{Builder.SetupBuildDirectory}, doc::Documenter.Document)
    @info "SetupBuildDirectory: setting up build directory."

    # Frequently used fields.
    build = doc.user.build
    source = doc.user.source
    workdir = doc.user.workdir

    # The .user.source directory must exist.
    isdir(source) || error("source directory '$(abspath(source))' is missing.")

    # We create the .user.build directory.
    # If .user.clean is set, we first clean the existing directory.
    doc.user.clean && isdir(build) && rm(build; recursive = true)
    isdir(build) || mkpath(build)

    # We'll walk over all the files in the .user.source directory.
    # The directory structure is copied over to .user.build. All files, with
    # the exception of markdown files (identified by the extension) are copied
    # over as well, since they're assumed to be images, data files etc.
    # Markdown files, however, get added to the document and also stored into
    # `mdpages`, to be used later.
    mdpages = String[]
    for (root, dirs, files) in walkdir(source; follow_symlinks = true)
        for dir in dirs
            d = normpath(joinpath(build, relpath(root, source), dir))
            isdir(d) || mkdir(d)
        end
        for file in files
            src = normpath(joinpath(root, file))
            dst = normpath(joinpath(build, relpath(root, source), file))

            if workdir == :build
                # set working directory to be the same as `build`
                wd = normpath(joinpath(build, relpath(root, source)))
            elseif workdir isa Symbol
                # Maybe allow `:src` and `:root` as well?
                throw(ArgumentError("Unrecognized working directory option '$workdir'"))
            else
                wd = normpath(joinpath(doc.user.root, workdir))
            end

            if endswith(file, ".md")
                push!(mdpages, Documenter.srcpath(source, root, file))
                Documenter.addpage!(doc, src, dst, wd)
            else
                cp(src, dst; force = true)
            end
        end
    end

    # If the user hasn't specified the page list, then we'll just default to a
    # flat list of all the markdown files we found, sorted by the filesystem
    # path (it will group them by subdirectory, among others).
    userpages = isempty(doc.user.pages) ? sort(mdpages, lt = lt_page) : doc.user.pages

    # Check if top_menu is being used
    if !isempty(doc.user.top_menu)
        # Track all pages used across sections to detect duplicates
        all_section_pages = Set{String}()

        # Populating top_menu_sections with their navtrees and navlists
        for section_entry in doc.user.top_menu
            section_title, section_pages = if section_entry isa Pair
                section_entry.first, section_entry.second
            else
                error("top_menu entries must be Pairs of \"Title\" => pages_array, got: $(typeof(section_entry))")
            end

            section_navtree = Documenter.NavNode[]
            section_navlist = Documenter.NavNode[]

            # Walk through the section's pages
            for navnode in walk_navpages(section_pages, nothing, doc; navlist = section_navlist)
                push!(section_navtree, navnode)
            end

            # Check for duplicate pages across sections
            for navnode in section_navlist
                if navnode.page in all_section_pages
                    @warn "Page '$(navnode.page)' appears in multiple top_menu sections. " *
                        "Each page should belong to only one section for proper navigation."
                end
                push!(all_section_pages, navnode.page)
            end

            # Populate prev/next for this section's navlist
            local prev::Union{Documenter.NavNode, Nothing} = nothing
            for navnode in section_navlist
                navnode.prev = prev
                if prev !== nothing
                    prev.next = navnode
                end
                prev = navnode
            end

            # Determine the first page for the section link
            first_page = isempty(section_navlist) ? nothing : section_navlist[1].page

            # Create the section with populated data
            section = Documenter.TopMenuSection(
                section_title,
                section_navtree,
                section_navlist,
                first_page
            )
            push!(doc.internal.top_menu_sections, section)

            # Also add to the global navlist for backward compatibility and cross-section navigation
            append!(doc.internal.navlist, section_navlist)
        end

        # Now populate the global navtree as well (for backward compatibility)
        # The global navtree will contain all sections' navtrees combined
        for section in doc.internal.top_menu_sections
            append!(doc.internal.navtree, section.navtree)
        end

        # Re-populate prev/next for the global navlist to allow cross-section navigation
        local prev_global::Union{Documenter.NavNode, Nothing} = nothing
        for navnode in doc.internal.navlist
            navnode.prev = prev_global
            if prev_global !== nothing
                prev_global.next = navnode
            end
            prev_global = navnode
        end
    else
        # Original behavior when top_menu is not used
        # Populating the .navtree and .navlist.
        # We need the for loop because we can't assign to the fields of the immutable
        # doc.internal.
        for navnode in walk_navpages(userpages, nothing, doc)
            push!(doc.internal.navtree, navnode)
        end

        # Finally we populate the .next and .prev fields of the navnodes that point
        # to actual pages.
        local prev::Union{Documenter.NavNode, Nothing} = nothing
        for navnode in doc.internal.navlist
            navnode.prev = prev
            if prev !== nothing
                prev.next = navnode
            end
            prev = navnode
        end
    end

    # If the user specified pagesonly, we will remove all the pages not in the navigation
    # menu (.pages).
    if doc.user.pagesonly
        navlist_pages = getfield.(doc.internal.navlist, :page)
        for page in keys(doc.blueprint.pages)
            page ∈ navlist_pages || delete!(doc.blueprint.pages, page)
        end
    end
    return
end

"""
    lt_page(a::AbstractString, b::AbstractString)

Checks if the page path `a` should come before `b` in a sorted list. Falls back to standard
string sorting, except for prioritizing `index.md` (i.e. `index.md` always comes first).
"""
function lt_page(a, b)
    # note: length("index.md") == 8
    a = endswith(a, "index.md") ? chop(a; tail = 8) : a
    b = endswith(b, "index.md") ? chop(b; tail = 8) : b
    return a < b
end

"""
$(SIGNATURES)

Recursively walks through the [`Document`](@ref)'s `.user.pages` field,
generating [`NavNode`](@ref)s and related data structures in the
process.

This implementation is the de facto specification for the `.user.pages` field.

The optional `navlist` keyword argument allows specifying an alternative navlist
to populate (used for top_menu sections).
"""
function walk_navpages(visible, title, src, children, parent, doc; navlist = nothing)
    # parent can also be nothing (for top-level elements)
    parent_visible = (parent === nothing) || parent.visible
    if src !== nothing
        src = normpath(src)
        src in keys(doc.blueprint.pages) || error("'$src' is not an existing page!")
    end
    nn = Documenter.NavNode(src, title, parent)
    # Push to the appropriate navlist
    if src !== nothing
        target_navlist = isnothing(navlist) ? doc.internal.navlist : navlist
        push!(target_navlist, nn)
    end
    nn.visible = parent_visible && visible
    nn.children = walk_navpages(children, nn, doc; navlist = navlist)
    return nn
end

function walk_navpages(hps::Tuple, parent, doc; navlist = nothing)
    @assert length(hps) == 4
    return walk_navpages(hps..., parent, doc; navlist = navlist)
end

walk_navpages(title::String, children::Vector, parent, doc; navlist = nothing) = walk_navpages(true, title, nothing, children, parent, doc; navlist = navlist)
walk_navpages(title::String, page, parent, doc; navlist = nothing) = walk_navpages(true, title, page, [], parent, doc; navlist = navlist)

walk_navpages(p::Pair, parent, doc; navlist = nothing) = walk_navpages(p.first, p.second, parent, doc; navlist = navlist)
walk_navpages(ps::Vector, parent, doc; navlist = nothing) = [walk_navpages(p, parent, doc; navlist = navlist)::Documenter.NavNode for p in ps]
walk_navpages(src::String, parent, doc; navlist = nothing) = walk_navpages(true, nothing, src, [], parent, doc; navlist = navlist)

function Selectors.runner(::Type{Builder.Doctest}, doc::Documenter.Document)
    if doc.user.doctest in [:fix, :only, true]
        @info "Doctest: running doctests."
        _doctest(doc.blueprint, doc)
        num_errors = length(doc.internal.errors)
        if (doc.user.doctest === :only || is_strict(doc, :doctest)) && num_errors > 0
            error("`makedocs` encountered $(num_errors > 1 ? "$(num_errors) doctest errors" : "a doctest error"). Terminating build")
        end
    else
        @info "Doctest: skipped."
    end
    return
end

function Selectors.runner(::Type{Builder.ExpandTemplates}, doc::Documenter.Document)
    is_doctest_only(doc, "ExpandTemplates") && return
    @info "ExpandTemplates: expanding markdown templates."
    expand(doc)
    return
end

function Selectors.runner(::Type{Builder.CrossReferences}, doc::Documenter.Document)
    is_doctest_only(doc, "CrossReferences") && return
    @info "CrossReferences: building cross-references."
    crossref(doc)
    return
end

function Selectors.runner(::Type{Builder.CheckDocument}, doc::Documenter.Document)
    is_doctest_only(doc, "CheckDocument") && return
    @info "CheckDocument: running document checks."
    missingdocs(doc)
    footnotes(doc)
    linkcheck(doc)
    githubcheck(doc)
    return
end

function Selectors.runner(::Type{Builder.Populate}, doc::Documenter.Document)
    is_doctest_only(doc, "Populate") && return
    @info "Populate: populating indices."
    doctest_replace!(doc)
    populate!(doc)
    return
end

function Selectors.runner(::Type{Builder.RenderDocument}, doc::Documenter.Document)
    is_doctest_only(doc, "RenderDocument") && return
    # How many fatal errors
    fatal_errors = filter(is_strict(doc), doc.internal.errors)
    c = length(fatal_errors)
    if c > 0
        error(
            "`makedocs` encountered $(c > 1 ? "errors" : "an error") ["
                * join(Ref(":") .* string.(fatal_errors), ", ")
                * "] -- terminating build before rendering."
        )
    else
        @info "RenderDocument: rendering document."
        Documenter.render(doc)
    end
    return
end

Selectors.runner(::Type{Builder.DocumentPipeline}, doc::Documenter.Document) = nothing

function is_doctest_only(doc, stepname)
    if doc.user.doctest in [:fix, :only]
        @info "Skipped $stepname step (doctest only)."
        return true
    end
    return false
end
