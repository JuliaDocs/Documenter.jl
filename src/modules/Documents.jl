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
    remote  :: Compat.String
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
        Utilities.getremote(root),
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

# Document Nodes.
# ---------------

## IndexNode.

immutable IndexNode
    pages    :: Vector{String}
    modules  :: Vector{Module}
    order    :: Vector{Symbol}
    build    :: String
    source   :: String
    elements :: Vector

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

function populate!(index::IndexNode, doc::Document)
    # Filtering valid index links.
    for (object, doc) in doc.internal.objects
        page = relpath(doc.page.build, dirname(index.build))
        mod  = object.binding.mod
        cat  = Symbol(lowercase(Utilities.doccat(object)))
        if _isvalid(page, index.pages) && _isvalid(mod, index.modules) && _isvalid(cat, index.order)
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


## ContentsNode.

immutable ContentsNode
    pages    :: Vector{String}
    depth    :: Int
    build    :: String
    source   :: String
    elements :: Vector

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

function populate!(contents::ContentsNode, doc::Document)
    # Filtering valid contents links.
    for (id, filedict) in doc.internal.headers.map
        for (file, anchors) in filedict
            for anchor in anchors
                page = relpath(anchor.file, dirname(contents.build))
                if _isvalid(page, contents.pages) && Utilities.header_level(anchor.object) ≤ contents.depth
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

function buildnode(T::Type, block, page)
    mod  = get(page.globals.meta, :CurrentModule, current_module())
    dict = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(block.code)
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
