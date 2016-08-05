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

using Compat

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
abstract DocumentPipeline <: Selectors.AbstractSelector

"""
Creates the correct directory layout within the `build` folder and parses markdown files.
"""
abstract SetupBuildDirectory <: DocumentPipeline

"""
Executes a sequence of actions on each node of the parsed markdown files in turn.
"""
abstract ExpandTemplates <: DocumentPipeline

"""
Finds and sets URLs for each `@ref` link in the document to the correct destinations.
"""
abstract CrossReferences <: DocumentPipeline

"""
Checks that all documented objects are included in the document and runs doctests on all
valid Julia code blocks.
"""
abstract CheckDocument <: DocumentPipeline

"""
Populates the `ContentsNode`s and `IndexNode`s with links.
"""
abstract Populate <: DocumentPipeline

"""
Writes the document tree to the `build` directory.
"""
abstract RenderDocument <: DocumentPipeline

Selectors.order(::Type{SetupBuildDirectory})   = 1.0
Selectors.order(::Type{ExpandTemplates})       = 2.0
Selectors.order(::Type{CrossReferences})       = 3.0
Selectors.order(::Type{CheckDocument})         = 4.0
Selectors.order(::Type{Populate})              = 5.0
Selectors.order(::Type{RenderDocument})        = 6.0

Selectors.matcher{T <: DocumentPipeline}(::Type{T}, doc::Documents.Document) = true

Selectors.strict{T <: DocumentPipeline}(::Type{T}) = false

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
    isdir(build) || mkdir(build)

    # We'll walk over all the files in the .user.source directory.
    # The directory structure is copied over to .user.build. All files, with
    # the exception of markdown files (identified by the extension) are copied
    # over as well, since they're assumed to be images, data files etc.
    # Markdown files, however, get added to the document and also stored into
    # `mdpages`, to be used later.
    mdpages = Compat.String[]
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
                cp(src, dst; remove_destination = true)
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
    local prev::Nullable{Documents.NavNode} = nothing
    for navnode in doc.internal.navlist
        navnode.prev = prev
        Utilities.unwrap(prev) do prevnode
            prevnode.next = navnode
        end
        prev = navnode
    end
end

"""
    walk_navpages(x, parent, doc)

Recursively walks through the [`Documents.Document`](@ref)'s `.user.pages` field,
generating [`Documents.NavNode`](@ref)s and related data structures in the
process.

This implementation is the de facto specification for the `.user.pages` field.
"""
walk_navpages(ps::Vector, parent, doc) = [walk_navpages(p, parent, doc)::Documents.NavNode for p in ps]
walk_navpages(p::Pair, parent, doc) = walk_navpages(p.first, p.second, parent, doc)
function walk_navpages(title::Compat.String, children::Vector, parent, doc)
    nn = Documents.NavNode(nothing, title, parent)
    nn.children = walk_navpages(children, nn, doc)
    nn
end
function walk_navpages(title::Compat.String, page::Compat.String, parent, doc)
    nn = walk_navpages(page, parent, doc)
    nn.title_override = title
    nn
end
function walk_navpages(src::Compat.String, parent, doc)
    src in keys(doc.internal.pages) || error("'$src' is not an existing page!")
    nn = Documents.NavNode(src, nothing, parent)
    push!(doc.internal.navlist, nn)
    nn
end


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
end

function Selectors.runner(::Type{Populate}, doc::Documents.Document)
    Utilities.log("populating indices.")
    Documents.populate!(doc)
end

function Selectors.runner(::Type{RenderDocument}, doc::Documents.Document)
    Utilities.log(doc, "rendering document.")
    Documenter.Writers.render(doc)
end

Selectors.runner(::Type{DocumentPipeline}, doc::Documents.Document) = nothing

end
