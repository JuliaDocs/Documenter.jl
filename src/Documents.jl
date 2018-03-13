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
    Utilities,
    IdDict

using Compat, DocStringExtensions
import Compat.Markdown
using Compat.Unicode

# Pages.
# ------

"""
[`Page`](@ref)-local values such as current module that are shared between nodes in a page.
"""
mutable struct Globals
    mod  :: Module
    meta :: Dict{Symbol, Any}
end
Globals() = Globals(Main, Dict())

"""
Represents a single markdown file.
"""
struct Page
    source   :: String
    build    :: String
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
    mapping  :: IdDict
    globals  :: Globals
end
function Page(source::AbstractString, build::AbstractString)
    elements = Markdown.parse(read(source, String)).content
    Page(source, build, elements, IdDict(), Globals())
end

# Document Nodes.
# ---------------

## IndexNode.

struct IndexNode
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

struct ContentsNode
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

struct MetaNode
    dict :: Dict{Symbol, Any}
end

struct MethodNode
    method  :: Method
    visible :: Bool
end

struct DocsNode
    docstr  :: Any
    anchor  :: Anchors.Anchor
    object  :: Utilities.Object
    page    :: Documents.Page
end

struct DocsNodes
    nodes :: Vector{DocsNode}
end

struct EvalNode
    code   :: Markdown.Code
    result :: Any
end

struct RawHTML
    code::String
end

struct RawNode
    name::Symbol
    text::String
end

# Navigation
# ----------------------

"""
Element in the navigation tree of a document, containing navigation references
to other page, reference to the [`Page`](@ref) object etc.
"""
mutable struct NavNode
    """
    `nothing` if the `NavNode` is a non-page node of the navigation tree, otherwise
    the string should be a valid key in `doc.internal.pages`
    """
    page           :: Union{String, Nothing}
    """
    If not `nothing`, specifies the text that should be displayed in navigation
    links etc. instead of the automatically determined text.
    """
    title_override :: Union{String, Nothing}
    parent         :: Union{NavNode, Nothing}
    children       :: Vector{NavNode}
    visible        :: Bool
    prev           :: Union{NavNode, Nothing}
    next           :: Union{NavNode, Nothing}
end
NavNode(page, title_override, parent) = NavNode(page, title_override, parent, [], true, nothing, nothing)

"""
Constructs a list of the ancestors of the `navnode` (inclding the `navnode` itself),
ordered so that the root of the navigation tree is the first and `navnode` itself
is the last item.
"""
navpath(navnode::NavNode) = navnode.parent === nothing ? [navnode] :
    push!(navpath(navnode.parent), navnode)


# Inner Document Fields.
# ----------------------

"""
User-specified values used to control the generation process.
"""
struct User
    root    :: String  # An absolute path to the root directory of the document.
    source  :: String  # Parent directory is `.root`. Where files are read from.
    build   :: String  # Parent directory is also `.root`. Where files are written to.
    format  :: Vector{Symbol} # What format to render the final document with?
    clean   :: Bool           # Empty the `build` directory before starting a new build?
    doctest :: Union{Bool,Symbol} # Run doctests?
    linkcheck::Bool           # Check external links..
    linkcheck_ignore::Vector{Union{String,Regex}}  # ..and then ignore (some of) them.
    checkdocs::Symbol         # Check objects missing from `@docs` blocks. `:none`, `:exports`, or `:all`.
    doctestfilters::Vector{Regex} # Filtering for doctests
    strict::Bool              # Throw an exception when any warnings are encountered.
    modules :: Set{Module}    # Which modules to check for missing docs?
    pages   :: Vector{Any}    # Ordering of document pages specified by the user.
    assets  :: Vector{String}
    repo    :: String  # Template for URL to source code repo
    sitename:: String
    authors :: String
    analytics::String
    version :: String # version string used in the version selector by default
    html_prettyurls :: Bool # Use pretty URLs in the HTML build?
    html_disable_git :: Bool # Don't call git when exporting HTML
    html_edit_branch :: Union{String, Nothing} # Change how the "Edit on GitHub" links are handled
    html_canonical   :: Union{String, Nothing} # Set a canonical url, if desired (https://en.wikipedia.org/wiki/Canonical_link_element)
end

"""
Private state used to control the generation process.
"""
struct Internal
    assets  :: String             # Path where asset files will be copied to.
    remote  :: String             # The remote repo on github where this package is hosted.
    pages   :: Dict{String, Page} # Markdown files only.
    navtree :: Vector{NavNode}           # A vector of top-level navigation items.
    navlist :: Vector{NavNode}           # An ordered list of `NavNode`s that point to actual pages
    headers :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `Markdown.Header` objects.
    docs    :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `@docs` docstrings.
    bindings:: IdDict                    # Tracks insertion order of object per-binding.
    objects :: IdDict                    # Tracks which `Utilities.Objects` are included in the `Document`.
    contentsnodes :: Vector{ContentsNode}
    indexnodes    :: Vector{IndexNode}
    locallinks :: Dict{Markdown.Link, String}
    errors::Set{Symbol}
end

# Document.
# ---------

"""
Represents an entire document.
"""
struct Document
    user     :: User     # Set by the user via `makedocs`.
    internal :: Internal # Computed values.
end

function Document(;
        root     :: AbstractString   = Utilities.currentdir(),
        source   :: AbstractString   = "src",
        build    :: AbstractString   = "build",
        format   :: Any              = :markdown,
        clean    :: Bool             = true,
        doctest  :: Union{Bool,Symbol} = true,
        linkcheck:: Bool             = false,
        linkcheck_ignore :: Vector   = [],
        checkdocs::Symbol            = :all,
        doctestfilters::Vector{Regex}= Regex[],
        strict::Bool                 = false,
        modules  :: Utilities.ModVec = Module[],
        pages    :: Vector           = Any[],
        assets   :: Vector           = String[],
        repo     :: AbstractString   = "",
        sitename :: AbstractString   = "",
        authors  :: AbstractString   = "",
        analytics :: AbstractString  = "",
        version :: AbstractString    = "",
        html_prettyurls  :: Bool     = false,
        html_disable_git :: Bool     = false,
        html_edit_branch :: Union{String, Nothing} = "master",
        html_canonical   :: Union{String, Nothing} = nothing,
        others...
    )
    Utilities.check_kwargs(others)

    fmt = Formats.fmt(format)
    @assert !isempty(fmt) "No formats provided."

    if version == "git-commit"
        version = "git:$(Utilities.get_commit_short(root))"
    end

    user = User(
        root,
        source,
        build,
        fmt,
        clean,
        doctest,
        linkcheck,
        linkcheck_ignore,
        checkdocs,
        doctestfilters,
        strict,
        Utilities.submodules(modules),
        pages,
        assets,
        repo,
        sitename,
        authors,
        analytics,
        version,
        html_prettyurls,
        html_disable_git,
        html_edit_branch,
        html_canonical,
    )
    internal = Internal(
        Utilities.assetsdir(),
        Utilities.getremote(root),
        Dict{String, Page}(),
        [],
        [],
        Anchors.AnchorMap(),
        Anchors.AnchorMap(),
        IdDict(),
        IdDict(),
        [],
        [],
        Dict{Markdown.Link, String}(),
        Set{Symbol}(),
    )
    Document(user, internal)
end

## Methods

function addpage!(doc::Document, src::AbstractString, dst::AbstractString)
    page = Page(src, dst)
    # page's identifier is the path relative to the `doc.user.source` directory
    name = normpath(relpath(src, doc.user.source))
    doc.internal.pages[name] = page
end

"""
$(SIGNATURES)

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
    mod  = get(page.globals.meta, :CurrentModule, Main)
    dict = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(block.code, doc, page)
        if Utilities.isassign(ex)
            cd(dirname(page.source)) do
                dict[ex.args[1]] = eval(mod, ex.args[2])
            end
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
