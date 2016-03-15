__precompile__(true)

module Lapidary

export makedocs, deploydocs

using Base.Meta, Compat

# types
# =====

typealias Str UTF8String

"""
Used to store the current state of the markdown template expansion. This simplifies the
[`expand`]({ref}) methods by avoiding having to thread all the state between each call
manually.
"""
immutable State
    src    :: Str
    dst    :: Str
    blocks :: Vector{Any}
    meta   :: Dict{Symbol, Any}
end
State(src, dst) = State(src, dst, [], Dict())
State()         = State("",  "",  [], Dict())

"""
Represents a file mapping from source file `.src` to destination file `.dst`.
"""
immutable Path
    src :: Str
    dst :: Str
end

"""
Same as [`Path`]({ref}), but also includes the parsed content of the markdown file.
"""
immutable ParsedPath
    src :: Str
    dst :: Str
    ast :: Markdown.MD
end

"""
Represents a file mapping from `.src` to `.dst` of a markdown header element. The `.nth`
field tracks the ordering of the headers within the file.
"""
immutable HeaderPath
    src :: Str
    dst :: Str
    nth :: Int
    ast :: Markdown.Header
end

"""
Stores all the state associated with a document. An instance of this type is threaded
through the sequence of transformations used to build the document.
"""
type Env{MIMETYPE}
    # paths
    root   :: Str
    source :: Str
    build  :: Str
    assets :: Str
    # misc
    clean   :: Bool
    doctest :: Bool
    mime    :: MIMETYPE
    modules :: Vector{Module}
    # state
    template_paths     :: Vector{Path}
    parsed_templates   :: Vector{ParsedPath}
    expanded_templates :: Vector{State}
    state              :: State
    headers            :: Dict{Str, HeaderPath}
    headermap          :: ObjectIdDict
    docsmap            :: ObjectIdDict
end

"""
    Env(kwargs...)

Helper method used to simplidy the construction of [`Env`]({ref}) objects. Takes any number
of keyword arguments. Note that unknown keyword arguments are discarded by this method.
"""
function Env(;
        root    = currentdir(),
        source  = "src",
        build   = "build",
        assets  = assetsdir(),
        clean   = true,
        doctest = true,
        mime    = MIME"text/plain"(),
        modules = Module[]
    )
    Env{typeof(mime)}(
        root, source, build, assets, clean, doctest, mime, modules,
        [], [], [], State(),
        Dict(), ObjectIdDict(), ObjectIdDict()
    )
end

# user-interface
# ==============

"""
    makedocs(
        root    = "<current-directory>",
        source  = "src",
        build   = "build",
        clean   = true,
        doctest = true,
        modules = Module[],
    )

Combines markdown files and inline docstrings into an interlinked document.

In most cases [`makedocs`]({ref}) should be run from a `make.jl` file:

```julia
using Lapidary

makedocs(
    # keywords...
)
```

which is then run from the command line with:

    \$ julia make.jl

The folder structure that [`makedocs`]({ref}) expects looks like:

    docs/
        build/
        src/
        make.jl

**Keywords**

**`root`** is the directory from which `makedocs` should run. When run from a `make.jl` file
this keyword does not need to be set. It is, for the most part, needed when repeatedly
running `makedocs` from the Julia REPL like so:

    julia> makedocs(root = Pkg.dir("MyPackage", "docs"))

**`source`** is the directory, relative to `root`, where the markdown source files are read
from. By convention this folder is called `src`. Note that any non-markdown files stored
in `source` are copied over to the build directory when [`makedocs`]({ref}) is run.

**`build`** is the directory, relative to `root`, into which generated files and folders are
written when [`makedocs`]({ref}) is run. The name of the build directory is, by convention,
called `build`, though, like with `source`, users are free to change this to anything else
to better suit their project needs.

**`clean`** tells [`makedocs`]({ref}) whether to remove all the content from the `build`
folder prior to generating new content from `source`. By default this is set to `true`.

**`doctest`** instructs [`makedocs`]({ref}) on whether to try to test Julia code blocks
that are encountered in the generated document. By default this keyword is set to `true`.
Doctesting should only ever be disabled when initially setting up a newly developed package
where the developer is just trying to get their package and documentation structure correct.
After that, it's encouraged to always make sure that documentation examples are runnable and
produce the expected results. See the [Doctests]({ref}) manual section for details about
running doctests.

**`modules`** specifies a vector of modules that should be documented in `source`. If any
inline docstrings from those modules are seen to be missing from the generated content then
a warning will be printed during execution of [`makedocs`]({ref}). By default no modules are
passed to `modules` and so no warnings will appear. This setting can be used as an indicator
of the "coverage" of the generated documentation.

For example Lapidary's `make.jl` file contains:

```julia
$(strip(readstring(joinpath(dirname(@__FILE__), "..", "docs", "make.jl"))))
```

and so any docstring from the module `Lapidary` that is not spliced into the generated
documentation in `build` will raise a warning.

**See Also**

A guide detailing how to document a package using Lapidary's [`makedocs`]({ref}) is provided
in the [Usage]({ref}) section of the manual.
"""
function makedocs(; debug = false, args...)
    env = Env(; args...)
    cd(env.root) do
        process(
            env,
            SetupBuildDirectory(),
            CopyAssetsDirectory(),
            ParseTemplates(),
            ExpandTemplates(
                FindHeaders(),
                MetaBlock(),
                DocsBlock(),
                EvalBlock(),
                IndexBlock(),
                ContentsBlock(),
                DefaultExpander()
            ),
            CrossReferenceLinks(),
            RunDocTests(),
            CheckDocs(),
            RenderDocument()
        )
    end
    debug ? env : nothing
end

# deploy docs (experimental)
# ==========================

"""
    deploydocs(
        root   = "<current-directory>",
        target = "site",
        repo   = "<required>",
        branch = "gh-pages",
        latest = "master",
        osname = "linux",
        julia  = "nightly",
        deps   = <Function>,
        make   = <Function>,
    )

Converts markdown files generated by [`makedocs`]({ref}) to HTML and pushes them to `repo`.

This function should be called from within a package's `docs/make.jl` file after the call to
[`makedocs`]({ref}), like so

```julia
using Lapidary, PACKAGE_NAME

makedocs(
    # options...
)

deploydocs(
    repo = "github.com/..."
)
```

**Keywords**

**`root`** has the same purpose as the `root` keyword for [`makedocs`]({ref}).

**`target`** is the directory, relative to `root`, where generated HTML content should be
written to. This directory **must** be added to the repository's `.gitignore` file. The
default value is `"site"`.

**`repo`** is the remote repository where generated HTML content should be pushed to. This
keyword *must* be set and will throw an error when left undefined. For example this package
uses the following `repo` value:

    repo = "github.com/MichaelHatherly/Lapidary.jl.git"

**`branch`** is the branch where the generated documentation is pushed. By default this
value is set to `"gh-pages"`.

**`latest`** is the branch that "tracks" the latest generated documentation. By default this
value is set to `"master"`.

**`osname`** is the operating system which will be used to deploy generated documentation.
This defaults to `"linux"`. This value must be one of those specified in the `os:` section
of the `.travis.yml` configuration file.

**`julia`** is the version of Julia that will be used to deploy generated documentation.
This defaults to `"nightly"`. This value must be one of those specified in the `julia:`
section of the `.travis.yml` configuration file.

**`deps`** is the function used to install any dependancies needed to build the
documentation. By default this function installs `pygments` and `mkdocs`:

    deps = () -> run(`pip install --user pygments mkdocs`)

**`make`** is the function used to convert the markdown files to HTML. By default this just
runs `mkdocs build` which populates the `target` directory.

**See Also**

The [Hosting Documentation]({ref}) section of the manual provides a step-by-step guide to
using the [`deploydocs`]({ref}) function to automatically generate docs and push then to
GitHub.
"""
function deploydocs(;
        root    = currentdir(),
        target  = "site",

        repo    = error("no 'repo' keyword provided."),
        branch  = "gh-pages",
        latest  = "master",

        osname  = "linux",
        julia   = "nightly",

        deps    = () -> run(`pip install --user pygments mkdocs`),
        make    = () -> run(`mkdocs build`)
    )
    # Get needed environment variables.
    github_api_key      = get(ENV, "GITHUB_API_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_osname       = get(ENV, "TRAVIS_OS_NAME",       "")
    travis_julia        = get(ENV, "TRAVIS_JULIA_VERSION", "")
    git_rev             = readchomp(`git rev-parse --short HEAD`)

    # When should a deploy be tried?
    should_deploy =
        travis_pull_request == "false" &&
        github_api_key      != ""      &&
        travis_osname       == osname  &&
        travis_julia        == julia   &&
        (
            travis_branch == latest ||
            travis_tag    != ""
        )

    if should_deploy
        # Install dependancies.
        log("installing dependancies.")
        deps()
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            log("setting up target directory.")
            cleandir(target)
            log("building documentation.")
            make()
            log("pushing new documentation to remote: $repo:$branch.")
            mktempdir() do temp
                # Versioned docs directories.
                latest_dir = joinpath(temp, "latest")
                stable_dir = joinpath(temp, "stable")
                tagged_dir = joinpath(temp, travis_tag)
                # Git repo setup.
                cd(temp) do
                    run(`git init`)
                    run(`git config user.name  "autodocs"`)
                    run(`git config user.email "autodocs"`)
                    success(`git remote add upstream "https://$github_api_key@$repo"`) ||
                        error("failed to add remote.")
                    success(`git fetch upstream`) ||
                        error("failed to fetch from remote.")
                    success(`git checkout -b $branch upstream/$branch`) ||
                        error("failed to checkout remote.")
                end
                # Copy generated from target to versioned doc directories.
                if travis_tag == ""
                    cleandir(latest_dir)
                    cp(target, latest_dir, remove_destination = true)
                else
                    cleandir(stable_dir)
                    cleandir(tagged_dir)
                    cp(target, stable_dir, remove_destination = true)
                    cp(target, tagged_dir, remove_destination = true)
                end
                # Commit the generated content to the repo.
                cd(temp) do
                    run(`git add -A .`)
                    run(`git commit -m "build based on $git_rev"`)
                    success(`git push -q upstream HEAD:$branch`) ||
                        error("failed to push to remote.")
                end
            end
        end
    else
        log("skipping docs deployment.")
    end
end

# stages
# ======

function exec end

## setup build directory
## =====================

"""
Cleans out previous `build` directory and rebuilds the folder structure to match that of the
`src` directory. Copies all non-markdown files from `src` to `build`.
"""
immutable SetupBuildDirectory end

function exec(::SetupBuildDirectory, env)
    env.clean && isdir(env.build) && rm(env.build; recursive = true)
    isdir(env.build) || mkdir(env.build)
    if isdir(env.source)
        for (root, dirs, files) in walkdir(env.source)
            for dir in dirs
                d = normpath(joinpath(env.build, relpath(root, env.source), dir))
                isdir(d) || mkdir(d)
            end
            for file in files
                src = normpath(joinpath(root, file))
                dst = normpath(joinpath(env.build, relpath(root, env.source), file))
                if endswith(src, ".md")
                    push!(env.template_paths, Path(src, dst))
                else
                    cp(src, dst; remove_destination = true)
                end
            end
        end
    else
        error("source directory '$(abspath(env.source))' is missing.")
    end
end
log(io, ::SetupBuildDirectory) = log(io, "setting up build directory.")

## copy asset directory
## ====================

"""
Copies the contents of the Lapidary `assets` folder to `build/assets`.

Will throw an error if the directory already exists.
"""
immutable CopyAssetsDirectory end

function exec(::CopyAssetsDirectory, env)
    if isdir(env.assets)
        dst = joinpath(env.build, "assets")
        isdir(dst) && rm(dst; recursive = true)
        cp(env.assets, dst; remove_destination = true)
    else
        error("assets directory '$(abspath(env.assets))' is missing.")
    end
end
log(io, ::CopyAssetsDirectory) = log(io, "copying assets to build directory.")

## parse templates
## ===============

"""
Reads the contents of each markdown file found in `src` and them into `Markdown.MD` objects
using `Markdown.parse`.
"""
immutable ParseTemplates end

function exec(::ParseTemplates, env)
    for path in env.template_paths
        ast = Markdown.parse(readstring(path.src))
        push!(env.parsed_templates, ParsedPath(path.src, path.dst, ast))
    end
end
log(io, ::ParseTemplates) = log(io, "parsing markdown templates.")

## expand templates
## ================

"""
Runs all the expanders stored in `.expanders` on each element of the parsed markdown files.
"""
immutable ExpandTemplates{E}
    expanders :: E
end
ExpandTemplates(x...) = ExpandTemplates{typeof(x)}(x)

function exec(E::ExpandTemplates, env)
    for each in env.parsed_templates
        env.state = State(each.src, each.dst)
        for block in each.ast.content
            for x in E.expanders
                expand(x, block, env) && break
            end
        end
        push!(env.expanded_templates, env.state)
    end
end
log(io, ::ExpandTemplates) = log(io, "expanding parsed template files.")

### expanders
### =========

abstract AbstractExpander

"""
Expand a single element, `block`, of a markdown file.
"""
expand(::AbstractExpander, block, env) = false

# default expander
# ----------------

"""
By default block expansion just pushes the block onto the end of the vector of expanded blocks.
"""
immutable DefaultExpander <: AbstractExpander end

function expand(::DefaultExpander, block, env)
    blocks = env.state.blocks
    push!(blocks, block)
    true
end

# header tracking
# ---------------

"""
An expander that tracks all header elements in a document. The data gathered by this expander
is used in later stages to build cross-reference links and tables of contents.
"""
immutable FindHeaders <: AbstractExpander end

const HEADER_ID_REGEX = r"^{#(.+)}$"

function is_custom_header_id(b)
    isa(b.text, Vector) &&
    length(b.text) === 1 &&
    isa(b.text[1], Markdown.Link) &&
    ismatch(HEADER_ID_REGEX, b.text[1].url)
end

function expand{N}(::FindHeaders, b::Markdown.Header{N}, env)
    # Generate a unique ID for the current header `b`.
    id =
        if is_custom_header_id(b)
            url = b.text[1].url
            # MUTATE HEADER! Remove outer link leaving just link text.
            b.text = b.text[1].text
            # Extract the ID for the header.
            match(HEADER_ID_REGEX, url)[1]
        else
            sprint(Markdown.plain, Markdown.Paragraph(b.text))
        end
    id = slugify(id)

    counter = length(env.headers)
    src     = env.state.src
    dst     = env.state.dst

    # Require all headers to have distinct IDs.
    haskey(env.headers, id) && error("duplicate header id '$(id)' in '$(abspath(src))'.")
    env.headers[id]  = HeaderPath(src, dst, counter, b)
    env.headermap[b] = id
    push!(env.state.blocks, b)
    true
end

# {meta} block
# ------------

"""
Expands markdown code blocks where the first line contains `{meta}`. The expander parses
the contents of the block expecting key/value pairs such as

    {meta}
    CurrentModule = Lapidary

Note that all syntax used in the block must be valid Julia syntax.
"""
immutable MetaBlock <: AbstractExpander end

"""
Stores the parsed and evaluated key/value pairs found in a `{meta}` block.
"""
immutable MetaNode
    dict :: Dict{Symbol, Any}
end

function expand(::MetaBlock, b::Markdown.Code, env)
    startswith(b.code, "{meta}") || return false
    meta = env.state.meta
    for (ex, str) in parseblock(b.code; skip = 1)
        isassign(ex) && (meta[ex.args[1]] = eval(current_module(), ex.args[2]))
    end
    push!(env.state.blocks, MetaNode(copy(meta)))
    true
end

# {docs} block
# ------------

"""
Expands code blocks where the first line contains `{docs}`. Subsequent lines should be names
of objects whose documentation should be retrieved from the Julia docsystem.

    {docs}
    foo
    bar(x, y)
    Baz.@baz

Each object is evaluated in the `current_module()` or `CurrentModule` if that has been set
in a `{meta}` block of the current page prior to the `{docs}` block.
"""
immutable DocsBlock <: AbstractExpander end

"""
Stores the object and related docstring for a single object found in a `{docs}` block. When
a `{docs}` block contains multiple entries then each one is expanded into a separate
[`DocsNode`]({ref}).
"""
immutable DocsNode
    object :: Any
    docs   :: Markdown.MD
end

function expand(::DocsBlock, b::Markdown.Code, env)
    startswith(b.code, "{docs}") || return false

    src  = env.state.src
    dst  = env.state.dst
    meta = env.state.meta
    mod  = get(meta, :CurrentModule, current_module())

    for (ex, str) in parseblock(b.code; skip = 1)
        # find the documented object and it's docstring
        obj = eval(mod, object(ex, str))
        doc = eval(mod, docs(ex, str))
        # error checks
        let n = strip(str),
            f = abspath(src)
            nodocs(doc)              && error("no docs found for '$n' in '$f'.")
            haskey(env.docsmap, obj) && error("docs for '$n' duplicated in '$f'.")
        end
        env.docsmap[obj] = (src, dst, doc, strip(strip(str), ':'))
        push!(env.state.blocks, DocsNode(obj, doc))
    end
    true
end

# {eval} block
# ------------

"""
Expands code blocks where the first line constains `{eval}`. Subsequent lines are evalutated
and the final result is used in place of the code block.

This expander block should be used when custom content should be generated such as plots or
other external data that must appear in the final documentation.
"""
immutable EvalBlock <: AbstractExpander end

function expand(::EvalBlock, b::Markdown.Code, env)
    startswith(b.code, "{eval}") || return false
    sandbox = Module(:EvalBlockSandbox)
    cd(dirname(env.state.dst)) do
        result = nothing
        for (ex, str) in parseblock(b.code; skip = 1)
            result = eval(sandbox, ex)
        end
        result === nothing || push!(env.state.blocks, result)
    end
    true
end

# {index} block
# -------------

"""
Expands code blocks where the first line contains `{index}`. Subsequent lines can contain
key/value pairs relevant to the index. Currently `Pages = ["...", ..., "..."]` is supported
for filtering the contents of the index based on source page.

Indexes are used to display links to all the docstrings, generated with `{docs}` blocks, on
any number of pages.
"""
immutable IndexBlock <: AbstractExpander end

"""
`{index}` code blocks are expanded into this object which is used to store the key/value
pairs needed to build the actual index during the later rendering state.
"""
immutable IndexNode
    dict :: Dict{Symbol, Any}
end

function expand(::IndexBlock, b::Markdown.Code, env)
    startswith(b.code, "{index}") || return false

    src  = env.state.src
    dst  = env.state.dst
    meta = env.state.meta
    mod  = get(meta, :CurrentModule, current_module())
    dict = Dict{Symbol, Any}(:src => src, :dst => dst)

    for (ex, str) in parseblock(b.code; skip = 1)
        isassign(ex) && (dict[ex.args[1]] = eval(mod, ex.args[2]))
    end
    push!(env.state.blocks, IndexNode(dict))
    true
end

# {contents} block
# ----------------

"""
Expands code blocks where the first line contains `{contents}`. Subsequent lines can, like
the `{index}` block, contains key/value pairs. Supported pairs are

    Pages = ["...", ..., "..."]
    Depth = 2

where `Pages` acts the same as for `{index}` and `Depth` limits the header level displayed
in the generated contents.

Contents blocks are used to a display nested list of the headers found in one or more pages.
"""
immutable ContentsBlock <: AbstractExpander end

"""
`{contents}` blocks are expanded into these objects, which, like with [`IndexNode`]({ref}),
store the key/value pairs needed to render the contents during the later rendering stage.
"""
immutable ContentsNode
    dict :: Dict{Symbol, Any}
end

function expand(::ContentsBlock, b::Markdown.Code, env)
    startswith(b.code, "{contents}") || return false

    src  = env.state.src
    dst  = env.state.dst
    meta = env.state.meta
    mod  = get(meta, :CurrentModule, current_module())
    dict = Dict{Symbol, Any}(:src => src, :dst => dst)

    for (ex, str) in parseblock(b.code; skip = 1)
        isassign(ex) && (dict[ex.args[1]] = eval(mod, ex.args[2]))
    end
    push!(env.state.blocks, ContentsNode(dict))
    true
end

## walk templates
## ==============

"""
Finds all code blocks in an expanded document where the language is set to `julia` and tries
to run them. Any failure will currently just terminate the entire document generation.

**Notes**

This stage can be disabled in [`makedocs`]({ref}) by setting the keyword `doctest = false`.
"""
immutable RunDocTests end

function exec(::RunDocTests, env)
    if env.doctest
        for each in env.expanded_templates
            meta = Dict()
            walk(meta, each.blocks) do code
                isa(code, Markdown.Code) || return true
                doctest(code, meta)
                false
            end
        end
    else
        warn("doctesting is disabled. Please enable it.")
    end
end
log(io, ::RunDocTests) = log(io, "running doctests.")

"""
Finds all `Markdown.Link` elements in an expanded document and tries to find where the link
should point to. Will terminate the entire document generation process when a link cannot
successfully be found.
"""
immutable CrossReferenceLinks end

function exec(::CrossReferenceLinks, env)
    for each in env.expanded_templates

        src    = each.src
        dst    = each.dst
        blocks = each.blocks
        meta   = Dict()

        walk(meta, blocks) do link
            isa(link, Markdown.Link) || return true
            if ismatch(r"^{ref(.*)}$", link.url)
                if isa(link.text[1], Markdown.Code)
                    code = link.text[1].code
                    mod  = get(meta, :CurrentModule, current_module())
                    obj  = eval(mod, object(parse(code), code))
                    haskey(env.docsmap, obj) || error("no doc for reference '$code' found.")
                    doc_src, doc_dst, docs, docstr = env.docsmap[obj]
                    path   = relpath(doc_dst, dirname(dst))
                    anchor = string(obj)
                    link.url = string(path, '#', anchor)
                    obj.binding.mod == Keywords && (link.text[1].code = strip(code, ':'))
                elseif isa(link.text, Vector) && length(link.text) === 1
                    r  = match(r"^{ref#(.+)}$", link.url)
                    id = r === nothing ? sprint(Markdown.plain, Markdown.Paragraph(link.text)) : r[1]
                    id = slugify(id)
                    haskey(env.headers, id) || error("no header ID '$id' found in document.")
                    path = relpath(env.headers[id].dst, dirname(dst))
                    link.url = string(path, '#', id)
                end
            end
            false
        end
    end
end
log(io, ::CrossReferenceLinks) = log(io, "generating cross-reference links.")

"""
    walk(f::Function, meta::Dict, element)

Scan a document tree and run function `f` on each `element` that is encountered.
"""
function walk end

# Change to the docstring's defining module if it has one. Change back afterwards.
function walk(f, meta, block::Markdown.MD)
    tmp = get(meta, :CurrentModule, nothing)
    mod = get(block.meta, :module, nothing)
    mod ≡ nothing || (meta[:CurrentModule] = mod)
    f(block) && walk(f, meta, block.content)
    tmp ≡ nothing ? delete!(meta, :CurrentModule) : (meta[:CurrentModule] = tmp)
    nothing
end

function walk(f, meta, block::Vector)
    for each in block
        f(each) && walk(f, meta, each)
    end
end

typealias MDContentElements Union{
    Markdown.BlockQuote,
    Markdown.Paragraph,
    Markdown.MD,
}
walk(f, meta, block::MDContentElements) = f(block) ? walk(f, meta, block.content) : nothing

walk(f, meta, block::DocsNode) = walk(f, meta, block.docs)

walk(f, meta, block::MetaNode) = (merge!(meta, block.dict); nothing)

typealias MDTextElements Union{
    Markdown.Bold,
    Markdown.Header,
    Markdown.Italic,
}
walk(f, meta, block::MDTextElements) = f(block) ? walk(f, meta, block.text)  : nothing

if isdefined(Base.Markdown, :Footnote)
    walk(f, meta, block::Markdown.Footnote) = f(block) ? walk(f, meta, block.text) : nothing
end

walk(f, meta, block::Markdown.Image) = f(block) ? walk(f, meta, block.alt)   : nothing
walk(f, meta, block::Markdown.Table) = f(block) ? walk(f, meta, block.rows)  : nothing
walk(f, meta, block::Markdown.List)  = f(block) ? walk(f, meta, block.items) : nothing
walk(f, meta, block::Markdown.Link)  = f(block) ? walk(f, meta, block.text)  : nothing

walk(f, meta, block) = (f(block); nothing)

## check docs
## ==========

"""
Consistency checks for the generated documentation. Have all the available docs from the
specified modules been added to the external docs?
"""
immutable CheckDocs end

function exec(::CheckDocs, env)
    missing_docs_check(env)
end
log(io, ::CheckDocs) = log(io, "checking document consistency.")

## render document
## ===============

"""
Write the contents of the expanded document tree to file. Currently only supports markdown output.
"""
immutable RenderDocument end

function exec(::RenderDocument, env)
    for each in env.expanded_templates
        open(each.dst, "w") do io
            render(io, env.mime, each.blocks, env)
        end
    end
end
log(io, ::RenderDocument) = log(io, "writing document to file.")

function render(io, mime, blocks::Vector, env)
    for each in blocks
        render(io, mime, each, env)
    end
end

render(io, mime, block, env) = (println(io); writemime(io, mime, Markdown.MD(block)); println(io))

function render(io, mime, h::Markdown.Header, env)
    id = env.headermap[h]
    println(io, "\n", "<a id='$id'></a>")
    writemime(io, mime, Markdown.MD(h))
    println(io)
end

function render(io, mime, doc::DocsNode, env)
    id = string(doc.object)
    print(io, "\n", "<a id='$id' href='#$id'>#</a>")
    println(io, "**", doc.object.binding, "** &mdash; *", doccat(doc.object), "*.\n")
    println(io, "---\n")
    writemime(io, mime, doc.docs)
    println(io, "\n")
end

function render(io, mime, index::IndexNode, env)
    pages   = get!(index.dict, :Pages, [])
    mapping = Dict()
    for (obj, (src, dst, markdown, docstr)) in env.docsmap
        path = relpath(dst, dirname(index.dict[:dst]))
        push!(get!(mapping, path, []), (docstr, path, string(obj)))
    end
    pages = isempty(pages) ? sort!(collect(keys(mapping))) : pages
    for page in pages
        if haskey(mapping, page)
            docs = mapping[page]
            for (docstr, path, object) in sort!(docs, by = t -> t[3])
                println(io, "- [`", docstr, "`](", path, '#', object, ")")
            end
        end
    end
end

function render(io, mime, contents::ContentsNode, env)
    pages = get(contents.dict, :Pages, [])
    depth = get(contents.dict, :Depth, 2)
    mapping = Dict()
    for (id, headerpath) in env.headers
        path = relpath(headerpath.dst, dirname(contents.dict[:dst]))
        if header_level(headerpath.ast) ≤ depth
            push!(get!(mapping, path, []), (headerpath.nth, headerpath.ast, path, id))
        end
    end
    pages = isempty(pages) ? sort!(collect(keys(mapping))) : pages
    for page in pages
        if haskey(mapping, page)
            links = mapping[page]
            for (counter, header, path, id) in sort!(links, by = first)
                print(io, "    "^(header_level(header) - 1), "- ")
                link = Markdown.Link(header.text, string(path, '#', id))
                Markdown.plaininline(io, link)
                println(io)
            end
        end
    end
end

render(io, mime, meta::MetaNode, env) = nothing

# utilities
# =========

"""
    log(io::IO, msg::AbstractString)
    log(msg::AbstractString)

Print a formatted message to `STDOUT`. Each document "stage" type must provide an implementation
of this function.
"""
function log end

log(T) = log(STDOUT, T)
log(io, msg::AbstractString) = print_with_color(:magenta, io, string("LAPIDARY: ", msg, "\n"))

"""
    process(env, stages...)

For each stage in `stages` execute stage with the given `env` as it's argument.
"""
process(env::Env, stages...)  = process(stages, env)

function process(stages::Tuple, env)
    log(car(stages))
    exec(car(stages), env)
    process(cdr(stages), env)
end
process(stages::Tuple{}, env) = nothing


"""
    car(x::Tuple)

Head element of the `Tuple` `x`. See also [`cdr`]({ref}).
"""
@inline    car(x::Tuple) = _car(x...)
@inline   _car(h, t...)  = h
@noinline _car()         = error("empty tuple.")

"""
    cdr(x::Tuple)

Tail elements of the `Tuple` `x`. See also [`car`]({ref}).
"""
@inline    cdr(x::Tuple) = _cdr(x...)
@inline   _cdr(h, t...)  = t
@noinline _cdr()         = error("empty tuple.")


"""
    currentdir()

Returns the current source directory. When `isinteractive() ≡ true` then the present working
directory, `pwd()` is returned instead.
"""
function currentdir()
    d = Base.source_dir()
    d === nothing ? pwd() : d
end

"""
    assetsdir()

Directory containing Lapidary asset files.
"""
assetsdir() = normpath(joinpath(dirname(@__FILE__), "..", "assets"))

cleandir(d::AbstractString) = (isdir(d) && rm(d, recursive = true); mkdir(d))

"""
    parseblock(code::AbstractString; skip = 0)

Returns an array of (expression, string) tuples for each complete toplevel expression from
`code`. The `skip` keyword argument will drop the provided number of leading lines.
"""
function parseblock(code; skip = 0)
    code = string(code, '\n')
    code = last(split(code, '\n', limit = skip + 1))
    results, cursor = [], 1
    while cursor < length(code)
        ex, ncursor = parse(code, cursor)
        push!(results, (ex, code[cursor:ncursor-1]))
        cursor = ncursor
    end
    results
end

isassign(x) = isexpr(x, :(=), 2) && isa(x.args[1], Symbol)

"""
Does the document returned from the docsystem contain any useful documentation.
"""
nodocs(x)      = contains(stringmime("text/plain", x), "No documentation found.")
nodocs(::Void) = false

"""
Slugify a string `s` by removing special characters. Used in the url generation process.
"""
function slugify(s)
    s = strip(lowercase(s))
    s = replace(s, r"\s+", "-")
    s = replace(s, r"&", "-and-")
    s = replace(s, r"[^\w\-]+", "")
    s = strip(replace(s, r"\-\-+", "-"), '-')
end

header_level{N}(::Markdown.Header{N}) = N

## doctests
## ========

"""
    doctest(source::Markdown.Code)

Try to run the Julia source code found in `source`.
"""
function doctest(block::Markdown.Code, meta::Dict)
    if block.language == "julia"
        code, sandbox = block.code, Module(:Main)
        haskey(meta, :DocTestSetup) && eval(sandbox, meta[:DocTestSetup])
        ismatch(r"^julia> "m, code)   ? eval_repl(code, sandbox)   :
        ismatch(r"^# output$"m, code) ? eval_script(code, sandbox) : nothing
    end
end

function eval_repl(code, sandbox)
    parts = split(code, "\njulia> ")
    for part in parts
        p = replace(part, "julia> ", "", 1)
        ex, cursor = parse(p, 1)
        result =
            try
                ans = eval(sandbox, ex)
                eval(sandbox, :(ans = $(ans)))
                endswith(strip(p[1:cursor-1]), ';') ?
                    "" : result_to_string(ans)
            catch err
                error_to_string(err, catch_backtrace())
            end
        checkresults(code, part, p[cursor:end], result)
    end
end
function eval_script(code, sandbox)
    code, expected = split(code, "\n# output\n", limit = 2)
    result =
        try
            ans = nothing
            for (ex, str) in parseblock(code)
                ans = eval(sandbox, ex)
            end
            result_to_string(ans)
        catch err
            error_to_string(err, catch_backtrace())
        end
    checkresults(code, "", expected, result)
end

function result_to_string(value)
    buf = IOBuffer()
    dis = Base.Multimedia.TextDisplay(buf)
    display(dis, value)
    takebuf_string(buf)
end
result_to_string(::Void) = ""

function error_to_string(er, bt)
    buf = IOBuffer()
    print(buf, "ERROR: ")
    showerror(buf, er, bt)
    println(buf)
    takebuf_string(buf)
end

function checkresults(code, part, expected, result)
    ex, res = map(stripws, (expected, result))
    ex == res ? nothing : throw(DocTestError(code, part, ex, res))
end
function stripws(str)
    buf = IOBuffer()
    for line in split(str, ['\n', '\r'])
        line = rstrip(line)
        isempty(line) || println(buf, line)
    end
    takebuf_string(buf)
end

immutable DocTestError <: Exception
    code     :: UTF8String
    part     :: UTF8String
    expected :: UTF8String
    result   :: UTF8String
end

function Base.showerror(io::IO, docerr::DocTestError)
    println(io, "DocTestError in block:\n")
    print_indented(io, docerr.code)
    if !isempty(docerr.part)
        println(io, "\nfor sub-expression:\n")
        print_indented(io, docerr.part)
    end
    println(io, "\n[Expected Result]\n")
    print_indented(io, docerr.expected)
    println(io, "\n[Actual Result]\n")
    print_indented(io, docerr.result)
end

function print_indented(buf::IO, str::AbstractString; indent = 4)
    for line in split(str, ['\n', '\r'])
        println(buf, " "^indent, line)
    end
end

## objects
## =======

immutable Binding
    mod :: Module
    var :: Symbol
    Binding(m, v) = new(Base.binding_module(m, v), v)
end

Base.show(io::IO, b::Binding) = print(io, b.mod, '.', b.var)

immutable Object
    binding   :: Binding
    signature :: Type
end

function splitexpr(x::Expr)
    isexpr(x, :macrocall) ? splitexpr(x.args[1]) :
    isexpr(x, :.)         ? (x.args[1], x.args[2]) :
    error("Invalid @var syntax `$x`.")
end
splitexpr(s::Symbol) = :(current_module()), quot(s)
splitexpr(other)     = error("Invalid @var syntax `$other`.")

Base.Docs.signature(::Symbol) = :(Union{})

function object(ex::Union{Symbol, Expr}, str::AbstractString)
    binding   = Expr(:call, Binding, splitexpr(Docs.namify(ex))...)
    signature = Base.Docs.signature(ex)
    isexpr(ex, :macrocall, 1) && !endswith(str, "()") && (signature = :(Union{}))
    Expr(:call, Object, binding, signature)
end

function object(qn::QuoteNode, str::AbstractString)
    if haskey(Base.Docs.keywords, qn.value)
        binding = Expr(:call, Binding, Keywords, qn)
        Expr(:call, Object, binding, Union{})
    else
        error("'$(qn.value)' is not a documented keyword.")
    end
end

function Base.print(io::IO, obj::Object)
    print(io, obj.binding)
    print_signature(io, obj.signature)
end
print_signature(io::IO, signature::Union) = nothing
print_signature(io::IO, signature)        = print(io, '-', signature)

## docs
## ====

# Macro representation changed between 0.4 and 0.5.
if VERSION < v"0.5-"
    function docs(ex::Union{Symbol, Expr}, str::AbstractString)
        :(Base.Docs.@doc $ex)
    end
else
    function docs(ex::Union{Symbol, Expr}, str::AbstractString)
        isexpr(ex, :macrocall, 1) && !endswith(rstrip(str), "()") && (ex = quot(ex))
        :(Base.Docs.@doc $ex)
    end
end
docs(qn::QuoteNode, str::AbstractString) = :(Base.Docs.@doc $(qn.value))

doccat(obj::Object) = startswith(string(obj.binding.var), '@') ?
    "Macro" : doccat(obj.binding, obj.signature)

doccat(b::Binding, ::Union) = b.mod == Keywords && haskey(Base.Docs.keywords, b.var) ?
    "Keyword" : doccat(getfield(b.mod, b.var))

doccat(b::Binding, ::Type)  = "Method"

doccat(::Function) = "Function"
doccat(::DataType) = "Type"
doccat(::Module)   = "Module"
doccat(::ANY)      = "Constant"

# Module used to uniquify keyword bindings.
baremodule Keywords end

## missing docs check
## ==================

function missing_docs_check(env)
    bindings = allbindings(env.modules)
    for obj in keys(env.docsmap)
        if haskey(bindings, obj.binding)
            signatures = bindings[obj.binding]
            if obj.signature == Union{} || length(signatures) == 1
                delete!(bindings, obj.binding)
            end
        end
    end
    for (binding, signatures) in bindings
        warn("docs for '$binding' potentially missing from generated docs.")
    end
end

function allbindings(mods)
    out = Dict{Binding, Vector{Type}}()
    for m in mods, (obj, doc) in Base.Docs.meta(m)
        isa(obj, ObjectIdDict) && continue
        out[Binding(m, nameof(obj))] = sigs(doc)
    end
    out
end

if isleaftype(Function) # 0.4
    nameof(x::Function) = x.env.name
else # 0.5
    nameof(x::Function) = typeof(x).name.mt.name
end
nameof(b::Base.Docs.Binding) = b.var
nameof(x::DataType)          = x.name.name
nameof(m::Module)            = module_name(m)

if isdefined(Base.Docs, :MultiDoc)
    sigs(x::Base.Docs.MultiDoc) = x.order
else
    sigs(x::Base.Docs.FuncDoc) = x.order
    sigs(x::Base.Docs.TypeDoc) = x.order
end
sigs(::Any)            = Type[Union{}]

## walkdir compat
## ==============

if !isdefined(:walkdir)
    function walkdir(root; topdown=true, follow_symlinks=false, onerror=throw)
        content = nothing
        try
            content = readdir(root)
        catch err
            isa(err, SystemError) || throw(err)
            onerror(err)
            #Need to return an empty task to skip the current root folder
            return Task(()->())
        end
        dirs = Array(eltype(content), 0)
        files = Array(eltype(content), 0)
        for name in content
            if isdir(joinpath(root, name))
                push!(dirs, name)
            else
                push!(files, name)
            end
        end

        function _it()
            if topdown
                produce(root, dirs, files)
            end
            for dir in dirs
                path = joinpath(root,dir)
                if follow_symlinks || !islink(path)
                    for (root_l, dirs_l, files_l) in walkdir(path, topdown=topdown, follow_symlinks=follow_symlinks, onerror=onerror)
                        produce(root_l, dirs_l, files_l)
                    end
                end
            end
            if !topdown
                produce(root, dirs, files)
            end
        end
        Task(_it)
    end
end

end
