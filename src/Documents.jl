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

import Compat: String

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
    """
    Ordered list of raw toplevel markdown nodes from the parsed page contents. This vector
    should be considered immutable.
    """
    elements :: Vector
    """
    Each element in `.elements` maps to an "expanded" element. This may be itself if the
    element does not need expanding or some other object, such as a `DocsNode` in the case
    of `@docs` code blocks.
    """
    mapping  :: ObjectIdDict
    globals  :: Globals
end
function Page(source::AbstractString, build::AbstractString)
    elements = Base.Markdown.parse(readstring(source)).content
    Page(source, build, elements, ObjectIdDict(), Globals())
end

# Document Nodes.
# ---------------

## IndexNode.

immutable IndexNode
    pages    :: Vector{String} # Which pages to include in the index? Set by user.
    modules  :: Vector{Module} # Which modules to include? Set by user.
    order    :: Vector{Symbol} # What order should docs be listed in? Set by user.
    build    :: String         # Path to the file where this index will appear.
    source   :: String         # Path to the file where this index was written.
    elements :: Vector         # (object, doc, page, mod, cat)-tuple for constructing links.

    function IndexNode(;
            # TODO: Fix difference between uppercase and lowercase naming of keys.
            #       Perhaps deprecate the uppercase versions? Same with `ContentsNode`.
            Pages   = [],
            Modules = [],
            Order   = [:module, :constant, :type, :function, :macro],
            build   = error("missing value for `build` in `IndexNode`."),
            source  = error("missing value for `source` in `IndexNode`."),
            others...
        )
        new(Pages, Modules, Order, build, source, [])
    end
end

## ContentsNode.

immutable ContentsNode
    pages    :: Vector{String} # Which pages should be included in contents? Set by user.
    depth    :: Int            # Down to which level should headers be displayed? Set by user.
    build    :: String         # Same as for `IndexNode`s.
    source   :: String         # Same as for `IndexNode`s.
    elements :: Vector         # (order, page, anchor)-tuple for constructing links.

    function ContentsNode(;
            Pages  = [],
            Depth  = 2,
            build  = error("missing value for `build` in `ContentsNode`."),
            source = error("missing value for `source` in `ContentsNode`."),
            others...
        )
        new(Pages, Depth, build, source, [])
    end
end

## Other nodes

immutable MetaNode
    dict :: Dict{Symbol, Any}
end

immutable MethodNode
    method  :: Method
    visible :: Bool
end

immutable DocsNode
    docstr  :: Any
    anchor  :: Anchors.Anchor
    object  :: Utilities.Object
    page    :: Documents.Page
    """
    Vector of methods associated with this `DocsNode`. Being nulled means that
    conceptually the `DocsNode` has no table of method (as opposed to having
    an empty table).
    """
    methods :: Nullable{Vector{MethodNode}}
end

immutable DocsNodes
    nodes :: Vector{DocsNode}
end

immutable EvalNode
    code   :: Base.Markdown.Code
    result :: Any
end

# Inner Document Fields.
# ----------------------

"""
User-specified values used to control the generation process.
"""
immutable User
    root    :: Compat.String  # An absolute path to the root directory of the document.
    source  :: Compat.String  # Parent directory is `.root`. Where files are read from.
    build   :: Compat.String  # Parent directory is also `.root`. Where files are written to.
    format  :: Formats.Format # What format to render the final document with?
    clean   :: Bool           # Empty the `build` directory before starting a new build?
    doctest :: Bool           # Run doctests?
    modules :: Set{Module}    # Which modules to check for missing docs?
    pages   :: Vector{Any}    # Ordering of document pages specified by the user.
    repo    :: Compat.String  # Template for URL to source code repo
end

"""
Private state used to control the generation process.
"""
immutable Internal
    assets  :: Compat.String             # Path where asset files will be copied to.
    remote  :: Compat.String             # The remote repo on github where this package is hosted.
    pages   :: Dict{Compat.String, Page} # Markdown files only.
    headers :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `Markdown.Header` objects.
    docs    :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `@docs` docstrings.
    bindings:: ObjectIdDict              # Tracks insertion order of object per-binding.
    objects :: ObjectIdDict              # Tracks which `Utilities.Objects` are included in the `Document`.
    contentsnodes :: Vector{ContentsNode}
    indexnodes    :: Vector{IndexNode}
end

# Document.
# ---------

"""
Represents an entire document.
"""
immutable Document
    user     :: User     # Set by the user via `makedocs`.
    internal :: Internal # Computed values.
end

function Document(;
        root     :: AbstractString   = Utilities.currentdir(),
        source   :: AbstractString   = "src",
        build    :: AbstractString   = "build",
        format   :: Formats.Format   = Formats.Markdown,
        clean    :: Bool             = true,
        doctest  :: Bool             = true,
        modules  :: Utilities.ModVec = Module[],
        pages    :: Vector           = Any[],
        repo     :: AbstractString   = "",
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
        Utilities.submodules(modules),
        pages,
        repo,
    )
    internal = Internal(
        Utilities.assetsdir(),
        Utilities.getremote(root),
        Dict{Compat.String, Page}(),
        Anchors.AnchorMap(),
        Anchors.AnchorMap(),
        ObjectIdDict(),
        ObjectIdDict(),
        [],
        []
    )
    Document(user, internal)
end

## Methods

function addpage!(doc::Document, src::AbstractString, dst::AbstractString)
    page = Page(src, dst)
    # the page's name is determined from the file system path, but we need
    # the path relative to `doc.user.source` and must drop the extension
    name = first(splitext(normpath(relpath(src, doc.user.source))))
    doc.internal.pages[name] = page
end

"""
Populates the `ContentsNode`s and `IndexNode`s of the `document` with links.

This can only be done after all the blocks have been expanded (and nodes constructed),
because the items have to exist before we can gather the links to those items.
"""
function populate!(document::Document)
    for node in document.internal.contentsnodes
        populate!(node, document)
    end
    for node in document.internal.indexnodes
        populate!(node, document)
    end
end

function populate!(index::IndexNode, document::Document)
    # Filtering valid index links.
    for (object, doc) in document.internal.objects
        page = relpath(doc.page.build, dirname(index.build))
        mod  = object.binding.mod
        # Include *all* signatures, whether they are `Union{}` or not.
        cat  = Symbol(lowercase(Utilities.doccat(object.binding, Union{})))
        if _isvalid(page, index.pages) && _isvalid(mod, index.modules) && _isvalid(cat, index.order)
            page = Formats.extension(document.user.format, page)
            push!(index.elements, (object, doc, page, mod, cat))
        end
    end
    # Sorting index links.
    pagesmap   = precedence(index.pages)
    modulesmap = precedence(index.modules)
    ordermap   = precedence(index.order)
    comparison = function(a, b)
        (x = _compare(pagesmap,   3, a, b)) == 0 || return x < 0 # page
        (x = _compare(modulesmap, 4, a, b)) == 0 || return x < 0 # module
        (x = _compare(ordermap,   5, a, b)) == 0 || return x < 0 # category
        string(a[1].binding) < string(b[1].binding)              # object name
    end
    sort!(index.elements, lt = comparison)
    return index
end

function populate!(contents::ContentsNode, document::Document)
    # Filtering valid contents links.
    for (id, filedict) in document.internal.headers.map
        for (file, anchors) in filedict
            for anchor in anchors
                page = relpath(anchor.file, dirname(contents.build))
                if _isvalid(page, contents.pages) && Utilities.header_level(anchor.object) ≤ contents.depth
                    page = Formats.extension(document.user.format, page)
                    push!(contents.elements, (anchor.order, page, anchor))
                end
            end
        end
    end
    # Sorting contents links.
    pagesmap   = precedence(contents.pages)
    comparison = function(a, b)
        (x = _compare(pagesmap, 2, a, b)) == 0 || return x < 0 # page
        a[1] < b[1]                                            # anchor order
    end
    sort!(contents.elements, lt = comparison)
    return contents
end

## Utilities.

function buildnode(T::Type, block, doc, page)
    mod  = get(page.globals.meta, :CurrentModule, current_module())
    dict = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(block.code, doc, page)
        if Utilities.isassign(ex)
            dict[ex.args[1]] = eval(mod, ex.args[2])
        end
    end
    T(; dict...)
end

function _compare(col, ind, a, b)
    x, y = a[ind], b[ind]
    haskey(col, x) && haskey(col, y) ? _compare(col[x], col[y]) : 0
end
_compare(a, b)  = a < b ? -1 : a == b ? 0 : 1
_isvalid(x, xs) = isempty(xs) || x in xs
precedence(vec) = Dict(zip(vec, 1:length(vec)))

end
