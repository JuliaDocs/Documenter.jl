"""
Defines [`Document`](@ref) and its supporting types

- [`Page`](@ref)
- [`User`](@ref)
- [`Internal`](@ref)
- [`Globals`](@ref)

"""
module Documents

import ..Documenter:

    Anchors,
    Formats,
    Utilities

using Compat

# Pages.
# ------

"""
[`Page`](@ref)-local values such as current module that are shared between nodes in a page.
"""
type Globals
    mod  :: Module
    meta :: Dict{Symbol, Any}
end
Globals() = Globals(current_module(), Dict())

"""
Represents a single markdown file.
"""
immutable Page
    source   :: Compat.String
    build    :: Compat.String
    elements :: Vector
    mapping  :: ObjectIdDict
    globals  :: Globals
end
function Page(source::AbstractString, build::AbstractString)
    elements = Base.Markdown.parse(readstring(source)).content
    Page(source, build, elements, ObjectIdDict(), Globals())
end

# Inner Document Fields.
# ----------------------

"""
User-specified values used to control the generation process.
"""
immutable User
    root    :: Compat.String
    source  :: Compat.String
    build   :: Compat.String
    format  :: Formats.Format
    clean   :: Bool
    doctest :: Bool
    modules :: Set{Module}
end

"""
Private state used to control the generation process.
"""
immutable Internal
    assets  :: Compat.String
    pages   :: Dict{Compat.String, Page}
    headers :: Anchors.AnchorMap
    docs    :: Anchors.AnchorMap
    objects :: ObjectIdDict
end

# Document.
# ---------

"""
Represents an entire document.
"""
immutable Document
    user     :: User
    internal :: Internal
end

function Document(;
        root     :: AbstractString   = Utilities.currentdir(),
        source   :: AbstractString   = "src",
        build    :: AbstractString   = "build",
        format   :: Formats.Format   = Formats.Markdown,
        clean    :: Bool             = true,
        doctest  :: Bool             = true,
        modules  :: Utilities.ModVec = Module[],
        others...
    )
    Utilities.check_kwargs(others)

    user = User(
        root,
        source,
        build,
        format,
        clean,
        doctest,
        Utilities.submodules(modules)
    )
    internal = Internal(
        Utilities.assetsdir(),
        Dict{Compat.String, Page}(),
        Anchors.AnchorMap(),
        Anchors.AnchorMap(),
        ObjectIdDict(),
    )
    Document(user, internal)
end

function addpage!(doc::Document, src::AbstractString, dst::AbstractString)
    page = Page(src, dst)
    doc.internal.pages[src] = page
end

end
