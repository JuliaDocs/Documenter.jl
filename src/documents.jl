# Defines [`Document`](@ref) and its supporting types

# When processing the AST during the build, in the MarkdownAST representation, we
# replace various code blocks etc. with Documenter-specific elements that the writers
# then can dispatch on. All the Documenter elements are subtypes of this node.
abstract type AbstractDocumenterBlock <: MarkdownAST.AbstractBlock end

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
    source      :: String
    build       :: String
    workdir :: Union{Symbol,String}
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
    globals  :: Globals
    mdast   :: MarkdownAST.Node{Nothing}
end
function Page(source::AbstractString, build::AbstractString, workdir::AbstractString)
    # The Markdown standard library parser is sensitive to line endings:
    #   https://github.com/JuliaLang/julia/issues/29344
    # This can lead to different AST and therefore differently rendered docs, depending on
    # what platform the docs are being built (e.g. when Git checks out LF files with
    # CRFL line endings on Windows). To make sure that the docs are always built consistently,
    # we'll normalize the line endings when parsing Markdown files by removing all CR characters.
    mdsrc = replace(read(source, String), '\r' => "")
    mdpage = Markdown.parse(mdsrc)
    mdast = try
        convert(MarkdownAST.Node, mdpage)
    catch err
        @error """
            MarkdownAST conversion error on $(source).
            This is a bug — please report this on the Documenter issue tracker
            """
        rethrow(err)
    end
    Page(source, build, workdir, mdpage.content, Globals(), mdast)
end

# FIXME -- special overload for parseblock
parseblock(code::AbstractString, doc, page::Documenter.Page; kwargs...) = parseblock(code, doc, page.source; kwargs...)

# Document blueprints.
# --------------------

# Should contain all the information that is necessary to build a document.
# Currently has enough information to just run doctests.
struct DocumentBlueprint
    pages :: Dict{String, Page} # Markdown files only.
    modules :: Set{Module} # Which modules to check for missing docs?
end


# Document Nodes.
# ---------------

## IndexNode.

struct IndexNode <: AbstractDocumenterBlock
    pages       :: Vector{String} # Which pages to include in the index? Set by user.
    modules     :: Vector{Module} # Which modules to include? Set by user.
    order       :: Vector{Symbol} # What order should docs be listed in? Set by user.
    build       :: String         # Path to the file where this index will appear.
    source      :: String         # Path to the file where this index was written.
    elements    :: Vector         # (object, doc, page, mod, cat)-tuple for constructing links.
    codeblock   :: MarkdownAST.CodeBlock # original code block

    function IndexNode(codeblock;
            # TODO: Fix difference between uppercase and lowercase naming of keys.
            #       Perhaps deprecate the uppercase versions? Same with `ContentsNode`.
            Pages   = [],
            Modules = [],
            Order   = [:module, :constant, :type, :function, :macro],
            build   = error("missing value for `build` in `IndexNode`."),
            source  = error("missing value for `source` in `IndexNode`."),
            others...
        )
        new(Pages, Modules, Order, build, source, [], codeblock)
    end
end

## ContentsNode.

struct ContentsNode <: AbstractDocumenterBlock
    pages       :: Vector{String} # Which pages should be included in contents? Set by user.
    mindepth    :: Int            # Minimum header level that should be displayed. Set by user.
    depth       :: Int            # Down to which level should headers be displayed? Set by user.
    build       :: String         # Same as for `IndexNode`s.
    source      :: String         # Same as for `IndexNode`s.
    elements    :: Vector         # (order, page, anchor)-tuple for constructing links.
    codeblock   :: MarkdownAST.CodeBlock # original code block

    function ContentsNode(codeblock;
            Pages  = [],
            Depth  = 1:2,
            build  = error("missing value for `build` in `ContentsNode`."),
            source = error("missing value for `source` in `ContentsNode`."),
            others...
        )
        if Depth isa Integer
            Depth = 1:Depth
        end
        new(Pages, first(Depth), last(Depth), build, source, [], codeblock)
    end
end

## Other nodes

struct MetaNode <: AbstractDocumenterBlock
    codeblock :: MarkdownAST.CodeBlock
    dict :: Dict{Symbol, Any}
end

struct MethodNode
    method  :: Method
    visible :: Bool
end

struct DocsNode <: AbstractDocumenterBlock
    anchor  :: Anchors.Anchor
    object  :: Object
    page    :: Documenter.Page
    # MarkdownAST support.
    # TODO: should be the docstring components (i.e. .mdasts) be stored as child nodes?
    mdasts  :: Vector{MarkdownAST.Node{Nothing}}
    results :: Vector{Base.Docs.DocStr}
    metas   :: Vector{Dict{Symbol, Any}}
    function DocsNode(anchor, object, page)
        new(anchor, object, page, [], [], [])
    end
end

struct DocsNodes
    nodes :: Vector{Union{DocsNode,Markdown.Admonition}}
end

struct EvalNode <: AbstractDocumenterBlock
    codeblock :: MarkdownAST.CodeBlock
    result :: Union{MarkdownAST.Node, Nothing}
end

struct RawNode <: AbstractDocumenterBlock
    name::Symbol
    text::String
end

# MultiOutput contains child nodes in .content that are either code blocks or
# dictionaries corresponding to the outputs rendered with various MIME types.
# In the MarkdownAST representation, the dictionaries get converted into
# MultiOutputElement elements.
struct MultiOutput <: AbstractDocumenterBlock
    codeblock :: MarkdownAST.CodeBlock
end

# For @repl blocks we store the inputs and outputs as separate Markdown.Code
# objects, and then combine them in the writer. When converting to MarkdownAST,
# those separate code blocks become child nodes.
struct MultiCodeBlock <: AbstractDocumenterBlock
    codeblock :: MarkdownAST.CodeBlock
    language::String
    content::Vector{Markdown.Code}
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
    the string should be a valid key in `doc.blueprint.pages`
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
# This method ensures that we do not print the whole navtree in case we ever happen to print
# a NavNode in some debug output somewhere.
function Base.show(io::IO, n::NavNode)
    parent = isnothing(n.parent) ? "nothing" : "NavNode($(repr(n.parent.page)), ...)"
    print(io, "NavNode($(repr(n.page)), $(repr(n.title_override)), $(parent))")
end

"""
Constructs a list of the ancestors of the `navnode` (including the `navnode` itself),
ordered so that the root of the navigation tree is the first and `navnode` itself
is the last item.
"""
navpath(navnode::NavNode) = navnode.parent === nothing ? [navnode] :
    push!(navpath(navnode.parent), navnode)


# Inner Document Fields.
# ----------------------

# Represents a 'root path' => (Remote, commit/branch) mapping.
struct RemoteRepository
    # Path to the root of the repository on the local machine
    root::String
    remote::Remotes.Remote
    # Note: in the HTML output you can override whether edit links
    # point to commits or main/master. But this here should still be a commit, since
    # it is predominantly used for source links in docstrings (when manually specified
    # via the remotes argument).
    commit::String
end
function RemoteRepository(root::AbstractString, remote::Remotes.Remote)
    RemoteRepository(root, remote, repo_commit(root))
end

"""
User-specified values used to control the generation process.
"""
struct User
    root    :: String  # An absolute path to the root directory of the document.
    source  :: String  # Parent directory is `.root`. Where files are read from.
    build   :: String  # Parent directory is also `.root`. Where files are written to.
    workdir :: Union{Symbol,String} # Parent directory is also `.root`. Where code is executed from.
    format  :: Vector{Writer} # What format to render the final document with?
    clean   :: Bool           # Empty the `build` directory before starting a new build?
    doctest :: Union{Bool,Symbol} # Run doctests?
    linkcheck::Bool           # Check external links..
    linkcheck_ignore::Vector{Union{String,Regex}}  # ..and then ignore (some of) them.
    linkcheck_timeout::Real   # ..but only wait this many seconds for each one.
    checkdocs::Symbol         # Check objects missing from `@docs` blocks. `:none`, `:exports`, or `:all`.
    doctestfilters::Vector{Regex} # Filtering for doctests
    strict::Union{Bool,Symbol,Vector{Symbol}} # Throw an exception when any warnings are encountered.
    pages   :: Vector{Any}    # Ordering of document pages specified by the user.
    pagesonly :: Bool         # Discard any .md pages from processing that are not in .pages
    expandfirst::Vector{String} # List of pages that get "expanded" before others
    # Remote Git repository information
    #
    # .remote is the remote corresponding to the main package / project repository.
    #  It is used for issue references, the repo-wide "GitHub" links and such, but not
    # to figure out where to link files to.
    #
    # .remotes is an array of (path, remote) pairs, where the path is the absolute path
    # to the root of the directory that contains the repository `remote`. The array
    # is sorted by having the longer prefixes first, so that you could have nested
    # repositories as well. When we try to match a file path with a remote, we can just
    # walk through the list and do a startswith(), and take the first one that matches.
    #
    # While the initial list in .remotes is populated when we construct the Document
    # object, we also dynamically add links to the .remotes array as we check different
    # files, by looking at .git directories.
    remote  :: Union{Remotes.Remote,Nothing}
    remotes :: Vector{RemoteRepository}
    sitename:: String
    authors :: String
    version :: String # version string used in the version selector by default
    highlightsig::Bool  # assume leading unlabeled code blocks in docstrings to be Julia.
    draft :: Bool
end

"""
Private state used to control the generation process.
"""
struct Internal
    assets  :: String             # Path where asset files will be copied to.
    navtree :: Vector{NavNode}           # A vector of top-level navigation items.
    navlist :: Vector{NavNode}           # An ordered list of `NavNode`s that point to actual pages
    headers :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `Markdown.Header` objects.
    docs    :: Anchors.AnchorMap         # See `modules/Anchors.jl`. Tracks `@docs` docstrings.
    bindings:: IdDict{Any,Any}           # Tracks insertion order of object per-binding.
    objects :: IdDict{Any,Any}           # Tracks which `Objects` are included in the `Document`.
    contentsnodes :: Vector{ContentsNode}
    indexnodes    :: Vector{IndexNode}
    locallinks :: IdDict{MarkdownAST.Link, String}
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
    plugins  :: Dict{DataType, Plugin}
    blueprint :: DocumentBlueprint
end

function Document(plugins = nothing;
        root     :: AbstractString   = currentdir(),
        source   :: AbstractString   = "src",
        build    :: AbstractString   = "build",
        workdir  :: Union{Symbol, AbstractString}  = :build,
        format   :: Any              = HTML(),
        clean    :: Bool             = true,
        doctest  :: Union{Bool,Symbol} = true,
        linkcheck:: Bool             = false,
        linkcheck_ignore :: Vector   = [],
        linkcheck_timeout :: Real    = 10,
        checkdocs::Symbol            = :all,
        doctestfilters::Vector{Regex}= Regex[],
        strict::Union{Bool,Symbol,Vector{Symbol}} = false,
        modules  :: ModVec = Module[],
        pages    :: Vector           = Any[],
        pagesonly:: Bool             = false,
        expandfirst :: Vector        = String[],
        repo     :: Union{Remotes.Remote, AbstractString} = "",
        remotes  :: Dict             = Dict(),
        sitename :: AbstractString   = "",
        authors  :: AbstractString   = "",
        version :: AbstractString    = "",
        highlightsig::Bool           = true,
        draft::Bool                  = false,
        others...
    )

    check_strict_kw(strict)
    check_kwargs(others)

    if !isa(format, AbstractVector)
        format = Writer[format]
    end

    if version == "git-commit"
        version = "git:$(get_commit_short(root))"
    end

    # We'll normalize repo to be a `Remotes.Remote` object
    repo_normalized::Union{Remotes.Remote, Nothing} = if isa(repo, AbstractString) && isempty(repo)
        # If the user does not provide the `repo` argument, we'll try to automatically
        # detect the remote repository later. But for now, we'll set it to `nothing`.
        nothing
    elseif repo isa AbstractString
        # Use the old template string parsing logic if a string was passed.
        Remotes.URL(repo)
    else
        # Otherwise it should be some Remote object, so we'll just use that.
        repo
    end

    # For `remotes`, we'll first validate that the array provided by the user contains
    # valid path-remote pairs.
    remotes_checked = RemoteRepository[]
    for (path, remoteref) in remotes
        # The paths should be relative to the directory containing make.jl (or, more generally, to the root
        # argument of makedocs)
        path = joinpath(root, path)
        if !isdir(path)
            throw(ArgumentError(("Invalid local path in remotes (not a directory): $(path)")))
        end
        path = realpath(path)
        # We'll also check that there are no duplicate entries.
        idx = findfirst(isequal(path), [remote.root for remote in remotes_checked])
        if !isnothing(idx)
            throw(ArgumentError("""
            Duplicate remote path in remotes: $(path) => $(remote)
            vs $(remotes_checked[idx])
            """))
        end
        # Now we actually check the remotes themselves
        remote = if isa(remoteref, Tuple{Remotes.Remote, AbstractString}) && length(remoteref) == 2
            RemoteRepository(path, remoteref[1], remoteref[2])
        elseif remoteref isa Remotes.Remote
            RemoteRepository(path, remoteref[1])
        else
            throw(ArgumentError("""
            Invalid remote in remotes: $(remote) (::$(typeof(remote)))
            for path $path
            must be ::Remotes.Remote or ::Tuple{Remotes.Remote, AbstractString}"""))
        end
        push!(remotes_checked, remote)
    end

    # Now we sort out the interaction between `repo` and `remotes`. Our goal is to make sure that we have a
    # value in both remotes for the repository root, and also repo is populated. Although it is possible
    # that automatically determining those will fail.
    repo_root, idx = let repo_root = find_root_parent(is_git_repo_root, root)
        if isnothing(repo_root)
            nothing, nothing
        else
            repo_root = realpath(repo_root)
            idx = findfirst(isequal(repo_root), [r.root for r in remotes_checked])
            repo_root, idx
        end
    end
    # If repo_root is not present in remotes, we'll try to determine the (GitHub) remote from the Git origin
    # and just push that
    if isnothing(repo_normalized)
        # If the user did not provide a repo argument, but we do find one in remotes that corresponds
        # to the repository root, we just use that. If we can't find one in remotes, however, we will
        # try to automatically determine the remote from the Git origin.
        if !isnothing(idx)
            repo_normalized = remotes_checked[idx][2]
        elseif !isnothing(repo_root)
            # This only works for GitHub-bases repositories.
            repo_normalized = getremote(repo_root)
            if isnothing(repo_normalized)
                @warn """
                Unable to automatically determine the remote repository corresponding to the repository root.
                This is likely because the repository is not hosted on GitHub. Please explicitly set the `repo`
                argument in `makedocs`.
                """ repo_root
            else
                # Since repo_root was not present in remotes, we'll push the automatically determined
                # one to remotes_checked
                push!(remotes_checked, RemoteRepository(repo_root, repo_normalized))
            end
        else
            @warn """
            Unable to automatically determine the remote repository. Various automatically generated
            links will likely be broken. Please explicitly set the `repo` argument in `makedocs`.
            """ repo_root
        end
    elseif !isnothing(repo_normalized) && isnothing(idx)
        # If the user did provide a repo argument, but we don't find one in remotes that corresponds
        # to the repository root, we will push the user-provided one to remotes_checked
        push!(remotes_checked, RemoteRepository(repo_root, repo_normalized))
    else
        # If the two values for the same directory (from repo and remotes) don't match, we will throw an
        # error. Note: this does require a sane == implementation for the Remotes.Remote objects.
        if remotes_checked[idx][2] != repo_normalized
            throw(ArgumentError("""
            A remote in remotes conflicts with the `repo` argument:
              repo = $(repo_normalized)
              remotes = $(remotes_checked[idx])
              path = $(repo_root)
            """))
        end
        # If the two are equal, then we don't really need to do anything since we have the correct and
        # matching information in both `remotes` and `repo`.
    end

    # At this point we assume that all the paths are absolute and fully resolved, so
    # we can check for subpaths by just doing startswith. This also means that any path
    # that is longer than another will be a subpath (as we assume they are all directories
    # as well). So we put the longest names first in the list, and check for subpaths
    # by just linearly walking through this list.
    sortremotes!(remotes_checked)

    user = User(
        root,
        source,
        build,
        workdir,
        format,
        clean,
        doctest,
        linkcheck,
        linkcheck_ignore,
        linkcheck_timeout,
        checkdocs,
        doctestfilters,
        strict,
        pages,
        pagesonly,
        expandfirst,
        repo_normalized,
        remotes_checked,
        sitename,
        authors,
        version,
        highlightsig,
        draft,
    )
    internal = Internal(
        assetsdir(),
        [],
        [],
        Anchors.AnchorMap(),
        Anchors.AnchorMap(),
        IdDict{Any,Any}(),
        IdDict{Any,Any}(),
        [],
        [],
        Dict{Markdown.Link, String}(),
        Set{Symbol}()
    )

    plugin_dict = Dict{DataType, Plugin}()
    if plugins !== nothing
        for plugin in plugins
            plugin isa Plugin ||
                throw(ArgumentError("$(typeof(plugin)) is not a subtype of `Plugin`."))
            haskey(plugin_dict, typeof(plugin)) &&
                throw(ArgumentError("only one copy of $(typeof(plugin)) may be passed."))
            plugin_dict[typeof(plugin)] = plugin
        end
    end

    blueprint = DocumentBlueprint(
        Dict{String, Page}(),
        submodules(modules),
    )
    Document(user, internal, plugin_dict, blueprint)
end

function addremote!(doc::Document, remoteref::RemoteRepository)
    for ref in doc.user.remotes
        if ref.root == remoteref.root
            error("Duplicate path in doc.user.remotes: $(remoteref.root)")
        end
    end
    push!(doc.user.remotes, remoteref)
    sortremotes!(doc.user.remotes)
    return nothing
end
# We'll sort the remotes, first, to make sure that the longer paths come first,
# so that we could match them first. How the individual paths are sorted is pretty
# unimportant, but we just want to make sure they are sorted in some well-defined
# order.
sortremotes!(remotes::Vector{RemoteRepository}) = sort!(remotes, lt = lt_remotepair)
function lt_remotepair(r1::RemoteRepository, r2::RemoteRepository)
    if length(r1.root) == length(r2.root)
        return r1.root < r2.root
    end
    return length(r1.root) > length(r2.root)
end

"""
    $(SIGNATURES)

Returns the path of `file`, relative to the root of the Git repository, or `nothing` if the
file is not in a Git repository.
"""
function relpath_from_remote_root(doc::Document, file::AbstractString)
    isfile(file) || error("relpath_from_repo_root called with nonexistent file: $file")
    isabspath(file) || error("relpath_from_repo_root called with non-absolute path: $file")
    # We want to expand the path properly, including symlinks, so we call realpath()
    # Note: it throws for non-existing files, but we just checked for it.
    file = realpath(file)
    # Try to see if `file` falls into any of the remotes in .remotes, or if it's a GitHub repository
    # we can automatically "configure".
    root_remote::Union{RemoteRepository,Nothing} = nothing
    root_directory = find_root_parent(file) do directory
        # First, we'll check the list of existing remotes, to see if the directory is already
        # listed there. If yes, we just return that.
        for remoteref in doc.user.remotes
            if directory == remoteref.root
                root_remote = remoteref
                return true
            end
        end
        # If it is not in .remotes, it is still possible that the directory is a Git repository.
        # In that case, we add it to .remotes.
        if is_git_repo_root(directory)
            # getremote() can only detect GitHub repositories right now, so there is a good
            # chance that it will return `nothing`. In that we also abort the check, because
            # we won't be able to correctly determine the remote (as we might incorrectly fall
            # back to the remote of one of the parent directories).
            remote = getremote(directory)
            if isnothing(remote)
                return true
            else
                # TODO: we might need the ability to skip the remote auto detection for certain
                # directories.. This could be done by allowing e.g. `nothing`s in `doc.user.remotes`
                # and `continue`-ing if we detect that. But let's not add that complexity now.
                remoteref = RemoteRepository(directory, remote)
                addremote!(doc, remoteref)
                root_remote = remoteref
            end
            return true
        end
        return false
    end
    # If we were not able to detect the remote
    if isnothing(root_remote)
        return nothing, nothing, nothing
    else
        # When root_remote is set, so should be root_directory
        @assert !isnothing(root_directory)
        return root_remote.remote, relpath(file, root_directory), root_remote.commit
    end
end

function edit_url(doc::Document, file; commit::AbstractString)
    # We'll prepend doc.user.root, unless already an absolute path.
    file = abspath(doc.user.root, file)
    if !isfile(file)
        @warn "couldn't find file \"$file\" when generating URL"
        return nothing
    end
    remote, relpath, commit = relpath_from_remote_root(doc, file)
    isnothing(relpath) || isnothing(remote) ? nothing : repofile(remote, commit, relpath)
end

source_url(doc::Document, docstring) = source_url(
    doc, docstring.data[:module], docstring.data[:path], linerange(docstring)
)

function source_url(doc::Document, mod, file, linerange)
    file === nothing && return nothing # needed since julia v0.6, see #689
    # Non-absolute paths generally indicate methods from Base.
    if inbase(mod) || !isabspath(file)
        ref = if isempty(Base.GIT_VERSION_INFO.commit)
            "v$VERSION"
        else
            Base.GIT_VERSION_INFO.commit
        end
        return repofile(julia_remote, ref, "base/$file", linerange)
    end
    # Generally, we assume that the Julia source file exists on the system.
    isfile(file) || return nothing
    remote, relpath, commit = relpath_from_remote_root(doc, file)
    if isnothing(relpath) || isnothing(remote)
        return nothing
    end
    return repofile(remote, commit, relpath, linerange)
end

"""
    getplugin(doc::Document, T)

Retrieves the [`Plugin`](@ref Plugin) type for `T` stored in `doc`. If `T` was passed to
[`makedocs`](@ref makedocs), the passed type will be returned. Otherwise, a new `T` object
will be created using the default constructor `T()`.
"""
function getplugin(doc::Document, plugin_type::Type{T}) where T <: Plugin
    if !haskey(doc.plugins, plugin_type)
        doc.plugins[plugin_type] = plugin_type()
    end

    doc.plugins[plugin_type]
end

## Methods

function addpage!(doc::Document, src::AbstractString, dst::AbstractString, wd::AbstractString)
    page = Page(src, dst, wd)
    # page's identifier is the path relative to the `doc.user.source` directory
    name = normpath(relpath(src, doc.user.source))
    doc.blueprint.pages[name] = page
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
        cat  = Symbol(lowercase(doccat(object.binding, Union{})))
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
                # Note: This only filters based on contents.depth and *not* contents.mindepth.
                #       Instead the writers who support this adjust this when rendering.
                if _isvalid(page, contents.pages) && anchor.object.level ≤ contents.depth
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

# some replacements for jldoctest blocks
function doctest_replace!(doc::Documenter.Document)
    for (src, page) in doc.blueprint.pages
        doctest_replace!(page.mdast)
    end
end
function doctest_replace!(ast::MarkdownAST.Node)
    for node in AbstractTrees.PreOrderDFS(ast)
        doctest_replace!(node.element)
    end
end
doctest_replace!(docsnode::DocsNode) = foreach(doctest_replace!, docsnode.mdasts)
function doctest_replace!(block::MarkdownAST.CodeBlock)
    startswith(block.info, "jldoctest") || return
    # suppress output for `#output`-style doctests with `output=false` kwarg
    if occursin(r"^# output$"m, block.code) && occursin(r";.*output\h*=\h*false", block.info)
        input = first(split(block.code, "# output\n", limit = 2))
        block.code = rstrip(input)
    end
    # correct the language field
    block.info = occursin(r"^julia> "m, block.code) ? "julia-repl" : "julia"
end
doctest_replace!(@nospecialize _) = nothing

function buildnode(T::Type, block, doc, page)
    mod  = get(page.globals.meta, :CurrentModule, Main)
    dict = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in parseblock(block.code, doc, page)
        if isassign(ex)
            cd(dirname(page.source)) do
                dict[ex.args[1]] = Core.eval(mod, ex.args[2])
            end
        end
    end
    T(block; dict...)
end

function _compare(col, ind, a, b)
    x, y = a[ind], b[ind]
    haskey(col, x) && haskey(col, y) ? _compare(col[x], col[y]) : 0
end
_compare(a, b)  = a < b ? -1 : a == b ? 0 : 1
_isvalid(x, xs) = isempty(xs) || x in xs
precedence(vec) = Dict(zip(vec, 1:length(vec)))

###########################################################################################
# Conversion to MarkdownAST, for writers

struct AnchoredHeader <: AbstractDocumenterBlock
    anchor :: Anchors.Anchor
end
MarkdownAST.iscontainer(::AnchoredHeader) = true

# A DocsNodesBlock corresponds to one @docs (or @autodocs) code block, and contains
# a list of docstrings, which are represented as child nodes of type DocsNode.
# In addition, the child node can also be an Admonition in case there was an error
# in splicing in a docstring.
struct DocsNodesBlock <: AbstractDocumenterBlock
    codeblock :: MarkdownAST.CodeBlock
end
MarkdownAST.iscontainer(::DocsNodesBlock) = true
MarkdownAST.can_contain(::DocsNodesBlock, ::MarkdownAST.AbstractElement) = false
MarkdownAST.can_contain(::DocsNodesBlock, ::Union{DocsNode, MarkdownAST.Admonition}) = true

MarkdownAST.iscontainer(::MultiCodeBlock) = true
MarkdownAST.can_contain(::MultiCodeBlock, ::MarkdownAST.Code) = true

struct MultiOutputElement <: AbstractDocumenterBlock
    element :: Any
end
MarkdownAST.iscontainer(::MultiOutput) = true
MarkdownAST.can_contain(::MultiOutput, ::Union{MultiOutputElement,MarkdownAST.CodeBlock}) = true

# In the SetupBlocks expander, we map @setup nodes to Markdown.MD() objects
struct SetupNode <: AbstractDocumenterBlock
    name :: String
    code :: String
end

# Override the show for DocumenterBlockTypes so that we would not print too much
# information when we happen to show the AST.
Base.show(io::IO, node::AbstractDocumenterBlock) = print(io, typeof(node), "([...])")

# Extend MDFlatten.mdflatten to support the Documenter-specific elements
MDFlatten.mdflatten(io, node::MarkdownAST.Node, ::AnchoredHeader) = MDFlatten.mdflatten(io, node.children)
MDFlatten.mdflatten(io, node::MarkdownAST.Node, e::SetupNode) = MDFlatten.mdflatten(io, node, MarkdownAST.CodeBlock(e.name, e.code))
MDFlatten.mdflatten(io, node::MarkdownAST.Node, e::RawNode) = MDFlatten.mdflatten(io, node, MarkdownAST.CodeBlock("@raw $(e.name)", e.text))
MDFlatten.mdflatten(io, node::MarkdownAST.Node, e::AbstractDocumenterBlock) = MDFlatten.mdflatten(io, node, e.codeblock)
function MDFlatten.mdflatten(io, ::MarkdownAST.Node, e::DocsNode)
    # this special case separates top level blocks with newlines
    for node in e.mdasts
        MDFlatten.mdflatten(io, node)
        # Docstrings are double wrapped in MD objects, and so led to extra newlines
        # in the old Markdown-based mdflatten()
        print(io, "\n\n\n\n")
    end
end
