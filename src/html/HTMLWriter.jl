"""
A module for rendering `Document` objects to HTML.

# Keywords

[`HTMLWriter`](@ref) uses the following additional keyword arguments that can be passed to
[`Documenter.makedocs`](@ref): `authors`, `pages`, `sitename`, `version`.
The behavior of [`HTMLWriter`](@ref) can be further customized by setting the `format`
keyword of [`Documenter.makedocs`](@ref) to a [`HTML`](@ref), which accepts the following
keyword arguments: `analytics`, `assets`, `canonical`, `disable_git`, `edit_link`,
`prettyurls`, `collapselevel`, `sidebar_sitename`, `highlights`, `mathengine` and `footer`.

**`sitename`** is the site's title displayed in the title bar and at the top of the
*navigation menu. This argument is mandatory for [`HTMLWriter`](@ref).

**`pages`** defines the hierarchy of the navigation menu.

# Experimental keywords

**`version`** specifies the version string of the current version which will be the
selected option in the version selector. If this is left empty (default) the version
selector will be hidden. The special value `git-commit` sets the value in the output to
`git:{commit}`, where `{commit}` is the first few characters of the current commit hash.

# `HTML` `Plugin` options

The [`HTML`](@ref) [`Documenter.Plugin`](@ref) provides additional customization options
for the [`HTMLWriter`](@ref). For more information, see the [`HTML`](@ref) documentation.

# Page outline

The [`HTMLWriter`](@ref) makes use of the page outline that is determined by the
headings. It is assumed that if the very first block of a page is a level 1 heading,
then it is intended as the page title. This has two consequences:

1. It is then used to automatically determine the page title in the navigation menu
   and in the `<title>` tag, unless specified in the `.pages` option.
2. If the first heading is interpreted as being the page title, it is not displayed
   in the navigation sidebar.
"""
module HTMLWriter

using Dates: Dates, @dateformat_str, now
import Markdown
using MarkdownAST: MarkdownAST, Node
import JSON
import Base64
import SHA

import ..Documenter
using Documenter: NavNode
using ..Documenter: Default, Remotes
using ...JSDependencies: JSDependencies, json_jsescape
import ...DOM: DOM, Tag, @tags
using ...MDFlatten

import ANSIColoredPrinters

export HTML

"Data attribute for the script inserting a warning for outdated docs."
const OUTDATED_VERSION_ATTR = "data-outdated-warner"

"List of Documenter native themes."
const THEMES = ["documenter-light", "documenter-dark"]
"The root directory of the HTML assets."
const ASSETS = normpath(joinpath(@__DIR__, "..", "..", "assets", "html"))
"The directory where all the Sass/SCSS files needed for theme building are."
const ASSETS_SASS = joinpath(ASSETS, "scss")
"Directory for the compiled CSS files of the themes."
const ASSETS_THEMES = joinpath(ASSETS, "themes")

struct HTMLAsset
    class :: Symbol
    uri :: String
    islocal :: Bool
    attributes::Dict{Symbol, String}

    function HTMLAsset(class::Symbol, uri::String, islocal::Bool, attributes::Dict{Symbol, String}=Dict{Symbol,String}())
        if !islocal && match(r"^https?://", uri) === nothing
            error("Remote asset URL must start with http:// or https://")
        end
        if islocal && isabspath(uri)
            @error("Local asset should not have an absolute URI: $uri")
        end
        class in [:ico, :css, :js] || error("Unrecognised asset class $class for `$(uri)`")
        new(class, uri, islocal, attributes)
    end
end

"""
    asset(uri)

Can be used to pass non-local web assets to [`HTML`](@ref), where `uri` should be an absolute
HTTP or HTTPS URL.

It accepts the following keyword arguments:

**`class`** can be used to override the asset class, which determines how exactly the asset
gets included in the HTML page. This is necessary if the class can not be determined
automatically (default).

Should be one of: `:js`, `:css` or `:ico`. They become a `<script>`,
`<link rel="stylesheet" type="text/css">` and `<link rel="icon" type="image/x-icon">`
elements in `<head>`, respectively.

**`islocal`** can be used to declare the asset to be local. The `uri` should then be a path
relative to the documentation source directory (conventionally `src/`). This can be useful
when it is necessary to override the asset class of a local asset.

# Usage

```julia
Documenter.HTML(assets = [
    # Standard local asset
    "assets/extra_styles.css",
    # Standard remote asset (extension used to determine that class = :js)
    asset("https://example.com/jslibrary.js"),
    # Setting asset class manually, since it can't be determined manually
    asset("https://example.com/fonts", class = :css),
    # Same as above, but for a local asset
    asset("asset/foo.script", class=:js, islocal=true),
])
```
"""
function asset(uri; class = nothing, islocal=false, attributes=Dict{Symbol,String}())
    if class === nothing
        class = assetclass(uri)
        (class === nothing) && error("""
        Unable to determine asset class for: $(uri)
        It can be set explicitly with the `class` keyword argument.
        """)
    end
    HTMLAsset(class, uri, islocal, attributes)
end

function assetclass(uri)
    # TODO: support actual proper URIs
    ext = splitext(uri)[end]
    ext == ".ico" ? :ico :
    ext == ".css" ? :css :
    ext == ".js"  ? :js  : :unknown
end

abstract type MathEngine end

"""
    KaTeX(config::Dict = <default>, override = false)

An instance of the `KaTeX` type can be passed to [`HTML`](@ref) via the `mathengine` keyword
to specify that the [KaTeX rendering engine](https://katex.org/) should be used in the HTML
output to render mathematical expressions.

A dictionary can be passed via the `config` argument to configure KaTeX. It becomes the
[options argument of `renderMathInElement`](https://katex.org/docs/autorender.html#api). By
default, Documenter only sets a custom `delimiters` option.

By default, the user-provided dictionary gets _merged_ with the default dictionary (i.e. the
resulting configuration dictionary will contain the values from both dictionaries, but e.g.
setting your own `delimiters` value will override the default). This can be overridden by
setting `override` to `true`, in which case the default values are ignored and only the
user-provided dictionary is used.
"""
struct KaTeX <: MathEngine
    config :: Dict{Symbol,Any}
    function KaTeX(config::Union{Dict,Nothing} = nothing, override=false)
        default = Dict(
            :delimiters => [
                Dict(:left => raw"$",   :right => raw"$",   display => false),
                Dict(:left => raw"$$",  :right => raw"$$",  display => true),
                Dict(:left => raw"\[",  :right => raw"\]",  display => true),
            ]
        )
        new((config === nothing) ? default : override ? config : merge(default, config))
    end
end

"""
    MathJax2(config::Dict = <default>, override = false)

An instance of the `MathJax2` type can be passed to [`HTML`](@ref) via the `mathengine`
keyword to specify that the [MathJax v2 rendering engine](https://www.mathjax.org/) should be
used in the HTML output to render mathematical expressions.

A dictionary can be passed via the `config` argument to configure MathJax. It gets passed to
the [`MathJax.Hub.Config`](https://docs.mathjax.org/en/v2.7-latest/options/) function. By
default, Documenter sets custom configurations for `tex2jax`, `config`, `jax`, `extensions`
and `Tex`.

By default, the user-provided dictionary gets _merged_ with the default dictionary (i.e. the
resulting configuration dictionary will contain the values from both dictionaries, but e.g.
setting your own `tex2jax` value will override the default). This can be overridden by
setting `override` to `true`, in which case the default values are ignored and only the
user-provided dictionary is used.

The URL of the MathJax JS file can be overridden using the `url` keyword argument (e.g. to
use a particular minor version).
"""
struct MathJax2 <: MathEngine
    config :: Dict{Symbol,Any}
    url :: String
    function MathJax2(config::Union{Dict,Nothing} = nothing, override=false; url = "")
        default = Dict(
            :tex2jax => Dict(
                "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
                "processEscapes" => true
            ),
            :config => ["MMLorHTML.js"],
            :jax => [
                "input/TeX",
                "output/HTML-CSS",
                "output/NativeMML"
            ],
            :extensions => [
                "MathMenu.js",
                "MathZoom.js",
                "TeX/AMSmath.js",
                "TeX/AMSsymbols.js",
                "TeX/autobold.js",
                "TeX/autoload-all.js"
            ],
            :TeX => Dict(:equationNumbers => Dict(:autoNumber => "AMS"))
        )
        new((config === nothing) ? default : override ? config : merge(default, config), url)
    end
end

@deprecate MathJax(config::Union{Dict,Nothing} = nothing, override=false) MathJax2(config, override) false
@doc "deprecated – Use [`MathJax2`](@ref) instead" MathJax

"""
    MathJax3(config::Dict = <default>, override = false)

An instance of the `MathJax3` type can be passed to [`HTML`](@ref) via the `mathengine`
keyword to specify that the [MathJax v3 rendering engine](https://www.mathjax.org/) should be
used in the HTML output to render mathematical expressions.

A dictionary can be passed via the `config` argument to configure MathJax. It gets passed to
[`Window.MathJax`](https://docs.mathjax.org/en/latest/options/) function. By default,
Documenter specifies in the key `tex` that `\$...\$` and `\\(...\\)` denote inline math, that AMS
style tags should be used and the `base`, `ams` and `autoload` packages should be imported.
The key `options`, by default, specifies which HTML classes to ignore and which to process
using MathJax.

By default, the user-provided dictionary gets _merged_ with the default dictionary (i.e. the
resulting configuration dictionary will contain the values from both dictionaries, but e.g.
setting your own `tex` value will override the default). This can be overridden by
setting `override` to `true`, in which case the default values are ignored and only the
user-provided dictionary is used.

The URL of the MathJax JS file can be overridden using the `url` keyword argument (e.g. to
use a particular minor version).
"""
struct MathJax3 <: MathEngine
    config :: Dict{Symbol,Any}
    url :: String
    function MathJax3(config::Union{Dict,Nothing} = nothing, override=false; url = "")
        default = Dict(
            :tex => Dict(
                "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
                "tags" => "ams",
                "packages" => ["base", "ams", "autoload"],
            ),
            :options => Dict(
                "ignoreHtmlClass" => "tex2jax_ignore",
                "processHtmlClass" => "tex2jax_process",
            )
        )
        new((config === nothing) ? default : override ? config : merge(default, config), url)
    end
end

"""
    HTML(kwargs...)

Sets the behavior of [`HTMLWriter`](@ref).

# Keyword arguments

**`prettyurls`** (default `true`) -- allows toggling the pretty URLs feature.

By default (i.e. when `prettyurls` is set to `true`), Documenter creates a directory
structure that hides the `.html` suffixes from the URLs (e.g. by default `src/foo.md`
becomes `src/foo/index.html`, but can be accessed with via `src/foo/` in the browser). This
structure is preferred when publishing the generate HTML files as a website (e.g. on GitHub
Pages), which is Documenter's primary use case.

If `prettyurls = false`, then Documenter generates `src/foo.html` instead, suitable for
local documentation builds, as browsers do not normally resolve `foo/` to `foo/index.html`
for local files.

To have pretty URLs disabled in local builds, but still have them enabled for the automatic
CI deployment builds, you can set `prettyurls = get(ENV, "CI", nothing) == "true"` (the
specific environment variable you will need to check may depend on the CI system you are
using, but this will work on Travis CI).

**`disable_git`** can be used to disable calls to `git` when the document is not
in a Git-controlled repository. Without setting this to `true`, Documenter will throw
an error and exit if any of the Git commands fail. The calls to Git are mainly used to
gather information about the current commit hash and file paths, necessary for constructing
the links to the remote repository.

**`edit_link`** can be used to specify which branch, tag or commit (when passed a `String`)
in the remote repository the edit buttons point to. If a special `Symbol` value `:commit`
is passed, the current commit will be used instead. If set to `nothing`, the link edit link
will be hidden altogether. By default, Documenter tries to determine it automatically by
looking at the `origin` remote, and falls back to `"master"` if that fails.

**`repolink`** can be used to override the URL of the Git repository link in the top navbar
(if passed a `String`). By default, Documenter attempts to determine the link from the Git
remote of the repository (e.g. specified via the `remote` argument of
[`makedocs`](@ref Documenter.makedocs)). Passing a `nothing` disables the repository link.

**`canonical`** specifies the canonical URL for your documentation. We recommend
you set this to the base url of your stable documentation, e.g. `https://documenter.juliadocs.org/stable`.
This allows search engines to know which version to send their users to. [See
wikipedia for more information](https://en.wikipedia.org/wiki/Canonical_link_element).
Default is `nothing`, in which case no canonical link is set.

**`assets`** can be used to include additional assets (JS, CSS, ICO etc. files). See below
for more information.

**`analytics`** can be used specify the Google Analytics tracking ID.

**`collapselevel`** controls the navigation level visible in the sidebar. Defaults to `2`.
To show fewer levels by default, set `collapselevel = 1`.

**`sidebar_sitename`** determines whether the site name is shown in the sidebar or not.
Setting it to `false` can be useful when the logo already contains the name of the package.
Defaults to `true`.

**`highlights`** can be used to add highlighting for additional languages. By default,
Documenter already highlights all the ["Common" highlight.js](https://highlightjs.org/download)
languages and Julia (`julia`, `julia-repl`). Additional languages must be specified by
their filenames as they appear on [CDNJS](https://cdnjs.com/libraries/highlight.js) for the
highlight.js version Documenter is using. E.g. to include highlighting for YAML and LLVM IR,
you would set `highlights = ["llvm", "yaml"]`. Note that no verification is done whether the
provided language names are sane.

**`mathengine`** specifies which LaTeX rendering engine will be used to render the math
blocks. The options are either [KaTeX](https://katex.org/) (default),
[MathJax v2](https://www.mathjax.org/), or [MathJax v3](https://www.mathjax.org/), enabled by
passing an instance of [`KaTeX`](@ref), [`MathJax2`](@ref), or
[`MathJax3`](@ref) objects, respectively. The rendering engine can further be customized by
passing options to the [`KaTeX`](@ref) or [`MathJax2`](@ref)/[`MathJax3`](@ref) constructors.

**`description`** is the site-wide description that displays in page previews and search
engines. Defaults to `"Documentation for \$sitename"``, where `sitename` is defined as
an argument to [`makedocs`](@ref).

**`footer`** can be a valid single-line markdown `String` or `nothing` and is displayed below
the page navigation. Defaults to `"Powered by [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)
and the [Julia Programming Language](https://julialang.org/)."`.

**`ansicolor`** can be used to globally disable colored output from `@repl` and `@example`
blocks by setting it to `false` (default: `true`).

**`lang`** specifies the [`lang` attribute](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/lang)
of the top-level `<html>` element, declaring the language of the generated pages. The default
value is `"en"`.

**`warn_outdated`** inserts a warning if the current page is not the newest version of the
documentation.

**`example_size_threshold`** specifies the size threshold above which the `@example` and other block
outputs get written to files, rather than being included in the HTML page. This mechanism is present
to reduce the size of the generated HTML files that contain a lot of figures etc.
Setting it to `nothing` will disable writing to files, and setting to `0` means that all examples
will be written to files. Defaults to `8 KiB`.

**`size_threshold`** sets the maximum allowed HTML file size (in bytes) that Documenter is allowed to
generate for a page. If the generated HTML file is larged than this, Documenter will throw an error and
the build will fail. If set to `nothing`, the file sizes are not checked. Defaults to `200 KiB` (but
increases of this default value will be considered to be non-breaking).

**`size_threshold_warn`**: like `size_threshold`, but going over this limit will only cause Documenter to
print a warning, instead of throwing an error. Defaults to `100 KiB`, and must be less than or equal to
`size_threshold`.

**`size_threshold_ignore`** can be passed a list of pages for which the size thresholds are completely
ignored (silently). The arguments should be the same file paths as for the `pages` argument of
[`makedocs`](@ref Documenter.makedocs). Using this argument to ignore a few specific pages is preferred
over setting a high general limit, or disabling the size checking altogether.

!!! note "Purpose of HTML size thresholds"

    The size threshold, with a reasonable default, exists so that users would not deploy huge pages
    accidentally (which among other this will result in bad UX for the readers and negatively impacts
    SEO). It is relatively easy to have e.g. an `@example` produce a lot of output.

## Experimental options

**`prerender`** a boolean (`true` or `false` (default)) for enabling prerendering/build
time application of syntax highlighting of code blocks. Requires a `node` (NodeJS)
executable to be available in `PATH` or to be passed as the `node` keyword.

**`node`** path to a `node` (NodeJS) executable used for prerendering.

**`highlightjs`** file path to custom highglight.js library to be used with prerendering.

# Default and custom assets

Documenter copies all files under the source directory (e.g. `/docs/src/`) over
to the compiled site. It also copies a set of default assets from `/assets/html/`
to the site's `assets/` directory, unless the user already had a file with the
same name, in which case the user's files overrides the Documenter's file.
This could, in principle, be used for customizing the site's style and scripting.

The HTML output also links certain custom assets to the generated HTML documents,
specifically a logo, a preview image, and additional javascript files.
The asset files that should be linked must be placed in `assets/`, under the source
directory (e.g `/docs/src/assets`) and must be on the top level (i.e. files in
the subdirectories of `assets/` are not linked).

For the **logo**, Documenter checks for the existence of `assets/logo.{svg,png,webp,gif,jpg,jpeg}`,
in this order. The first one it finds gets displayed at the top of the navigation sidebar.
It will also check for `assets/logo-dark.{svg,png,webp,gif,jpg,jpeg}` and use that for dark
themes.

Similarly, for the **preview image**, Documenter checks for the existence of
`assets/preview.{png,webp,gif,jpg,jpeg}` in order. Assuming that `canonical` has
been set, the canonical URL for the image gets constructed, , and a set of
HTML `<meta>` tags are generated for the image, ensuring that the image shows
up in link previews. The preview image will not be shown if `canonical` is not set.

Additional JS, ICO, and CSS assets can be included in the generated pages by passing them as
a list with the `assets` keyword. Each asset will be included in the `<head>` of every page
in the order in which they are given. The type of the asset (i.e. whether it is going to be
included with a `<script>` or a `<link>` tag) is determined by the file's extension --
either `.js`, `.ico`[^1], or `.css` (unless overridden with [`asset`](@ref)).

Simple strings are assumed to be local assets and that each correspond to a file relative to
the documentation source directory (conventionally `src/`). Non-local assets, identified by
their absolute URLs, can be included with the [`asset`](@ref) function.

[^1]: Adding an ICO asset is primarily useful for setting a custom `favicon`.
"""
struct HTML <: Documenter.Writer
    prettyurls    :: Bool
    disable_git   :: Bool
    edit_link     :: Union{String, Symbol, Nothing}
    repolink      :: Union{String, Nothing, Default{Nothing}}
    canonical     :: Union{String, Nothing}
    assets        :: Vector{HTMLAsset}
    analytics     :: String
    collapselevel :: Int
    sidebar_sitename :: Bool
    highlights    :: Vector{String}
    mathengine    :: Union{MathEngine,Nothing}
    description   :: Union{String,Nothing}
    footer        :: Union{MarkdownAST.Node, Nothing}
    ansicolor     :: Bool
    lang          :: String
    warn_outdated :: Bool
    prerender     :: Bool
    node          :: Union{Cmd,String,Nothing}
    highlightjs   :: Union{String,Nothing}
    size_threshold :: Int
    size_threshold_warn :: Int
    size_threshold_ignore :: Vector{String}
    example_size_threshold :: Int

    function HTML(;
            prettyurls    :: Bool = true,
            disable_git   :: Bool = false,
            repolink      :: Union{String, Nothing, Default} = Default(nothing),
            edit_link     :: Union{String, Symbol, Nothing, Default} = Default(Documenter.git_remote_head_branch("HTML(edit_link = ...)", Documenter.currentdir())),
            canonical     :: Union{String, Nothing} = nothing,
            assets        :: Vector = String[],
            analytics     :: String = "",
            collapselevel :: Integer = 2,
            sidebar_sitename :: Bool = true,
            highlights    :: Vector{String} = String[],
            mathengine    :: Union{MathEngine,Nothing} = KaTeX(),
            description   :: Union{String, Nothing} = nothing,
            footer        :: Union{String, Nothing} = "Powered by [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and the [Julia Programming Language](https://julialang.org/).",
            ansicolor     :: Bool = true,
            lang          :: String = "en",
            warn_outdated :: Bool = true,
            prerender     :: Bool = false,
            node          :: Union{Cmd,String,Nothing} = nothing,
            highlightjs   :: Union{String,Nothing} = nothing,
            size_threshold :: Union{Integer, Nothing} = 200 * 2^10, # 200 KiB
            size_threshold_warn :: Union{Integer, Nothing} = 100 * 2^10, # 100 KiB
            size_threshold_ignore :: Vector = String[],
            # The choice of the default here is that having ~10 figures on a page
            # seems reasonable, and that would lead to ~80 KiB, which is still fine
            # and leaves a buffer before hitting `size_threshold_warn`.
            example_size_threshold :: Union{Integer, Nothing} = 8 * 2^10, # 8 KiB

            # deprecated keywords
            edit_branch   :: Union{String, Nothing, Default} = Default(nothing),
        )
        collapselevel >= 1 || throw(ArgumentError("collapselevel must be >= 1"))
        if prerender
            prerender, node, highlightjs = prepare_prerendering(prerender, node, highlightjs, highlights)
        end
        assets = map(assets) do asset
            isa(asset, HTMLAsset) && return asset
            isa(asset, AbstractString) && return HTMLAsset(assetclass(asset), asset, true)
            error("Invalid value in assets: $(asset) [$(typeof(asset))]")
        end
        # Handle edit_branch deprecation
        if !isa(edit_branch, Default)
            isa(edit_link, Default) || error("Can't specify edit_branch (deprecated) and edit_link simultaneously")
            @warn """
            The edit_branch keyword is deprecated -- use edit_link instead.
            Note: `edit_branch = nothing` must be changed to `edit_link = :commit`.
            """
            edit_link = (edit_branch === nothing) ? :commit : edit_branch
        end
        if isa(edit_link, Symbol) && (edit_link !== :commit)
            throw(ArgumentError("Invalid symbol (:$edit_link) passed to edit_link."))
        end
        if footer !== nothing
            footer = Markdown.parse(footer)
            if !(length(footer.content) == 1 && footer.content[1] isa Markdown.Paragraph)
                throw(ArgumentError("footer must be a single-line markdown compatible string."))
            end
            footer = isnothing(footer) ? nothing : convert(Node, footer)
        end
        # convert size threshold values to integers, if need be
        if isnothing(size_threshold)
            size_threshold = typemax(Int)
        elseif size_threshold <= 0
            throw(ArgumentError("size_threshold must be non-negative, got $(size_threshold)"))
        end
        if isnothing(size_threshold_warn)
            size_threshold_warn = min(typemax(Int), size_threshold)
        elseif size_threshold_warn <= 0
            throw(ArgumentError("size_threshold_warn must be non-negative, got $(size_threshold_warn)"))
        elseif size_threshold_warn > size_threshold
            throw(ArgumentError("size_threshold_warn ($size_threshold_warn) must be smaller than size_threshold ($size_threshold)"))
        end
        if isnothing(example_size_threshold)
            example_size_threshold = typemax(Int)
        elseif example_size_threshold < 0
            throw(ArgumentError("example_size_threshold must be non-negative, got $(example_size_threshold)"))
        end
        isa(edit_link, Default) && (edit_link = edit_link[])
        new(prettyurls, disable_git, edit_link, repolink, canonical, assets, analytics,
            collapselevel, sidebar_sitename, highlights, mathengine, description, footer,
            ansicolor, lang, warn_outdated, prerender, node, highlightjs,
            size_threshold, size_threshold_warn, size_threshold_ignore, example_size_threshold,
        )
    end
end

# Cache of downloaded highlight.js bundles
const HLJSFILES = Dict{String,String}()
# Look for node and highlight.js
function prepare_prerendering(prerender, node, highlightjs, highlights)
    node = node === nothing ? Sys.which("node") : node
    if node === nothing
        @error "HTMLWriter: no node executable given or found on the system. Setting `prerender=false`."
        return false, node, highlightjs
    end
    if !success(`$node --version`)
        @error "HTMLWriter: bad node executable at $node. Setting `prerender=false`."
        return false, node, highlightjs
    end
    if highlightjs === nothing
        # Try to download
        curl = Sys.which("curl")
        if curl === nothing
            @error "HTMLWriter: no highlight.js file given and no curl executable found " *
                   "on the system. Setting `prerender=false`."
            return false, node, highlightjs
        end
        @debug "HTMLWriter: downloading highlightjs"
        r = Documenter.JSDependencies.RequireJS([])
        RD.highlightjs!(r, highlights)
        libs = sort!(collect(r.libraries); by = first) # puts highlight first
        key = join((x.first for x in libs), ',')
        highlightjs = get!(HLJSFILES, key) do
            path, io = mktemp()
            for lib in libs
                println(io, "// $(lib.first)")
                run(pipeline(`$(curl) -fsSL $(lib.second.url)`; stdout=io))
                println(io)
            end
            close(io)
            return path
        end
    end
    return prerender, node, highlightjs
end

include("RD.jl")

struct SearchRecord
    src :: String
    page :: Documenter.Page
    fragment :: String
    category :: String
    title :: String
    page_title :: String
    text :: String
end

Base.@kwdef struct AtExampleFallbackWarning
    page::String
    size_bytes::Int
    fallback::Union{String,Nothing}
end

"""
[`HTMLWriter`](@ref)-specific globals that are passed to `domify` and
other recursive functions.
"""
mutable struct HTMLContext
    doc :: Documenter.Document
    settings :: Union{HTML, Nothing}
    scripts :: Vector{String}
    documenter_js :: String
    themeswap_js :: String
    warner_js :: String
    search_index :: Vector{SearchRecord}
    search_index_js :: String
    search_navnode :: Documenter.NavNode
    atexample_warnings::Vector{AtExampleFallbackWarning}

    HTMLContext(doc, settings=nothing) = new(
        doc, settings, [], "", "", "", [], "",
        Documenter.NavNode("search", "Search", nothing),
        AtExampleFallbackWarning[],
    )
end

struct DCtx
    # ctx and navnode were recursively passed to all domify() methods
    ctx :: HTMLContext
    navnode :: Documenter.NavNode
    # The following fields were keyword arguments to mdconvert()
    droplinks :: Bool
    settings :: Union{HTML, Nothing}
    footnotes :: Union{Vector{Node{Nothing}},Nothing}

    DCtx(ctx, navnode, droplinks=false) = new(ctx, navnode, droplinks, ctx.settings, [])
    DCtx(
        dctx::DCtx;
        navnode = dctx.navnode,
        droplinks = dctx.droplinks,
        settings = dctx.settings,
        footnotes = dctx.footnotes,
    ) = new(dctx.ctx, navnode, droplinks, settings, footnotes)
end

function SearchRecord(ctx::HTMLContext, navnode; fragment="", title=nothing, category="page", text="")
    page_title = mdflatten_pagetitle(DCtx(ctx, navnode))
    if title === nothing
        title = page_title
    end
    SearchRecord(
        pretty_url(ctx, get_url(ctx, navnode.page)),
        getpage(ctx, navnode),
        fragment,
        lowercase(category),
        title,
        page_title,
        text
    )
end

function SearchRecord(ctx::HTMLContext, navnode, node::Node, element::Documenter.AnchoredHeader)
    a = element.anchor
    SearchRecord(ctx, navnode;
        fragment=Documenter.anchor_fragment(a),
        title=mdflatten(node), # AnchoredHeader has Heading as single child
        category="section")
end

function SearchRecord(ctx, navnode, node::Node, ::MarkdownAST.AbstractElement)
    SearchRecord(ctx, navnode; text=mdflatten(node))
end

function JSON.lower(rec::SearchRecord)
    # Replace any backslashes in links, if building the docs on Windows
    src = replace(rec.src, '\\' => '/')
    ref = string(src, rec.fragment)
    Dict{String, String}(
        "location" => ref,
        "page" => rec.page_title,
        "title" => rec.title,
        "category" => rec.category,
        "text" => rec.text
    )
end

"""
Returns a page (as a [`Documenter.Page`](@ref) object) using the [`HTMLContext`](@ref).
"""
getpage(ctx::HTMLContext, path) = ctx.doc.blueprint.pages[path]
getpage(ctx::HTMLContext, navnode::Documenter.NavNode) = getpage(ctx, navnode.page)
getpage(dctx::DCtx) = getpage(dctx.ctx, dctx.navnode)

function render(doc::Documenter.Document, settings::HTML=HTML())
    @info "HTMLWriter: rendering HTML pages."
    !isempty(doc.user.sitename) || error("HTML output requires `sitename`.")
    if isempty(doc.blueprint.pages)
        error("Aborting HTML build: no pages under src/")
    elseif !haskey(doc.blueprint.pages, "index.md")
        @warn "Can't generate landing page (index.html): src/index.md missing" keys(doc.blueprint.pages)
    end

    if isa(settings.repolink, Default) && (isnothing(doc.user.remote) || Remotes.repourl(doc.user.remote) === nothing)
        @warn """
        Unable to determine the repository root URL for the navbar link.
        This can happen when a string is passed to the `repo` keyword of `makedocs`.

        To remove this warning, either pass a Remotes.Remote object to `repo` to completely
        specify the remote repository, or explicitly set the remote URL by setting `repolink`
        via `makedocs(format = HTML(repolink = "..."), ...)`.
        """
    end

    ctx = HTMLContext(doc, settings)
    ctx.search_index_js = "search_index.js"
    ctx.themeswap_js = copy_asset("themeswap.js", doc)
    ctx.warner_js = copy_asset("warner.js", doc)

    # Generate documenter.js file with all the JS dependencies
    ctx.documenter_js = "assets/documenter.js"
    if isfile(joinpath(doc.user.source, "assets", "documenter.js"))
        @warn "not creating 'documenter.js', provided by the user."
    else
        r = JSDependencies.RequireJS([
            RD.jquery, RD.jqueryui, RD.headroom, RD.headroom_jquery, RD.minisearch,
        ])
        RD.mathengine!(r, settings.mathengine)
        if !settings.prerender
            RD.highlightjs!(r, settings.highlights)
        end
        for filename in readdir(joinpath(ASSETS, "js"))
            path = joinpath(ASSETS, "js", filename)
            endswith(filename, ".js") && isfile(path) || continue
            push!(r, JSDependencies.parse_snippet(path))
        end
        JSDependencies.verify(r; verbose=true) || error("RequireJS declaration is invalid")
        JSDependencies.writejs(joinpath(doc.user.build, "assets", "documenter.js"), r)
    end

    for theme in THEMES
        copy_asset("themes/$(theme).css", doc)
    end

    size_limit_successes = map(collect(keys(doc.blueprint.pages))) do page
        idx = findfirst(nn -> nn.page == page, doc.internal.navlist)
        nn = (idx === nothing) ? Documenter.NavNode(page, nothing, nothing) : doc.internal.navlist[idx]
        @debug "Rendering $(page) [$(repr(idx))]"
        render_page(ctx, nn)
    end
    # ctx::HTMLContext might have accumulated some warnings about large at-example blocks
    # If so, we'll report them here in one big warning (rather than one each).
    if !isempty(ctx.atexample_warnings)
        msg = """
        For $(length(ctx.atexample_warnings)) @example blocks, the 'text/html' representation of the resulting
        object is above the the threshold (example_size_threshold: $(ctx.settings.example_size_threshold) bytes).
        """
        fallbacks = unique(w.fallback for w in ctx.atexample_warnings)
        # We'll impose some regular order, but importantly we want 'nothing'-s on the top
        for fallback in sort(fallbacks, by = s -> isnothing(s) ? "" : s)
            warnings = filter(w -> w.fallback == fallback, ctx.atexample_warnings)
            n_warnings = length(warnings)
            largest_size = maximum(w -> w.size_bytes, warnings)
            msg *= if isnothing(fallback)
                """
                - $(n_warnings) blocks had no image MIME show() method representation as an alternative.
                  Sticking to the 'text/html' representation (largest block is $(largest_size) bytes).
                """
            else
                """
                - $(n_warnings) blocks had '$(fallback)' fallback image representation available, using that.
                """
            end
            pages = sort(unique(w.page for w in warnings))
            msg *= "  On pages: $(join(pages, ", "))\n"
        end
        @warn(msg)
    end
    # Check that all HTML files are smaller or equal to size_threshold option
    all(size_limit_successes) || throw(HTMLSizeThresholdError())

    open(joinpath(doc.user.build, ctx.search_index_js), "w") do io
        println(io, "var documenterSearchIndex = {\"docs\":")
        # convert Vector{SearchRecord} to a JSON string + do additional JS escaping
        println(io, json_jsescape(ctx.search_index), "\n}")
    end

    generate_siteinfo_json(doc.user.build)
end

struct HTMLSizeThresholdError <: Exception end
function Base.showerror(io::IO, ::HTMLSizeThresholdError)
    print(io, """
    HTMLSizeThresholdError: Some generated HTML files are above size_threshold.
    See logged errors for details.""")
end

"""
Copies an asset from Documenters `assets/html/` directory to `doc.user.build`.
Returns the path of the copied asset relative to `.build`.
"""
function copy_asset(file, doc)
    src = joinpath(Documenter.assetsdir(), "html", file)
    alt_src = joinpath(doc.user.source, "assets", file)
    dst = joinpath(doc.user.build, "assets", file)
    isfile(src) || error("Asset '$file' not found at $(abspath(src))")

    # Since user's alternative assets are already copied over in a previous build
    # step and they should override Documenter's original assets, we only actually
    # perform the copy if <source>/assets/<file> does not exist. Note that checking
    # the existence of <build>/assets/<file> is not sufficient since the <build>
    # directory might be dirty from a previous build.
    if isfile(alt_src)
        @warn "not copying '$src', provided by the user."
    else
        ispath(dirname(dst)) || mkpath(dirname(dst))
        ispath(dst) && @warn "overwriting '$dst'."
        # Files in the Documenter folder itself are read-only when
        # Documenter is Pkg.added so we create a new file to get
        # correct file permissions.
        open(io -> write(dst, io), src, "r")
    end
    assetpath = normpath(joinpath("assets", file))
    # Replace any backslashes in links, if building the docs on Windows
    return replace(assetpath, '\\' => '/')
end

# Page
# ------------------------------------------------------------------------------

## Standard page
"""
Constructs and writes the page referred to by the `navnode` to `.build`.
"""
function render_page(ctx, navnode)
    @tags html div body
    head = render_head(ctx, navnode)
    sidebar = render_sidebar(ctx, navnode)
    navbar = render_navbar(ctx, navnode, true)
    article = render_article(ctx, navnode)
    footer = render_footer(ctx, navnode)
    htmldoc = render_html(ctx, navnode, head, sidebar, navbar, article, footer)
    write_html(ctx, navnode, htmldoc)
end

## Rendering HTML elements
# ------------------------------------------------------------------------------

"""
Renders the main `<html>` tag.
"""
function render_html(ctx, navnode, head, sidebar, navbar, article, footer, scripts::Vector{DOM.Node}=DOM.Node[])
    @tags html body div
    DOM.HTMLDocument(
        html[:lang=>ctx.settings.lang](
            head,
            body(
                div["#documenter"](
                    sidebar,
                    div[".docs-main"](navbar, article, footer),
                    render_settings(ctx),
                ),
            ),
            scripts...
        )
    )
end

"""
Renders the modal settings dialog.
"""
function render_settings(ctx)
    @tags div header section footer p button hr span select option label a

    theme_selector = p(
        label[".label"]("Theme"),
        div[".select"](
            select["#documenter-themepicker"](
                (option[:value=>theme](theme) for theme in THEMES)...,
                option[:value=>"auto"]("Automatic (OS)")
            )
        )
    )

    now_full, now_short = Dates.format(now(), dateformat"E d U Y HH:MM"), Dates.format(now(), dateformat"E d U Y")
    buildinfo = p(
        "This document was generated with ",
        a[:href => "https://github.com/JuliaDocs/Documenter.jl"]("Documenter.jl"),
        " version $(Documenter.DOCUMENTER_VERSION)",
        " on ",
        span[".colophon-date", :title => now_full](now_short),
        ". ",
        "Using Julia version $(Base.VERSION)."
    )

    div["#documenter-settings.modal"](
        div[".modal-background"],
        div[".modal-card"](
            header[".modal-card-head"](
                p[".modal-card-title"]("Settings"),
                button[".delete"]()
            ),
            section[".modal-card-body"](
                theme_selector, hr(), buildinfo
            ),
            footer[".modal-card-foot"]()
        )
    )
end

function render_head(ctx, navnode)
    @tags head meta link script title
    src = get_url(ctx, navnode)

    page_title = "$(mdflatten_pagetitle(DCtx(ctx, navnode))) · $(ctx.doc.user.sitename)"

    description = if navnode !== ctx.search_navnode
        get(getpage(ctx, navnode).globals.meta, :Description) do
            default_site_description(ctx)
        end
    else
        default_site_description(ctx)
    end

    css_links = [
        RD.lato,
        RD.juliamono,
        RD.fontawesome_css...,
        RD.katex_css,
    ]

    head(
        meta[:charset=>"UTF-8"],
        meta[:name => "viewport", :content => "width=device-width, initial-scale=1.0"],

        # Title tag and meta tags
        title(page_title),
        meta[:name => "title", :content => page_title],
        meta[:property => "og:title", :content => page_title],
        meta[:property => "twitter:title", :content => page_title],

        # Description meta tags
        meta[:name => "description", :content => description],
        meta[:property => "og:description", :content => description],
        meta[:property => "twitter:description", :content => description],

        # Canonical URL tags
        canonical_url_tags(ctx, navnode),

        # Preview image meta tags
        preview_image_meta_tags(ctx),

        # Analytics and warning scripts
        analytics_script(ctx.settings.analytics),
        warning_script(src, ctx),

        # Stylesheets.
        map(css_links) do each
            link[:href => each, :rel => "stylesheet", :type => "text/css"]
        end,

        script("documenterBaseURL=\"$(relhref(src, "."))\""),
        script[
            :src => RD.requirejs_cdn,
            Symbol("data-main") => relhref(src, ctx.documenter_js)
        ],
        script[:src => relhref(src, ctx.search_index_js)],

        script[:src => relhref(src, "siteinfo.js")],
        script[:src => relhref(src, "../versions.js")],
        # Themes. Note: we reverse the list to make sure that the default theme (first in
        # the array) comes as the last <link> tag.
        map(Iterators.reverse(enumerate(THEMES))) do (i, theme)
            e = link[".docs-theme-link",
                :rel => "stylesheet", :type => "text/css",
                :href => relhref(src, "assets/themes/$(theme).css"),
                Symbol("data-theme-name") => theme,
            ]
            (i == 1) && push!(e.attributes, Symbol("data-theme-primary") => "")
            (i == 2) && push!(e.attributes, Symbol("data-theme-primary-dark") => "")
            return e
        end,
        script[:src => relhref(src, ctx.themeswap_js)],
        # Custom user-provided assets.
        asset_links(src, ctx.settings.assets),
    )
end

function canonical_url_tags(ctx, navnode)
    @tags meta link
    canonical = canonical_url(ctx, navnode)
    if isnothing(canonical)
        return DOM.VOID
    else
        tags = DOM.Node[
            meta[:property => "og:url", :content => canonical],
            meta[:property => "twitter:url", :content => canonical],
            link[:rel => "canonical", :href => canonical]
        ]
        return tags
    end
end

function preview_image_meta_tags(ctx)
    @tags meta
    canonical_link = ctx.settings.canonical
    preview = find_preview_image(ctx)
    if canonical_link === nothing || preview === nothing
        # Cannot construct absolute link if canonical URL is not set
        return DOM.VOID
    else
        # Return OpenGraph and Twitter image meta tags.
        preview = replace(preview, r"[/\\]+" => "/")
        preview_url = rstrip(canonical_link, '/') * "/" * preview
        tags = DOM.Node[
            meta[:property => "og:image", :content => preview_url],
            meta[:property => "twitter:image", :content => preview_url],
            meta[:property => "twitter:card", :content => "summary_large_image"]
        ]
        return tags
    end
end

function default_site_description(ctx)
    if isnothing(ctx.settings.description)
        return "Documentation for $(ctx.doc.user.sitename)."
    else
        return ctx.settings.description
    end
end

function find_preview_image(ctx)
    for ext in ["png", "webp", "gif", "jpg", "jpeg"]
        filename = joinpath("assets", "preview.$(ext)")
        isfile(joinpath(ctx.doc.user.build, filename)) && return filename
    end
    return nothing
end

function asset_links(src::AbstractString, assets::Vector{HTMLAsset})
    isabspath(src) && @error("Absolute path '$src' passed to asset_links")
    @tags link script
    links = DOM.Node[]
    for asset in assets
        class = asset.class
        url = asset.islocal ? relhref(src, asset.uri) : asset.uri
        node =
            class == :ico ? link[:href  => url, :rel => "icon", :type => "image/x-icon", pairs(asset.attributes)...] :
            class == :css ? link[:href  => url, :rel => "stylesheet", :type => "text/css", pairs(asset.attributes)...] :
            class == :js  ? script[:src => url, pairs(asset.attributes)...] : continue # Skip non-js/css files.
        push!(links, node)
    end
    return links
end

function analytics_script(tracking_id::AbstractString)
    @tags script
    isempty(tracking_id) ? DOM.VOID : [
        script[:async, :src => "https://www.googletagmanager.com/gtag/js?id=$(tracking_id)"](),
        script("""
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '$(tracking_id)', {'page_path': location.pathname + location.search + location.hash});
        """)
    ]
end

function warning_script(src, ctx)
    if ctx.settings.warn_outdated
        return Tag(:script)[Symbol(OUTDATED_VERSION_ATTR), :src => relhref(src, ctx.warner_js)]()
    end
    return DOM.VOID
end

# Navigation menu
# ------------------------------------------------------------------------------

struct NavMenuContext
    htmlctx :: HTMLContext
    current :: Documenter.NavNode
    idstack :: Vector{Int}
end
NavMenuContext(ctx::HTMLContext, current::Documenter.NavNode) = NavMenuContext(ctx, current, [])

function render_sidebar(ctx, navnode)
    @tags a form img input nav div button select option span
    src = get_url(ctx, navnode)
    navmenu = nav[".docs-sidebar"]

    # The logo and sitename will point to the first page in the navigation menu
    href = navhref(ctx, first(ctx.doc.internal.navlist), navnode)

    # Logo
    logo = find_image_asset(ctx, "logo")
    logo_dark = find_image_asset(ctx, "logo-dark")
    if logo !== nothing
        alt = isempty(ctx.doc.user.sitename) ? "Logo" : "$(ctx.doc.user.sitename) logo"
        logo_element = a[".docs-logo", :href => href]
        if logo_dark === nothing
            push!(logo_element.nodes, img[:src => relhref(src, logo), :alt => alt])
        else
            push!(logo_element.nodes, img[".docs-light-only", :src => relhref(src, logo), :alt => alt])
            push!(logo_element.nodes, img[".docs-dark-only", :src => relhref(src, logo_dark), :alt => alt])
        end
        push!(navmenu.nodes, logo_element)
    end
    # Sitename
    if ctx.settings.sidebar_sitename
        push!(navmenu.nodes, div[".docs-package-name"](
            span[".docs-autofit"](a[:href => href](ctx.doc.user.sitename))
        ))
    end

    # Search box
    push!(navmenu.nodes,
        button["#documenter-search-query.docs-search-query.input.is-rounded.is-small.is-clickable.my-2.mx-auto.py-1.px-2"]("Search docs (Ctrl + /)")
    )

    # The menu itself
    menu = navitem(NavMenuContext(ctx, navnode))
    push!(menu.attributes, :class => "docs-menu")
    push!(navmenu.nodes, menu)

    # Version selector
    let
        vs_class = ".docs-version-selector.field.has-addons"
        vs_label = span[".docs-label.button.is-static.is-size-7"]("Version")
        vs_label = div[".control"](vs_label)
        vs_select = select["#documenter-version-selector"]
        if !isempty(ctx.doc.user.version)
            vs_class = "$(vs_class).visible"
            opt = option[:value => "#", :selected => "selected", ](ctx.doc.user.version)
            vs_select = vs_select(opt)
        end
        vs_select = div[".select.is-fullwidth.is-size-7"](vs_select)
        vs_select = div[".docs-selector.control.is-expanded"](vs_select)
        push!(navmenu.nodes, div[vs_class](vs_label, vs_select))
    end
    navmenu
end

function find_image_asset(ctx, name)
    for ext in ["svg", "png", "webp", "gif", "jpg", "jpeg"]
        filename = joinpath("assets", "$(name).$(ext)")
        isfile(joinpath(ctx.doc.user.build, filename)) && return filename
    end
    return nothing
end

"""
[`navitem`](@ref) returns the lists and list items of the navigation menu.
It gets called recursively to construct the whole tree.

It always returns a [`DOM.Node`](@ref). If there's nothing to display (e.g. the node is set
to be invisible), it returns an empty text node (`DOM.Node("")`).
"""
navitem(nctx) = navitem(nctx, nctx.htmlctx.doc.internal.navtree)
function navitem(nctx, nns::Vector)
    push!(nctx.idstack, 0)
    nodes = map(nns) do nn
        nctx.idstack[end] = nctx.idstack[end] + 1
        navitem(nctx, nn)
    end
    pop!(nctx.idstack)
    filter!(node -> node.name !== DOM.TEXT, nodes) # FIXME: why?
    ulclass = (length(nctx.idstack) >= nctx.htmlctx.settings.collapselevel) ? ".collapsed" : ""
    isempty(nodes) ? DOM.Node("") : DOM.Tag(:ul)[ulclass](nodes)
end
function navitem(nctx, nn::Documenter.NavNode)
    @tags ul li span a input label i
    ctx, current = nctx.htmlctx, nctx.current
    dctx = DCtx(nctx.htmlctx, nn, true)
    # We'll do the children first, primarily to determine if this node has any that are
    # visible. If it does not and it itself is not visible (including current), then
    # we'll hide this one as well, returning an empty string Node.
    children = navitem(nctx, nn.children)
    if nn !== current && !nn.visible && children.name === DOM.TEXT
        return DOM.Node("")
    end

    # construct this item
    title = domify(dctx, pagetitle(dctx))
    currentclass = (nn === current) ? ".is-active" : ""
    item = if length(nctx.idstack) >= ctx.settings.collapselevel && children.name !== DOM.TEXT
        menuid = "menuitem-$(join(nctx.idstack, '-'))"
        input_attr = ["#$(menuid).collapse-toggle", :type => "checkbox"]
        nn in Documenter.navpath(nctx.current) && push!(input_attr, :checked)
        li[currentclass](
            input[input_attr...],
            label[".tocitem", :for => menuid](span[".docs-label"](title), i[".docs-chevron"]),
        )
    elseif nn.page === nothing
        li[currentclass](span[".tocitem"](title))
    else
        li[currentclass](a[".tocitem", :href => navhref(ctx, nn, current)](title))
    end

    # add the subsections (2nd level headings) from the page
    if (nn === current) && current.page !== nothing
        subs = collect_subsections(getpage(ctx, current.page).mdast)
        internal_links = map(subs) do s
            istoplevel, anchor, text = s
            _li = istoplevel ? li[".toplevel"] : li[]
            _li(a[".tocitem", :href => anchor](span(domify(dctx, text.children))))
        end
        # Only create the ul.internal tag if there actually are in-page headers
        length(internal_links) > 0 && push!(item.nodes, ul[".internal"](internal_links))
    end

    # add the visible subsections, if any, as a single list
    (children.name === DOM.TEXT) || push!(item.nodes, children)

    item
end

function render_navbar(ctx, navnode, edit_page_link::Bool)
    @tags div header nav ul li a span

    # Hamburger on mobile
    navbar_left = a[
        "#documenter-sidebar-button.docs-sidebar-button.docs-navbar-link.fa-solid.fa-bars.is-hidden-desktop",
        :href => "#",
    ]

    # The breadcrumb (navigation links on top)
    navpath = Documenter.navpath(navnode)
    header_links = map(navpath) do nn
        dctx = DCtx(ctx, nn, true)
        title = domify(dctx, pagetitle(dctx))
        nn.page === nothing ? li(a[".is-disabled"](title)) : li(a[:href => navhref(ctx, nn, navnode)](title))
    end
    header_links[end] = header_links[end][".is-active"]
    breadcrumb = nav[".breadcrumb"](
        ul[".is-hidden-mobile"](header_links),
        ul[".is-hidden-tablet"](header_links[end]) # when on mobile, we only show the page title, basically
    )

    # The "Edit on GitHub" links and the hamburger to open the sidebar (on mobile) float right
    navbar_right = div[".docs-right"]

    # Set up the link to the root of the remote Git repository
    #
    # By default, we try to determine it from the configured remote. If that fails, the link
    # is not displayed. The user can also pass `repolink` to HTML to either disable it
    # (repolink = nothing) or override the link URL (if set to a string). In the latter case,
    # we try to figure out what icon and string we should use based on the URL.
    if !isnothing(ctx.settings.repolink) && (ctx.settings.repolink isa String || ctx.doc.user.remote isa Remotes.Remote)
        url, (host, logo) = if ctx.settings.repolink isa String
            ctx.settings.repolink, host_logo(ctx.settings.repolink)
        else # ctx.doc.user.remote isa Remotes.Remote
            Remotes.repourl(ctx.doc.user.remote), host_logo(ctx.doc.user.remote)
        end
        # repourl() can sometimes return a nothing (Remotes.URL)
        if !isnothing(url)
            repo_title = "View the repository" * (isempty(host) ? "" : " on $host")
            push!(navbar_right.nodes,
                a[".docs-navbar-link", :href => url, :title => repo_title](
                    span[".docs-icon.fa-brands"](logo),
                    span[".docs-label.is-hidden-touch"](isempty(host) ? "Repository" : host)
                )
            )
        end
    end
    # Add an edit link, with just an icon, but only on pages where edit_page_link is true.
    # Some pages, like search, are special and do not have a source file to link to.
    edit_page_link && edit_link(ctx, navnode) do logo, title, url
        push!(navbar_right.nodes,
            a[".docs-navbar-link", :href => url, :title => title](
                span[".docs-icon.fa-solid"](logo)
            )
        )
    end

    # Settings cog
    push!(navbar_right.nodes, a[
        "#documenter-settings-button.docs-settings-button.docs-navbar-link.fa-solid.fa-gear",
        :href => "#", :title => "Settings",
    ])

    # Collapse/Expand All articles toggle
    push!(navbar_right.nodes, a[
        "#documenter-article-toggle-button.docs-article-toggle-button.fa-solid.fa-chevron-up",
        :href=>"javascript:;", :title=>"Collapse all docstrings",
    ])

    # Construct the main <header> node that should be the first element in div.docs-main
    header[".docs-navbar"](navbar_left, breadcrumb, navbar_right)
end

"""
Calls `f(logo, title, url)` if it is possible to create an edit link for the `navnode`.
"""
function edit_link(f, ctx, navnode)
    view_logo, edit_logo = "\uf15c", "\uf044" # 'fa-file-lines' and 'fa-pen-to-square', from .fa-solid class
    # Let's fetch the edit path. Usually this is the source file of the page, but the user
    # can override it specifying the EditURL option in an @meta block. Usually, it is a
    # relative path pointing to a file, but can also be set to an absolute URL.
    editpath = get(getpage(ctx, navnode).globals.meta, :EditURL, getpage(ctx, navnode).source)
    # If the user has set :EditURL to nothing, then the link will be disabled. Note: the
    # .source field of a Page is always a String.
    isnothing(editpath) && return
    # If the user has set an absolute :EditURL, then we just use that URL without
    # modifications. The only thing we want to do is to determine the Git remote host name
    # from the URL, if we can. We also use the "view" verb and logo here, since we do not
    # know if the remote link allows editing, and so it is the safer option.
    if Documenter.isabsurl(editpath)
        host, _ = host_logo(editpath)
        title = "View source" * (isempty(host) ? "" : " on $(host)")
        f(view_logo, title, editpath)
        return
    end
    # If the user has disable Git, then we can not determine edit links
    ctx.settings.disable_git && return
    # If the user has passed HTML(edit_link = nothing), then all edit links (with relative
    # paths) are disabled.
    isnothing(ctx.settings.edit_link) && return
    # edit_url will call abspath() on the path, but our working directory is set to
    # makedocs' root argument. The Page .source paths are already relative to that, but
    # user-provided EditURLs are assumed to be relative to the current page. So we need to
    # update the path accordingly.
    if editpath != getpage(ctx, navnode).source
        editpath = joinpath(dirname(getpage(ctx, navnode).source), editpath)
    end
    # If the user has set `ctx.settings.edit_link = :commit` (only non-String value), then
    # we set pass commit=nothing and let edit_url figure out the commit ref with Git.
    # We also render a "view" link, instead of the usual "edit" link, since it is usually
    # not possible to directly modify the repository files if they refer to a particular
    # commit.
    verb, logo, commit = if ctx.settings.edit_link === :commit
        "View", view_logo, nothing
    else
        "Edit", edit_logo, ctx.settings.edit_link
    end
    host, _ = host_logo(ctx.doc.user.remote)
    editurl = Documenter.edit_url(ctx.doc, editpath, rev=commit)
    # It is possible for editurl() to return a nothing, if something goes wrong
    isnothing(editurl) && return
    # Create the edit link
    f(logo, "$verb source" * (isempty(host) ? "" : " on $(host)"), editurl)
    return
end

# All these logos are from the .fa-brands (brands) class
const host_logo_github    = (host = "GitHub",       logo = "\uf09b") # fa-github
const host_logo_bitbucket = (host = "BitBucket",    logo = "\uf171") # fa-bitbucket
const host_logo_gitlab    = (host = "GitLab",       logo = "\uf296") # fa-gitlab
const host_logo_azure     = (host = "Azure DevOps", logo = "\uf3ca") # fa-microsoft; TODO: change to ADO logo when added to FontAwesome
const host_logo_fallback  = (host = "",             logo = "\uf841") # fa-git-alt
host_logo(remote::Remotes.GitHub) = host_logo_github
host_logo(remote::Remotes.URL) = host_logo(remote.urltemplate)
host_logo(remote::Union{Remotes.Remote,Nothing}) = host_logo_fallback
function host_logo(remoteurl::String)
    occursin("github", remoteurl)    ? host_logo_github    :
    occursin("gitlab", remoteurl)    ? host_logo_gitlab    :
    occursin("bitbucket", remoteurl) ? host_logo_bitbucket :
    occursin("azure", remoteurl)     ? host_logo_azure     :
    host_logo_fallback
end

function render_footer(ctx, navnode)
    @tags a div nav
    # Navigation links (previous/next page), if there are any
    navlinks = DOM.Node[]
    if navnode.prev !== nothing
        dctx = DCtx(ctx, navnode.prev, true)
        title = domify(dctx, pagetitle(dctx))
        link = a[".docs-footer-prevpage", :href => navhref(ctx, navnode.prev, navnode)]("« ", title)
        push!(navlinks, link)
    end
    if navnode.next !== nothing
        dctx = DCtx(ctx, navnode.next, true)
        title = domify(dctx, pagetitle(dctx))
        link = a[".docs-footer-nextpage", :href => navhref(ctx, navnode.next, navnode)](title, " »")
        push!(navlinks, link)
    end

    linebreak = div[".flexbox-break"]()
    footer_content = ctx.settings.footer

    nav_children = []
    if !isempty(navlinks)
        push!(nav_children, navlinks, linebreak)
    end

    if footer_content !== nothing
        footer_container = domify(DCtx(ctx, navnode), ctx.settings.footer)
        push!(first(footer_container).attributes, :class => "footer-message")
        push!(nav_children, footer_container)
    end

    return nav[".docs-footer"](nav_children...)
end

# Article (page contents)
# ------------------------------------------------------------------------------

function render_article(ctx, navnode)
    dctx = DCtx(ctx, navnode)
    # function render_article(ctx, navnode)
    @tags article section ul li hr span a div p

    # Build the page itself (and collect any footnotes)
    empty!(dctx.footnotes)
    art_body = article["#documenter-page.content"](domify(dctx))
    # Footnotes, if there are any
    if !isempty(dctx.footnotes)
        fnotes = map(dctx.footnotes) do f
            # If there are any nested footnotes, they'll get ignored.
            dctx_footnote = DCtx(dctx, footnotes = nothing)
            fid = "footnote-$(f.element.id)"
            citerefid = "citeref-$(f.element.id)"
            if length(f.children) == 1 && first(f.children).element isa MarkdownAST.Paragraph
                li["#$(fid).footnote"](
                    a[".tag.is-link", :href => "#$(citerefid)"](f.element.id),
                    domify(dctx_footnote, first(f.children).children),
                )
            else
                li["#$(fid).footnote"](
                    a[".tag.is-link", :href => "#$(citerefid)"](f.element.id),
                    # passing an empty MD() as `parent` to give it block context
                    domify(dctx_footnote, f.children),
                )
            end
        end
        push!(art_body.nodes, section[".footnotes.is-size-7"](ul(fnotes)))
    end
    return art_body
end

# expand the versions argument from the user
# and return entries and needed symlinks
function expand_versions(dir, versions)
    # output: entries and symlinks
    entries = String[]
    symlinks = Pair{String,String}[]

    # read folders and filter out symlinks
    available_folders = readdir(dir)
    cd(() -> filter!(!islink, available_folders), dir)

    # filter and sort release folders
    vnum(x) = VersionNumber(x)
    version_folders = [x for x in available_folders if occursin(Base.VERSION_REGEX, x)]
    sort!(version_folders, lt = (x, y) -> vnum(x) < vnum(y), rev = true)
    release_folders = filter(x -> (v = vnum(x); v.prerelease == () && v.build == ()), version_folders)
    # pre_release_folders = filter(x -> (v = vnum(x); v.prerelease != () || v.build != ()), version_folders)
    major_folders = filter!(x -> (v = vnum(x); v.major != 0),
                            unique(x -> (v = vnum(x); v.major), release_folders))
    minor_folders = filter!(x -> (v = vnum(x); !(v.major == 0 && v.minor == 0)),
                            unique(x -> (v = vnum(x); (v.major, v.minor)), release_folders))
    patch_folders = unique(x -> (v = vnum(x); (v.major, v.minor, v.patch)), release_folders)

    filter!(x -> vnum(x) !== 0, major_folders)

    # populate output
    for entry in versions
        if entry == "v#" # one doc per major release
            for x in major_folders
                vstr = "v$(vnum(x).major).$(vnum(x).minor)"
                push!(entries, vstr)
                push!(symlinks, vstr => x)
            end
        elseif entry == "v#.#" # one doc per minor release
            for x in minor_folders
                vstr = "v$(vnum(x).major).$(vnum(x).minor)"
                push!(entries, vstr)
                push!(symlinks, vstr => x)
            end
        elseif entry == "v#.#.#" # one doc per patch release
            for x in patch_folders
                vstr = "v$(vnum(x).major).$(vnum(x).minor).$(vnum(x).patch)"
                push!(entries, vstr)
                push!(symlinks, vstr => x)
            end
        elseif entry == "v^" || (entry isa Pair && entry.second == "v^")
            if !isempty(release_folders)
                x = first(release_folders)
                vstr = isa(entry, Pair) ? entry.first : "v$(vnum(x).major).$(vnum(x).minor)"
                push!(entries, vstr)
                push!(symlinks, vstr => x)
            end
        elseif entry isa Pair
            k, v = entry
            i = findfirst(==(v), available_folders)
            if i === nothing
                @warn "no match for `versions` entry `$(repr(entry))`"
            else
                push!(entries, k)
                push!(symlinks, k => v)
            end
        else
            @warn "no match for `versions` entry `$(repr(entry))`"
        end
    end
    unique!(entries) # remove any duplicates

    # generate remaining symlinks
    foreach(x -> push!(symlinks, "v$(vnum(x).major)" => x), major_folders)
    foreach(x -> push!(symlinks, "v$(vnum(x).major).$(vnum(x).minor)" => x), minor_folders)
    foreach(x -> push!(symlinks, "v$(vnum(x).major).$(vnum(x).minor).$(vnum(x).patch)" => x), patch_folders)
    filter!(x -> x.first != x.second, unique!(symlinks))

    # assert that none of the links point to another link
    for link in symlinks
        i = findfirst(x -> link.first == x.second, symlinks)
        if i !== nothing
            throw(ArgumentError("link `$(link)` incompatible with link `$(symlinks[i])`."))
        end
    end

    return entries, symlinks
end

# write version file
function generate_version_file(versionfile::AbstractString, entries, symlinks = [])
    open(versionfile, "w") do buf
        println(buf, "var DOC_VERSIONS = [")
        for folder in entries
            println(buf, "  \"", folder, "\",")
        end
        println(buf, "];")

        # entries is empty if no versions have been built at all
        isempty(entries) && return

        # The first element in entries corresponds to the latest version, but is usually not the full version
        # number. So this essentially follows the symlinks that will be generated to figure out the full
        # version number (stored in DOCUMENTER_CURRENT_VERSION in siteinfo.js).
        # Every symlink points to a directory, so this doesn't need to be recursive.
        newest = first(entries)
        for s in symlinks
            if s.first == newest
                newest = s.second
                break
            end
        end
        println(buf, "var DOCUMENTER_NEWEST = \"$(newest)\";")
        println(buf, "var DOCUMENTER_STABLE = \"$(first(entries))\";")
    end
end

# write redirect file
function generate_redirect_file(redirectfile::AbstractString, entries)
    # The link to the redirected destination is same as outdated-warning. (DOCUMENTER_STABLE)

    comment = "<!--This file is automatically generated by Documenter.jl-->"

    isfile(redirectfile) && !startswith(read(redirectfile, String), comment) && return
    isempty(entries) && return

    open(redirectfile, "w") do buf
        println(buf, comment)
        println(buf, "<meta http-equiv=\"refresh\" content=\"0; url=./$(first(entries))/\"/>")
    end
end

function generate_siteinfo_file(dir::AbstractString, version::Union{AbstractString,Nothing})
    open(joinpath(dir, "siteinfo.js"), "w") do buf
        if version !== nothing
            println(buf, "var DOCUMENTER_CURRENT_VERSION = \"$(version)\";")
        else
            println(buf, "var DOCUMENTER_VERSION_SELECTOR_DISABLED = true;")
        end
    end
end

# The .documenter-siteinfo.json can contain various metadata (such as the Documenter version
# used to generate the docs) that automated tools (like DocumenterTools) can use to when
# performing e.g. post-processing after the fact on the generated docs.
#
# The file should be assumed to contain a JSON object that contains at least a 'documenter'
# field. The 'documenter' field is controlled by Documenter. Other tools are free to modify
# the file and add their own values, preferably in a namespace that is unlikely to cause
# a conflict.
#
# Note: siteinfo.js is generated by `deploydocs` and gets loaded in the HTML, whereas
# .documenter-siteinfo.json gets generated by makedocs and does not normally get loaded
# in the HTML
function generate_siteinfo_json(root::AbstractString)
    isdir(root) || error("generate_siteinfo_json: not a directory at $root")
    siteinfo = Dict(
        "documenter_version" => string(Documenter.DOCUMENTER_VERSION),
        "julia_version" => string(VERSION),
        "generation_timestamp" => Dates.format(now(), dateformat"yyyy-mm-dd\THH:MM:SS"),
    )
    open(joinpath(root, ".documenter-siteinfo.json"), "w") do io
        JSON.print(io, Dict("documenter" => siteinfo))
    end
    return
end

## domify(...)
# ------------

function domify(dctx::DCtx, node::Node, element::MarkdownAST.AbstractElement)
    error("Unimplemented element: $(typeof(element))")
end

function domify(dctx::DCtx)
    ctx, navnode = dctx.ctx, dctx.navnode
    map(getpage(ctx, navnode).mdast.children) do node
        rec = SearchRecord(ctx, navnode, node, node.element)
        push!(ctx.search_index, rec)
        domify(dctx, node, node.element)
    end
end
domify(dctx::DCtx, node::Node) = domify(dctx, node, node.element)
function domify(dctx::DCtx, children)
    @assert eltype(children) <: Node
    map(child -> domify(dctx, child), children)
end

domify(dctx::DCtx, node::Node, ::MarkdownAST.Document) = domify(dctx, node.children)

function domify(dctx::DCtx, node::Node, ah::Documenter.AnchoredHeader)
    @assert length(node.children) == 1 && isa(first(node.children).element, MarkdownAST.Heading)
    ctx, navnode = dctx.ctx, dctx.navnode
    anchor = ah.anchor
    # function domify(ctx, navnode, anchor::Anchor)
    @tags a
    frag = Documenter.anchor_fragment(anchor)
    legacy = anchor.nth == 1 ? (a[:id => lstrip(frag, '#')*"-1"],) : ()
    h = first(node.children)
    Tag(Symbol("h$(h.element.level)"))[:id => lstrip(frag, '#')](
        a[".docs-heading-anchor", :href => frag](domify(dctx, h.children)),
        legacy...,
        a[".docs-heading-anchor-permalink", :href => frag, :title => "Permalink"]
    )
end

struct ListBuilder
    es::Vector
end
ListBuilder() = ListBuilder([])

import Base: push!
function push!(lb::ListBuilder, level, node)
    @assert level >= 1
    if level == 1
        push!(lb.es, node)
    else
        if isempty(lb.es) || typeof(last(lb.es)) !== ListBuilder
            push!(lb.es, ListBuilder())
        end
        push!(last(lb.es), level-1, node)
    end
end

function domify(lb::ListBuilder)
    @tags ul li
    ul(map(e -> isa(e, ListBuilder) ? li[".no-marker"](domify(e)) : li(e), lb.es))
end

function domify(dctx::DCtx, node::Node, contents::Documenter.ContentsNode)
    ctx, navnode = dctx.ctx, dctx.navnode
    # function domify(ctx, navnode, contents::Documenter.ContentsNode)
    @tags a
    navnode_dir = dirname(navnode.page)
    navnode_url = get_url(ctx, navnode)
    lb = ListBuilder()
    for (count, path, anchor) in contents.elements
        header = first(anchor.node.children)
        level = header.element.level
        # Skip header levels smaller than the requested mindepth
        level = level - contents.mindepth + 1
        level < 1 && continue
        path = joinpath(navnode_dir, path) # links in ContentsNodes are relative to current page
        path = pretty_url(ctx, relhref(navnode_url, get_url(ctx, path)))
        url = string(path, Documenter.anchor_fragment(anchor))
        node = a[:href=>url](domify(DCtx(dctx, droplinks=true), header.children))
        push!(lb, level, node)
    end
    domify(lb)
end

function domify(dctx::DCtx, node::Node, index::Documenter.IndexNode)
    ctx, navnode = dctx.ctx, dctx.navnode
    # function domify(ctx, navnode, index::Documenter.IndexNode)
    @tags a code li ul
    navnode_dir = dirname(navnode.page)
    navnode_url = get_url(ctx, navnode)
    lis = map(index.elements) do el
        object, doc, path, mod, cat = el
        path = joinpath(navnode_dir, path) # links in IndexNodes are relative to current page
        path = pretty_url(ctx, relhref(navnode_url, get_url(ctx, path)))
        url = string(path, "#", Documenter.slugify(object))
        li(a[:href=>url](code("$(object.binding)")))
    end
    ul(lis)
end

domify(dctx::DCtx, node::Node, ::Documenter.DocsNodesBlock) = domify(dctx, node.children)

function domify(dctx::DCtx, mdast_node::Node, node::Documenter.DocsNode)
    ctx, navnode = dctx.ctx, dctx.navnode
    # function domify(ctx, navnode, node::Documenter.DocsNode)
    @tags a code article header span

    # push to search index
    rec = SearchRecord(ctx, navnode;
        fragment=Documenter.anchor_fragment(node.anchor),
        title=string(node.object.binding),
        category=Documenter.doccat(node.object),
        text = mdflatten(mdast_node))
    push!(ctx.search_index, rec)

    article[".docstring"](
        header(
            a[".docstring-article-toggle-button.fa-solid.fa-chevron-down", :href=>"javascript:;", :title=>"Collapse docstring"],
            a[".docstring-binding", :id=>node.anchor.id, :href=>"#$(node.anchor.id)"](code("$(node.object.binding)")),
            " — ", # &mdash;
            span[".docstring-category"]("$(Documenter.doccat(node.object))")
        ),
        domify_doc(dctx, mdast_node)
    )
end

function domify_doc(dctx::DCtx, node::Node)
    @assert node.element isa Documenter.DocsNode
    ctx, navnode = dctx.ctx, dctx.navnode
    # function domify_doc(ctx, navnode, md::Markdown.MD)
    @tags a section footer div
    # The `:results` field contains a vector of `Docs.DocStr` objects associated with
    # each markdown object. The `DocStr` contains data such as file and line info that
    # we need for generating correct source links.
    map(zip(node.element.mdasts, node.element.results)) do (markdown, result)
        ret = section(div(domify(dctx, markdown)))
        # When a source link is available then print the link.
        if !ctx.settings.disable_git
            url = Documenter.source_url(ctx.doc, result)
            if url !== nothing
                push!(ret.nodes, a[".docs-sourcelink", :target=>"_blank", :href=>url]("source"))
            end
        end
        return ret
    end
end

function domify(dctx::DCtx, ::Node, evalnode::Documenter.EvalNode)
    isnothing(evalnode.result) ? DOM.Node[] : domify(dctx, evalnode.result.children)
end

# nothing to show for MetaNodes, so we just return an empty list
domify(::DCtx, ::Node, ::Documenter.MetaNode) = DOM.Node[]
domify(::DCtx, ::Node, ::Documenter.SetupNode) = DOM.Node[]

function domify(::DCtx, ::Node, raw::Documenter.RawNode)
    raw.name === :html ? Tag(Symbol("#RAW#"))(raw.text) : DOM.Node[]
end


# Utilities
# ------------------------------------------------------------------------------

"""
Writes the HTML DOM into the HTML file that corresponds to `navnode`.
Prints a warning/error if the page goes over the `size_threshold` or `size_threshold_warn`
limits, and in the former case also returns `false`, to report back to the caller that the
size threshold check failed.
"""
function write_html(ctx::HTMLContext, navnode::Documenter.NavNode, page_html::DOM.HTMLDocument) :: Bool
    page_path = get_url(ctx, navnode)
    buf = IOBuffer()
    print(buf, page_html)
    path = joinpath(ctx.doc.user.build, page_path)
    isdir(dirname(path)) || mkpath(dirname(path))
    file_size = open(io -> write(io, take!(buf)), path; write=true)

    file_size_format_results = format_units(file_size)
    size_threshold_format_results = format_units(ctx.settings.size_threshold)
    size_threshold_warn_format_results = format_units(ctx.settings.size_threshold_warn)

    size_threshold_msg(var::Symbol) = """
    Generated HTML over $(var) limit: $(navnode.page)
        Generated file size: $file_size_format_results
        size_threshold_warn: $size_threshold_warn_format_results
        size_threshold:      $size_threshold_format_results
        HTML file:           $(page_path)"""
    if navnode.page in ctx.settings.size_threshold_ignore
        if file_size > ctx.settings.size_threshold_warn
            @debug """
            $(size_threshold_msg(:size_threshold_warn))
            Hard limit ignored due to 'size_threshold_ignore'.
            """ size_threshold_ignore = ctx.settings.size_threshold_ignore
        end
    elseif file_size > ctx.settings.size_threshold
        @error size_threshold_msg(:size_threshold)
        return false
    elseif file_size > ctx.settings.size_threshold_warn
        @warn size_threshold_msg(:size_threshold_warn)
    end
    return true
end

"""
Calculates and converts bytes to appropriate format.
"""
function format_units(size)
    unit = "bytes"

    if size == typemax(Int)
        return "(no limit)"
    end
    if size >= 1024
        size = size / 1024
        unit = "KiB"
        if size >= 1024
            size = size / 1024
            unit = "MiB"
        end
    end

    return string(round(size, digits = 2), " (", unit, ")")
end

"""
Get the relative hyperlink between two [`Documenter.NavNode`](@ref)s. Assumes that both
[`Documenter.NavNode`](@ref)s have an associated [`Documenter.Page`](@ref) (i.e. `.page`
is not `nothing`).
"""
navhref(ctx, to, from) = pretty_url(ctx, relhref(get_url(ctx, from), get_url(ctx, to)))

"""
Calculates a relative HTML link from one path to another.
"""
function relhref(from, to)
    pagedir = dirname(from)
    # The regex separator replacement is necessary since otherwise building the docs on
    # Windows will result in paths that have `//` separators which break asset inclusion.
    replace(relpath(to, isempty(pagedir) ? "." : pagedir), r"[/\\]+" => "/")
end

"""
Returns the full path corresponding to a path of a `.md` page file. The the input and output
paths are assumed to be relative to `src/`.
"""
function get_url(ctx, path::AbstractString)
    if ctx.settings.prettyurls
        d = if basename(path) == "index.md"
            dirname(path)
        else
            first(splitext(path))
        end
        isempty(d) ? "index.html" : "$d/index.html"
    else
        # change extension to .html
        string(splitext(path)[1], ".html")
    end
end

"""
Generates a unique file for the output of an at-example block if it goes over the configured
size threshold, and returns the filename (that should be in the same directory are the
corresponding HTML file). If the data is under the threshold, no file is created, and the
function returns `nothing`.
"""
function write_data_file(dctx::DCtx, data::Union{Vector{UInt8},AbstractString}; suffix::AbstractString)
    ctx, navnode = dctx.ctx, dctx.navnode
    # If we're under the threshold, we return `nothing`, indicating to the caller that
    # they should inline the file instead.
    if length(data) < ctx.settings.example_size_threshold
        return nothing
    end
    slug = dataslug(data)
    datafile = data_filename(dctx, slug, suffix)
    mkpath(dirname(datafile.path)) # generally, the directory for the HTML page will not exist yet
    write(datafile.path, data)
    # In all cases the file should be places in the same directory as the HTML file,
    # so we only need the filename to generate a valid relative href.
    return datafile.filename
end

function data_filename(dctx::DCtx, slug::AbstractString, suffix::AbstractString)
    ctx, navnode = dctx.ctx, dctx.navnode
    # We want to
    dir, pagename = splitdir(navnode.page)
    # Let's normalize the filename of the page by removing .md extensions (if present).
    # We'll keep other extensions though.
    if endswith(pagename, ".md")
        pagename = first(splitext(pagename))
    end

    filename_prefix = if ctx.settings.prettyurls
        # If pretty URLs are enabled, we would normally have
        # foo/bar.md -> foo/bar/index.html, and we then generate files
        # like foo/bar/$(slug).png
        # However, if we have foo/index.md, then it becomes foo/index.html,
        # and so we want to differentiate the data filenames just in case,
        # and so they become foo/index-$(slug).png
        if pagename == "index"
            string("index-", slug)
        else
            # We also need to update dir from foo/ to foo/bar here, since we want the
            # file to end up at foo/bar/$(slug).png
            dir = joinpath(dir, pagename)
            slug
        end
    else
        # If pretty URLs are disabled, then
        # foo/bar.md becomes foo/bar.html, and we always want to add the
        # Markdown filename to the data filename, i.e. foo/bar-$(slug).png
        string(pagename, "-", slug)
    end
    # Now we need to find a valid file name, in case there are existing duplicates.
    filename = find_valid_data_file(joinpath(ctx.doc.user.build, dir), filename_prefix, suffix)
    return (;
        filename,
        path = joinpath(ctx.doc.user.build, dir, filename),
    )
end

function find_valid_data_file(directory::AbstractString, prefix::AbstractString, suffix::AbstractString)
    # We'll try 10_000 different filename.. if this doesn't work, then something is probably really
    # badly wrong, and so we just crash.
    for i in 0:10_000
        filename = if i == 0
            string(prefix, suffix)
        else
            string(prefix, '-', lpad(string(i), 3, '0'), suffix)
        end
        ispath(joinpath(directory, filename)) || return filename
    end
    error("""
    Unable to find valid file name for an at-example output:
      directory = $(directory)
      prefix = $(prefix)
      suffix = $(suffix)""")
end

"""
Returns the first `limit` characters of the hex SHA1 of the data `bytes`.
"""
function dataslug(bytes::Union{Vector{UInt8},AbstractString}; limit=8)::String
    full_sha = bytes2hex(SHA.sha1(bytes))
    return first(full_sha, limit)
end

"""
Returns the full path of a [`Documenter.NavNode`](@ref) relative to `src/`.
"""
get_url(ctx, navnode::Documenter.NavNode) = get_url(ctx, navnode.page)

"""
If `prettyurls` for [`HTML`](@ref Documenter.HTML) is enabled, returns a "pretty" version of
the `path` which can then be used in links in the resulting HTML file.
"""
function pretty_url(ctx, path::AbstractString)
    if ctx.settings.prettyurls
        dir, file = splitdir(path)
        if file == "index.html"
            return length(dir) == 0 ? "" : "$(dir)/"
        end
    end
    return path
end

"""
If `canonical` for [`HTML`](@ref Documenter.HTML) is set, returns the canonical
URL of a `path` or [`Documenter.NavNode`](@ref), otherwise returns nothing.
"""
function canonical_url(ctx, path_or_navnode)
    canonical_link = ctx.settings.canonical
    if canonical_link === nothing
        return nothing
    else
        canonical_link_stripped = rstrip(canonical_link, '/')
        url = pretty_url(ctx, get_url(ctx, path_or_navnode))
        return "$canonical_link_stripped/$url"
    end
end

"""
Tries to guess the page title by looking at the `<h1>` headers and returns the
header contents of the first `<h1>` on a page (or `nothing` if the algorithm
was unable to find any `<h1>` headers).
"""
function pagetitle(page::Node)
    @assert page.element isa MarkdownAST.Document
    # function pagetitle(page::Documenter.Page)
    title = nothing
    for node in page.children
        # AnchoredHeaders should have just one child node, which is the Heading node
        if isa(node.element, Documenter.AnchoredHeader)
            node = first(node.children)
        end
        if isa(node.element, MarkdownAST.Heading) && node.element.level == 1
            title = collect(node.children)
            break
        end
    end
    title
end

function pagetitle(dctx::DCtx)
    ctx, navnode = dctx.ctx, dctx.navnode
    # function pagetitle(ctx, navnode::Documenter.NavNode)
    if navnode.title_override !== nothing
        # parse title_override as markdown
        md = Markdown.parse(navnode.title_override)
        # Markdown.parse results in a paragraph so we need to strip that
        if !(length(md.content) === 1 && isa(first(md.content), Markdown.Paragraph))
            error("Bad Markdown provided for page title: '$(navnode.title_override)'")
        end
        mdast = convert(Node, md)
        return collect(first(mdast.children).children)
    end

    if navnode.page !== nothing
        title = pagetitle(getpage(dctx).mdast)
        title === nothing || return title
    end

    [MarkdownAST.@ast("-")]
end

mdflatten_pagetitle(dctx::DCtx) = sprint((io, ns) -> foreach(n -> mdflatten(io, n), ns), pagetitle(dctx))

"""
Returns an ordered list of tuples, `(toplevel, anchor, text)`, corresponding to level 1 and 2
headings on the `page`. Note that if the first header on the `page` is a level 1 header then
it is not included -- it is assumed to be the page title and so does not need to be included
in the navigation menu twice.
"""
function collect_subsections(page::MarkdownAST.Node)
    @assert page.element isa MarkdownAST.Document
    # function collect_subsections(page::Documenter.Page)
    sections = []
    title_found = false
    for node in page.children
        @assert !isa(node.element, MarkdownAST.Heading) # all headings should have been replaced
        isa(node.element, Documenter.AnchoredHeader) || continue
        anchor = node.element.anchor
        node = first(node.children) # get the Heading node
        @assert isa(node.element, MarkdownAST.Heading)
        if node.element.level < 3
            toplevel = node.element.level === 1
            # Don't include the first header if it is `h1`.
            if toplevel && isempty(sections) && !title_found
                title_found = true
                continue
            end
            push!(sections, (toplevel, Documenter.anchor_fragment(anchor), node))
        end
    end
    return sections
end

function domify_ansicoloredtext(text::AbstractString, class = "")
    @tags pre
    stack = DOM.Node[pre()] # this `pre` is dummy
    function cb(io::IO, printer, tag::String, attrs::Dict{Symbol, String})
        text = String(take!(io))
        children = stack[end].nodes
        isempty(text) || push!(children, Tag(Symbol("#RAW#"))(text))
        if startswith(tag, "/")
            pop!(stack)
        else
            parent = Tag(Symbol(tag))[attrs]
            push!(children, parent)
            push!(stack, parent)
        end
        return true
    end
    ansiclass = isempty(class) ? "ansi" : class * " ansi"
    printer = ANSIColoredPrinters.HTMLPrinter(IOBuffer(text), callback = cb,
                                              root_tag = "code", root_class = ansiclass)
    show(IOBuffer(), MIME"text/html"(), printer)
    return stack[1].nodes
end

function domify(dctx::DCtx, node::Node, e::MarkdownAST.Text)
    ctx, navnode = dctx.ctx, dctx.navnode
    text = e.text
    # function mdconvert(text::AbstractString, parent; kwargs...)

    # Javascript LaTeX engines have a hard time dealing with `$` floating around
    # because they use them as in-line escapes. You can try a few different
    # solutions that don't work (e.g., HTML symbols &#x24;). The easiest (if
    # hacky) solution is to wrap dollar signs in a <span>. For now, only do this
    # when the text coming in is a singleton escaped $ sign.
    if text == "\$"
        return Tag(:span)("\$")
    end
    return DOM.Node(text)
end

domify(dctx::DCtx, node::Node, ::MarkdownAST.BlockQuote) = Tag(:blockquote)(domify(dctx, node.children))

domify(dctx::DCtx, node::Node, ::MarkdownAST.Strong) = Tag(:strong)(domify(dctx, node.children))

function domify(dctx::DCtx, node::Node, c::MarkdownAST.CodeBlock)
    ctx, navnode, settings = dctx.ctx, dctx.navnode, dctx.settings
    language = c.info
    # function mdconvert(c::Markdown.Code, parent::MDBlockContext; settings::Union{HTML,Nothing}=nothing, kwargs...)
    @tags pre code
    language = Documenter.codelang(language)
    if language == "documenter-ansi" # From @repl blocks (through MultiCodeBlock)
        return pre(domify_ansicoloredtext(c.code, "nohighlight hljs"))
    elseif settings !== nothing && settings.prerender &&
           !(isempty(language) || language == "nohighlight")
        r = hljs_prerender(c, settings)
        r !== nothing && return r
    end
    class = isempty(language) ? "nohighlight" : "language-$(language)"
    return pre(code[".$(class) .hljs"](c.code))
end

function domify(dctx::DCtx, node::Node, mcb::Documenter.MultiCodeBlock)
    ctx, navnode = dctx.ctx, dctx.navnode
    # function mdconvert(mcb::Documenter.MultiCodeBlock, parent::MDBlockContext; kwargs...)
    @tags pre br
    p = pre()
    for (i, thing) in enumerate(node.children)
        pre = domify(dctx, thing)
        code = pre.nodes[1]
        # TODO: This should probably be added to the CSS later on...
        push!(code.attributes, :style => "display:block;")
        push!(p.nodes, code)
        # insert a <br> between output and the next input
        if i != length(node.children) &&
            findnext(x -> x.element.info == mcb.language, collect(node.children), i + 1) == i + 1
            push!(p.nodes, br())
        end
    end
    return p
end

domify(dctx::DCtx, node::Node, c::MarkdownAST.Code) = Tag(:code)(c.code)

function hljs_prerender(c::MarkdownAST.CodeBlock, settings::HTML)
    @assert settings.prerender "unreachable"
    @tags pre code
    lang = Documenter.codelang(c.info)
    hljs = settings.highlightjs
    js = """
    const hljs = require('$(hljs)');
    console.log(hljs.highlight($(repr(c.code)), {'language': "$(lang)"}).value);
    """
    out, err = IOBuffer(), IOBuffer()
    try
        run(pipeline(`$(settings.node) -e "$(js)"`; stdout=out, stderr=err))
        str = String(take!(out))
        # prepend nohighlight to stop runtime highlighting
        # return pre(code[".nohighlight $(lang) .hljs"](Tag(Symbol("#RAW#"))(str)))
        return pre(code[".language-$(lang) .hljs"](Tag(Symbol("#RAW#"))(str)))
    catch e
        @error "HTMLWriter: prerendering failed" exception=e stderr=String(take!(err))
    end
    return nothing
end

function domify(dctx::DCtx, node::Node, h::MarkdownAST.Heading)
    N = h.level
    DOM.Tag(Symbol("h$N"))(domify(dctx, node.children))
end

domify(dctx::DCtx, node::Node, ::MarkdownAST.ThematicBreak) = Tag(:hr)()

const ImageElements = Union{MarkdownAST.Image, Documenter.LocalImage}
function domify(dctx::DCtx, node::Node, i::ImageElements)
    ctx, navnode = dctx.ctx, dctx.navnode
    alt = mdflatten(node.children)
    url = filehref(dctx, node, i)
    # function mdconvert(i::Markdown.Image, parent; kwargs...)
    # TODO: Implement .title
    @tags video img a

    if occursin(r"\.(webm|mp4|ogg|ogm|ogv|avi)$", url)
        video[:src => url, :controls => "true", :title => alt](
            a[:href => url](alt)
        )
    else
        img[:src => url, :alt => alt]
    end
end

domify(dctx::DCtx, node::Node, ::MarkdownAST.Emph) = Tag(:em)(domify(dctx, node.children))

domify(dctx::DCtx, node::Node, m::MarkdownAST.DisplayMath) = Tag(:p)[".math-container"](string("\\[", m.math, "\\]"))

domify(dctx::DCtx, node::Node, m::MarkdownAST.InlineMath) = Tag(:span)(string('$', m.math, '$'))

domify(dctx::DCtx, node::Node, m::MarkdownAST.LineBreak) = Tag(:br)()
# TODO: Implement SoftBreak, Backslash (but they don't appear in standard library Markdown conversions)

const LinkElements = Union{MarkdownAST.Link, Documenter.PageLink, Documenter.LocalLink}
function domify(dctx::DCtx, node::Node, link::LinkElements)
    droplinks = dctx.droplinks
    url = filehref(dctx, node, link)
    # function mdconvert(link::Markdown.Link, parent; droplinks=false, kwargs...)
    link_text = domify(dctx, node.children)
    droplinks ? link_text : Tag(:a)[:href => url](link_text)
end

function domify(dctx::DCtx, node::Node, list::MarkdownAST.List)
    isordered = (list.type === :ordered)
    (isordered ? Tag(:ol) : Tag(:ul))(map(Tag(:li), domify(dctx, node.children)))
end
domify(dctx::DCtx, node::Node, ::MarkdownAST.Item) = domify(dctx, node.children)

function domify(dctx::DCtx, node::Node, ::MarkdownAST.Paragraph)
    content = domify(dctx, node.children)
    # This 'if' here is to render tight/loose lists properly, as they all have Markdown.Paragraph as a child
    # node, but we should not render it for tight lists.
    # See also: https://github.com/JuliaLang/julia/pull/26598
    is_in_tight_list(node) ? content : Tag(:p)(content)
end
is_in_tight_list(node::Node) = !isnothing(node.parent) && isa(node.parent.element, MarkdownAST.Item) &&
    !isnothing(node.parent.parent) && isa(node.parent.parent.element, MarkdownAST.List) &&
    node.parent.parent.element.tight

function domify(dctx::DCtx, node::Node, t::MarkdownAST.Table)
    th_row, tbody_rows = Iterators.peel(MarkdownAST.tablerows(node))
    # function mdconvert(t::Markdown.Table, parent; kwargs...)
    @tags table tr th td
    alignment_style = map(t.spec) do align
        if align == :right
            "text-align: right"
        elseif align == :center
            "text-align: center"
        else
            "text-align: left"
        end
    end
    table(
        tr(map(enumerate(th_row.children)) do (i, x)
            th[:style => alignment_style[i]](domify(dctx, x.children))
        end),
        map(tbody_rows) do x
            tr(map(enumerate(x.children)) do (i, y) # each cell in a row
                td[:style => alignment_style[i]](domify(dctx, y.children))
            end)
        end
    )
end

function domify(dctx::DCtx, node::Node, e::MarkdownAST.JuliaValue)
    @warn("""
    Unexpected Julia interpolation in the Markdown. This probably means that you
    have an unbalanced or un-escaped \$ in the text.

    To write the dollar sign, escape it with `\\\$`

    We don't have the file or line number available, but we got given the value:

    `$(e.ref)` which is of type `$(typeof(e.ref))`
    """)
    return string(e.ref)
end

function domify(dctx::DCtx, node::Node, f::MarkdownAST.FootnoteLink)
    @tags sup a
    sup[".footnote-reference"](a["#citeref-$(f.id)", :href => "#footnote-$(f.id)"]("[$(f.id)]"))
end
function domify(dctx::DCtx, node::Node, f::MarkdownAST.FootnoteDefinition)
    # As we run through the document to generate the document, we won't render the footnote
    # definitions right away, and instead store them on dctx.footnotes. They get printed
    # a little later, at the very end of the page.
    #
    # It does mean that we call domify() again later on the actual footnote bodies, and in that
    # case dctx.footnotes = nothing. In case we then still end up here, it means we have footnote
    # definitions nested inside footnote definition. We just ignore those and print a warning.
    #
    # TODO: this could be rearranged such that we push!() the DOM here into .footnotes, rather
    # than the Node objects.
    if isnothing(dctx.footnotes)
        @error "Invalid nested footnote definition in $(Documenter.locrepr(dctx.navnode.page))" f.id
    else
        push!(dctx.footnotes, node)
    end
    return DOM.Node[]
end

function domify(dctx::DCtx, node::Node, a::MarkdownAST.Admonition)
    @tags header div details summary
    colorclass =
        (a.category == "danger")  ? ".is-danger"  :
        (a.category == "warning") ? ".is-warning" :
        (a.category == "note")    ? ".is-info"    :
        (a.category == "info")    ? ".is-info"    :
        (a.category == "tip")     ? ".is-success" :
        (a.category == "compat")  ? ".is-compat"  : begin
            # If the admonition category is not one of the standard ones, we tag the
            # admonition div element with a `is-category-$(category)` class. However, we
            # first carefully sanitize the category name. Strictly speaking, this is not
            # necessary when were using the Markdown parser in the Julia standard library,
            # since it restricts the category to [a-z]+. But it is possible for the users to
            # construct their own Admonition objects with arbitrary category strings and
            # pass them onto Documenter.
            #
            # (1) remove all characters except A-Z, a-z, 0-9 and -
            cat_sanitized = replace(a.category, r"[^A-Za-z0-9-]" => "")
            # (2) remove any dashes from the beginning and end of the string
            cat_sanitized = replace(cat_sanitized, r"^[-]+" => "")
            cat_sanitized = replace(cat_sanitized, r"[-]+$" => "")
            # (3) reduce any duplicate dashes in the middle to single dashes
            cat_sanitized = replace(cat_sanitized, r"[-]+" => "-")
            cat_sanitized = lowercase(cat_sanitized)
            # (4) if nothing is left (or the category was empty to begin with), we don't
            # apply a class
            isempty(cat_sanitized) ? "" : ".is-category-$(cat_sanitized)"
        end

    inner_div = div[".admonition-body"](domify(dctx, node.children))
    if a.category == "details"
        # details admonitions are rendered as <details><summary> blocks
        details[".admonition.is-details"](
            summary[".admonition-header"](a.title), inner_div
        )
    else
        div[".admonition$(colorclass)"](
            header[".admonition-header"](a.title), inner_div
        )
    end
end

# Select the "best" representation for HTML output.
domify(dctx::DCtx, node::Node, ::Documenter.MultiOutput) = domify(dctx, node.children)
domify(dctx::DCtx, node::Node, moe::Documenter.MultiOutputElement) = Base.invokelatest(domify, dctx, node, moe.element)

function domify(dctx::DCtx, node::Node, d::Dict{MIME,Any})
    rawhtml(code) = Tag(Symbol("#RAW#"))(code)
    # Our first preference for the MIME type is 'text/html', which we can natively include
    # in the HTML. But it might happen that it's too large (above example_size_threshold),
    # in which case we move on to trying to write it as an image.
    has_text_html = false
    if haskey(d, MIME"text/html"())
        if length(d[MIME"text/html"()]) < dctx.ctx.settings.example_size_threshold
            # If the size threshold is met, we can just return right away
            return rawhtml(d[MIME"text/html"()])
        end
        # We'll set has_text_html to distinguish it from the case where the 'text/html' MIME
        # show() method was simply missing.
        has_text_html = true
    end
    # If text/html failed, we try to write the output as an image, possibly to a file.
    image = if haskey(d, MIME"image/svg+xml"())
        @tags img
        svg = d[MIME"image/svg+xml"()]
        svg_tag_match = match(r"<svg[^>]*>", svg)
        dom = if length(svg) >= dctx.ctx.settings.example_size_threshold
            filename = write_data_file(dctx, svg; suffix=".svg")
            @assert !isnothing(filename)
            img[:src => filename, :alt => "Example block output"]
        elseif svg_tag_match === nothing
            # There is no svg tag so we don't do any more advanced
            # processing and just return the svg as HTML.
            # The svg string should be invalid but that's not our concern here.
            rawhtml(svg)
        else
            # The xmlns attribute has to be present for data:image/svg+xml
            # to work (https://stackoverflow.com/questions/18467982).
            # If it doesn't exist, we splice it into the first svg tag.
            # This should never invalidate otherwise valid svg.
            svg_tag = svg_tag_match.match
            xmlns_present = occursin("xmlns", svg_tag)
            if !xmlns_present
                svg = replace(svg, "<svg" => "<svg xmlns=\"http://www.w3.org/2000/svg\"", count = 1)
            end

            # We can leave the svg as utf8, but the minimum safety precaution we need
            # is to ensure the src string separator is not in the svg.
            # That can be either " or ', and the svg will most likely use only one of them
            # so we check which one occurs more often and use the other as the separator.
            # This should leave most svg basically intact.

            # Replace % with %25 and # with %23 https://github.com/jakubpawlowicz/clean-css/issues/763#issuecomment-215283553
            svg = replace(svg, "%" => "%25")
            svg = replace(svg, "#" => "%23")

            singles = count(==('\''), svg)
            doubles = count(==('"'), svg)
            if singles > doubles
                # Replace every " with %22 because it terminates the src=" string otherwise
                svg = replace(svg, "\"" => "%22")
                sep = "\""
            else
                # Replace every ' with %27 because it terminates the src=' string otherwise
                svg = replace(svg, "\'" => "%27")
                sep = "'"
            end

            rawhtml(string("<img src=", sep, "data:image/svg+xml;utf-8,", svg, sep, "/>"))
        end
        (; dom = dom, mime = "image/svg+xml")
    elseif haskey(d, MIME"image/png"())
        domify_show_image_binary(dctx, "png", d)
    elseif haskey(d, MIME"image/webp"())
        domify_show_image_binary(dctx, "webp", d)
    elseif haskey(d, MIME"image/gif"())
        domify_show_image_binary(dctx, "gif", d)
    elseif haskey(d, MIME"image/jpeg"())
        domify_show_image_binary(dctx, "jpeg", d)
    end
    # If image is nothing, then the object did not have any of the supported image
    # representations. In that case, if the 'text/html' representation exists, we use that,
    # but with a warning because it goes over the size limit. If 'text/html' was missing too,
    # we carry on to additional MIME types.
    if has_text_html && isnothing(image)
        # The 'text/html' representation of an @example block is above the threshold, but no
        # supported image representation is present as an alternative.
        push!(dctx.ctx.atexample_warnings, AtExampleFallbackWarning(
            page = dctx.navnode.page,
            size_bytes = length(d[MIME"text/html"()]),
            fallback = nothing,
        ))
        return rawhtml(d[MIME"text/html"()])
    elseif has_text_html && !isnothing(image)
        # The 'text/html' representation of an @example block is above the threshold,
        # falling back to '$(image.mime)' representation.
        push!(dctx.ctx.atexample_warnings, AtExampleFallbackWarning(
            page = dctx.navnode.page,
            size_bytes = length(d[MIME"text/html"()]),
            fallback = image.mime,
        ))
        return image.dom
    elseif !has_text_html && !isnothing(image)
        return image.dom
    end
    # Check for some 'fallback' MIMEs, defaulting to 'text/plain' if we can't find any of them.
    return if haskey(d, MIME"text/latex"())
        latex = d[MIME"text/latex"()]
        # If the show(io, ::MIME"text/latex", x) output is already wrapped in
        # \[ ... \] or $$ ... $$, we unwrap it first, since when we output
        # Markdown.LaTeX objects we put the correct delimiters around it anyway.
        has_math, latex = _strip_latex_math_delimiters(latex)
        out = if !has_math
            Documenter.mdparse(latex; mode = :single)
        else
            [MarkdownAST.@ast MarkdownAST.DisplayMath(latex)]
        end
        domify(dctx, out)
    elseif haskey(d, MIME"text/markdown"())
        out = Markdown.parse(d[MIME"text/markdown"()])
        out = convert(MarkdownAST.Node, out)
        domify(dctx, out)
    elseif haskey(d, MIME"text/plain"())
        @tags pre
        text = d[MIME"text/plain"()]
        pre[".documenter-example-output"](domify_ansicoloredtext(text, "nohighlight hljs"))
    else
        error("this should never happen.")
    end
end

function _strip_latex_math_delimiters(latex::AbstractString)
    # Make sure to match multiline strings!
    m_bracket = match(r"\s*\\\[(.*)\\\]\s*"s, latex)
    if m_bracket !== nothing
        return true, m_bracket[1]
    end
    # This regex matches the strings "$ ... $" and "$$ ... $$", but not
    # strings with miss-matched dollar signs such as "$ ... $$" or "$$ ... $"
    m_dollars = match(r"^\s*(\${1,2})([^\$]*)\1\s*$"s, latex)
    if m_dollars !== nothing
        return true, m_dollars[2]
    end
    return false, latex
end

function domify_show_image_binary(dctx::DCtx, filetype::AbstractString, d::Dict{MIME,Any})
    @tags img
    mime_name = "image/$filetype"
    mime = MIME{Symbol(mime_name)}()
    # When we construct `d` in the expander pipeline, we call `stringmime`, which
    # base64-encodes the bytes, so the values in the dictionary are base64-encoded.
    # So if we do write it to a file, we need to decode it first.
    data_base64 = d[mime]
    filename = write_data_file(dctx, Base64.base64decode(data_base64); suffix=".$filetype")
    alt = (:alt => "Example block output")
    dom = if isnothing(filename)
        src = string("data:$(mime_name);base64,", data_base64)
        img[:src => src, alt]
    else
        img[:src => filename, alt]
    end
    (; dom, mime = mime_name)
end

# filehrefs
# ------------------------------------------------------------------------------

# If the nodes passed through CrossReferences as native MarkdownAST elements, then that
# means they're reasonable absolute URLs. Or, possibly, the URL is problematic, but we
# just ignore that here. That should have been caught earlier.
filehref(dctx::DCtx, node::Node, e::Union{MarkdownAST.Image, MarkdownAST.Link}) = e.destination

function filehref(dctx::DCtx, node::Node, e::Documenter.PageLink)
    ctx, navnode = dctx.ctx, dctx.navnode
    path = Documenter.pagekey(ctx.doc, e.page)
    path = pretty_url(ctx, relhref(get_url(ctx, navnode), get_url(ctx, path)))
    # Add a fragment, if present
    return isempty(e.fragment) ? path : "$path#$(e.fragment)"
end

function filehref(dctx::DCtx, node::Node, e::Documenter.LocalLink)
    ctx, navnode = dctx.ctx, dctx.navnode
    path = relhref(get_url(ctx, navnode), e.path)
    # Replace any backslashes in links, if building the docs on Windows
    path = replace(path, '\\' => '/')
    # Add a fragment, if present
    return isempty(e.fragment) ? path : "$path#$(e.fragment)"
end

function filehref(dctx::DCtx, node::Node, e::Documenter.LocalImage)
    ctx, navnode = dctx.ctx, dctx.navnode
    path = relhref(get_url(ctx, navnode), e.path)
    # Replace any backslashes in links, if building the docs on Windows
    return replace(path, '\\' => '/')
end

end
