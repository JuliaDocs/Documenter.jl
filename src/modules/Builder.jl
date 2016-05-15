"""
Defines the Documenter build "pipeline".

The default pipeline consists of the following:

- [`SetupBuildDirectory`](@ref)
- [`CopyAssetsDirectory`](@ref)
- [`ExpandTemplates`](@ref)
- [`CrossReferences`](@ref)
- [`CheckDocument`](@ref)
- [`RenderDocument`](@ref)

Each stage of the pipeline performs an action on a [`Documents.Document`](@ref). These
actions may involve creating directory structures, expanding templates, running doctests, etc.
"""
module Builder

import ..Documenter:

    Anchors,
    Documents,
    Documenter,
    Utilities

using Compat

# Stages.
# -------

"""
Creates the correct directory layout within the `build` folder and parses markdown files.
"""
immutable SetupBuildDirectory end
"""
Copies the contents of the `assets` directory into the `build` folder.
"""
immutable CopyAssetsDirectory end


"""
Executes a sequence of actions on each node of the parsed markdown files in turn. These
actions may be any of:

- [`TrackHeaders`](@ref)
- [`MetaBlocks`](@ref)
- [`DocsBlocks`](@ref)
- [`EvalBlocks`](@ref)
- [`IndexBlocks`](@ref)
- [`ContentsBlocks`](@ref)

See the docs for each of the listed "expanders" for their description.
"""
immutable ExpandTemplates{T}
    expanders :: T
end
ExpandTemplates(t...) = ExpandTemplates{typeof(t)}(t)

abstract Expander

"""
Tracks all `Markdown.Header` nodes found in the parsed markdown files and stores an
[`Anchors.Anchor`](@ref) object for each one.
"""
immutable TrackHeaders <: Expander end
"""
Parses each code block where the first line is `{meta}` and evaluates the key/value pairs
found within the block, i.e.

        {meta}
        CurrentModule = Documenter
        DocTestSetup  = quote
            using Documenter
        end

"""
immutable MetaBlocks <: Expander end
"""
Parses each code block where the first line is `{docs}` and evaluates the expressions found
within the block. Replaces the block with the docstrings associated with each expression.

        {docs}
        Documenter
        makedocs
        deploydocs

"""
immutable DocsBlocks <: Expander end

immutable AutoDocsBlocks <: Expander end

"""
Parses each code block where the first line is `{eval}` and evaluates it's content. Replaces
the block with the value resulting from the evaluation. This can be useful for inserting
generated content into a document such as plots.

        {eval}
        using PyPlot

        x = linspace(-π, π)
        y = sin(x)

        plot(x, y, color = "red")
        savefig("plot.svg")

        Markdown.Image("Plot", "plot.svg")

"""
immutable EvalBlocks <: Expander end
"""
Parses each code block where the first line is `{index}` and replaces it with an index of
all docstrings spliced into the document. The pages that are included can be set using a
key/value pair `Pages = [...]` such as

        {index}
        Pages = ["foo.md", "bar.md"]

"""
immutable IndexBlocks <: Expander end
"""
Parses each code block where the first line is `{contents}` and replaces it with a nested
list of all `Header` nodes in the generated document. The pages and depth of the list can
be set using `Pages = [...]` and `Depth = N` where `N` is and integer.

        {contents}
        Pages = ["foo.md", "bar.md"]
        Depth = 1

The default `Depth` value is `2`.
"""
immutable ContentsBlocks <: Expander end

immutable ExampleBlocks <: Expander end

immutable REPLBlocks <: Expander end

"""
Finds and sets URLs for each `@ref` link in the document to the correct destinations.
"""
immutable CrossReferences end
"""
Checks that all documented objects are included in the document and runs doctests on all
valid Julia code blocks.
"""
immutable CheckDocument end
"""
Writes the document tree to the `build` directory.
"""
immutable RenderDocument end

# Pipeline.
# ---------

immutable Pipeline{T}
    pipeline :: T
end
Pipeline(p...) = Pipeline{typeof(p)}(p)

const DEFAULT_PIPELINE = Pipeline(
    SetupBuildDirectory(),
    CopyAssetsDirectory(),
    ExpandTemplates(
        TrackHeaders(),
        MetaBlocks(),
        DocsBlocks(),
        AutoDocsBlocks(),
        EvalBlocks(),
        IndexBlocks(),
        ContentsBlocks(),
        ExampleBlocks(),
        REPLBlocks(),
    ),
    CrossReferences(),
    CheckDocument(),
    RenderDocument(),
)

# Processing.
# -----------

process(p::Pipeline, document) = process(p.pipeline, document)

function process(pipeline::Tuple, document)
    stage = car(pipeline)
    log(stage); exec(stage, document)
    process(cdr(pipeline), document)
end
process(::Tuple{}, document) = nothing

@inline  car(x::Tuple) = _car(x...)
@inline _car(h, t...)  = h
@inline _car()         = ()

@inline  cdr(x::Tuple) = _cdr(x...)
@inline _cdr(h, t...)  = t
@inline _cdr()         = ()

# Interface.
# ----------

function log  end
function exec end

# Implementations.
# ----------------

# Setup build directory.

log(::SetupBuildDirectory) = Utilities.log("setting up build directory.")

function exec(::SetupBuildDirectory, doc)
    # Frequently used fields.
    build  = doc.user.build
    source = doc.user.source

    doc.user.clean && isdir(build) && rm(build; recursive = true)
    isdir(build) || mkdir(build)
    if isdir(source)
        for (root, dirs, files) in walkdir(source)
            for dir in dirs
                d = normpath(joinpath(build, relpath(root, source), dir))
                isdir(d) || mkdir(d)
            end
            for file in files
                src = normpath(joinpath(root, file))
                dst = normpath(joinpath(build, relpath(root, source), file))
                # Non-markdown files are simply copied over to `build`.
                # Markdown files get added to the document tree as `Page` objects.
                endswith(src, ".md") ?
                    Documents.addpage!(doc, src, dst) :
                    cp(src, dst; remove_destination = true)
            end
        end
    else
        error("source directory '$(abspath(source))' is missing.")
    end
end

# Copy assets directory.

log(::CopyAssetsDirectory) = Utilities.log("copying assets to build directory.")

function exec(::CopyAssetsDirectory, doc)
    assets = doc.internal.assets
    if isdir(assets)
        builddir = joinpath(doc.user.build, "assets")
        isdir(builddir) || mkdir(builddir)
        for each in readdir(assets)
            src = joinpath(assets, each)
            dst = joinpath(builddir, each)
            ispath(dst) && Utilities.warn("Overwriting '$dst'.")
            cp(src, dst; remove_destination = true)
        end
    else
        error("assets directory '$(abspath(assets))' is missing.")
    end
end

# Expand templates.

log(::ExpandTemplates)         = Utilities.log("expanding markdown templates.")
exec(ex::ExpandTemplates, doc) = Documenter.Expanders.expand(ex, doc)

# Build cross-references.

log(::CrossReferences)       = Utilities.log("building cross-references.")
exec(::CrossReferences, doc) = Documenter.CrossReferences.crossref(doc)

# Check document.

log(::CheckDocument) = Utilities.log("running document checks.")

function exec(::CheckDocument, doc)
    Documenter.DocChecks.missingdocs(doc)
    Documenter.DocChecks.doctest(doc)
end

# Render document.

log(::RenderDocument)       = Utilities.log("rendering document.")
exec(::RenderDocument, doc) = Documenter.Writers.render(doc)

end
