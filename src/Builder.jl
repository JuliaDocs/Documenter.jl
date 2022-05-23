"""
Defines the `Documenter.jl` build "pipeline" named [`DocumentPipeline`](@ref).

Each stage of the pipeline performs an action on a [`Documents.Document`](@ref) object.
These actions may involve creating directory structures, expanding templates, running
doctests, etc.
"""
module Builder

import ..Documenter:
    Anchors,
    DocTests,
    Documents,
    Documenter,
    Utilities

import .Utilities: Selectors, is_strict

using DocStringExtensions

# Document Pipeline.
# ------------------

"""
The default document processing "pipeline", which consists of the following actions:

- [`SetupBuildDirectory`](@ref)
- [`Doctest`](@ref)
- [`ExpandTemplates`](@ref)
- [`CrossReferences`](@ref)
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

Selectors.order(::Type{SetupBuildDirectory})   = 1.0
Selectors.order(::Type{Doctest})               = 1.1
Selectors.order(::Type{ExpandTemplates})       = 2.0
Selectors.order(::Type{CrossReferences})       = 3.0
Selectors.order(::Type{CheckDocument})         = 4.0
Selectors.order(::Type{Populate})              = 5.0
Selectors.order(::Type{RenderDocument})        = 6.0

Selectors.matcher(::Type{T}, doc::Documents.Document) where {T <: DocumentPipeline} = true

Selectors.strict(::Type{T}) where {T <: DocumentPipeline} = false

function Selectors.runner(::Type{SetupBuildDirectory}, doc::Documents.Document)
    @info "SetupBuildDirectory: setting up build directory."

    # Frequently used fields.
    build  = doc.user.build
    source = doc.user.source
    workdir = doc.user.workdir
    preprocess = doc.user.preprocess


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
    for (root, dirs, files) in walkdir(source)
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
                push!(mdpages, Utilities.srcpath(source, root, file))
                Documents.addpage!(doc, src, dst, wd, preprocess)
            else
                cp(src, dst; force = true)
            end
        end
    end

    # If the user hasn't specified the page list, then we'll just default to a
    # flat list of all the markdown files we found, sorted by the filesystem
    # path (it will group them by subdirectory, among others).
    userpages = isempty(doc.user.pages) ? sort(mdpages, lt=lt_page) : doc.user.pages

    # Populating the .navtree and .navlist.
    # We need the for loop because we can't assign to the fields of the immutable
    # doc.internal.
    for navnode in walk_navpages(userpages, nothing, doc)
        push!(doc.internal.navtree, navnode)
    end

    # Finally we populate the .next and .prev fields of the navnodes that point
    # to actual pages.
    local prev::Union{Documents.NavNode, Nothing} = nothing
    for navnode in doc.internal.navlist
        navnode.prev = prev
        if prev !== nothing
            prev.next = navnode
        end
        prev = navnode
    end
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

Recursively walks through the [`Documents.Document`](@ref)'s `.user.pages` field,
generating [`Documents.NavNode`](@ref)s and related data structures in the
process.

This implementation is the de facto specification for the `.user.pages` field.
"""
function walk_navpages(visible, title, src, children, parent, doc)
    # parent can also be nothing (for top-level elements)
    parent_visible = (parent === nothing) || parent.visible
    if src !== nothing
        src = normpath(src)
        src in keys(doc.blueprint.pages) || error("'$src' is not an existing page!")
    end
    nn = Documents.NavNode(src, title, parent)
    (src === nothing) || push!(doc.internal.navlist, nn)
    nn.visible = parent_visible && visible
    nn.children = walk_navpages(children, nn, doc)
    nn
end

function walk_navpages(hps::Tuple, parent, doc)
    @assert length(hps) == 4
    walk_navpages(hps..., parent, doc)
end

walk_navpages(title::String, children::Vector, parent, doc) = walk_navpages(true, title, nothing, children, parent, doc)
walk_navpages(title::String, page, parent, doc) = walk_navpages(true, title, page, [], parent, doc)

walk_navpages(p::Pair, parent, doc) = walk_navpages(p.first, p.second, parent, doc)
walk_navpages(ps::Vector, parent, doc) = [walk_navpages(p, parent, doc)::Documents.NavNode for p in ps]
walk_navpages(src::String, parent, doc) = walk_navpages(true, nothing, src, [], parent, doc)

function Selectors.runner(::Type{Doctest}, doc::Documents.Document)
    if doc.user.doctest in [:fix, :only, true]
        @info "Doctest: running doctests."
        DocTests.doctest(doc.blueprint, doc)
        num_errors = length(doc.internal.errors)
        if (doc.user.doctest === :only || is_strict(doc.user.strict, :doctest)) && num_errors > 0
            error("`makedocs` encountered $(num_errors > 1 ? "$(num_errors) doctest errors" : "a doctest error"). Terminating build")
        end
    else
        @info "Doctest: skipped."
    end
end

function Selectors.runner(::Type{ExpandTemplates}, doc::Documents.Document)
    is_doctest_only(doc, "ExpandTemplates") && return
    @info "ExpandTemplates: expanding markdown templates."
    Documenter.Expanders.expand(doc)
end

function Selectors.runner(::Type{CrossReferences}, doc::Documents.Document)
    is_doctest_only(doc, "CrossReferences") && return
    @info "CrossReferences: building cross-references."
    Documenter.CrossReferences.crossref(doc)
end

function Selectors.runner(::Type{CheckDocument}, doc::Documents.Document)
    is_doctest_only(doc, "CheckDocument") && return
    @info "CheckDocument: running document checks."
    Documenter.DocChecks.missingdocs(doc)
    Documenter.DocChecks.footnotes(doc)
    Documenter.DocChecks.linkcheck(doc)
end

function Selectors.runner(::Type{Populate}, doc::Documents.Document)
    is_doctest_only(doc, "Populate") && return
    @info "Populate: populating indices."
    Documents.doctest_replace!(doc)
    Documents.populate!(doc)
end

function Selectors.runner(::Type{RenderDocument}, doc::Documents.Document)
    is_doctest_only(doc, "RenderDocument") && return
    # How many fatal errors
    fatal_errors = filter(is_strict(doc.user.strict), doc.internal.errors)
    c = length(fatal_errors)
    if c > 0
        error("`makedocs` encountered $(c > 1 ? "errors" : "an error") ("
        * join(Ref(":") .* string.(fatal_errors), ", ")
        * "). Terminating build before rendering.")
    else
        @info "RenderDocument: rendering document."
        Documenter.Writers.render(doc)
    end
end

Selectors.runner(::Type{DocumentPipeline}, doc::Documents.Document) = nothing

function is_doctest_only(doc, stepname)
    if doc.user.doctest in [:fix, :only]
        @info "Skipped $stepname step (doctest only)."
        return true
    end
    return false
end

end
