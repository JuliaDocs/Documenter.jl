"""
Defines the `Documenter.jl` build "pipeline" named [`DocumentPipeline`](@ref).

Each stage of the pipeline performs an action on a [`Documents.Document`](@ref) object.
These actions may involve creating directory structures, expanding templates, running
doctests, etc.
"""
module Builder

import ..Documenter:
    Anchors,
    Selectors,
    Documents,
    Documenter,
    Utilities

using Compat, DocStringExtensions

# Document Pipeline.
# ------------------

"""
The default document processing "pipeline", which consists of the following actions:

- [`SetupBuildDirectory`](@ref)
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
Selectors.order(::Type{ExpandTemplates})       = 2.0
Selectors.order(::Type{CrossReferences})       = 3.0
Selectors.order(::Type{CheckDocument})         = 4.0
Selectors.order(::Type{Populate})              = 5.0
Selectors.order(::Type{RenderDocument})        = 6.0

Selectors.matcher(::Type{T}, doc::Documents.Document) where {T <: DocumentPipeline} = true

Selectors.strict(::Type{T}) where {T <: DocumentPipeline} = false

function Selectors.runner(::Type{SetupBuildDirectory}, doc::Documents.Document)
    Utilities.log(doc, "setting up build directory.")

    # Frequently used fields.
    build  = doc.user.build
    source = doc.user.source

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
            if endswith(file, ".md")
                push!(mdpages, Utilities.srcpath(source, root, file))
                Documents.addpage!(doc, src, dst)
            else
                Compat.cp(src, dst; force = true)
            end
        end
    end

    # If the user hasn't specified the page list, then we'll just default to a
    # flat list of all the markdown files we found, sorted by the filesystem
    # path (it will group them by subdirectory, among others).
    userpages = isempty(doc.user.pages) ? sort(mdpages) : doc.user.pages

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
        src in keys(doc.internal.pages) || error("'$src' is not an existing page!")
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


function Selectors.runner(::Type{ExpandTemplates}, doc::Documents.Document)
    Utilities.log(doc, "expanding markdown templates.")
    Documenter.Expanders.expand(doc)
end

function Selectors.runner(::Type{CrossReferences}, doc::Documents.Document)
    Utilities.log(doc, "building cross-references.")
    Documenter.CrossReferences.crossref(doc)
end

function Selectors.runner(::Type{CheckDocument}, doc::Documents.Document)
    Utilities.log(doc, "running document checks.")
    Documenter.DocChecks.missingdocs(doc)
    Documenter.DocChecks.doctest(doc)
    Documenter.DocChecks.footnotes(doc)
    Documenter.DocChecks.linkcheck(doc)
end

function Selectors.runner(::Type{Populate}, doc::Documents.Document)
    Utilities.log("populating indices.")
    Documents.populate!(doc)
end

function Selectors.runner(::Type{RenderDocument}, doc::Documents.Document)
    count = length(doc.internal.errors)
    if doc.user.strict && count > 0
        error("`makedocs` encountered $(count > 1 ? "errors" : "an error"). Terminating build")
    else
        Utilities.log(doc, "rendering document.")
        Documenter.Writers.render(doc)
    end
end

Selectors.runner(::Type{DocumentPipeline}, doc::Documents.Document) = nothing

end
