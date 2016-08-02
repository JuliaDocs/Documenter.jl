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
