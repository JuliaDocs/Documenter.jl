"""
A module for rendering `Document` objects to HTML.

# Keywords

[`HTMLWriter`](@ref) uses the following additional keyword arguments that can be passed to
[`Documenter.makedocs`](@ref): `authors`, `pages`, `sitename`, `version`.
The behavior of [`HTMLWriter`](@ref) can be further customized by setting the `format`
keyword of [`Documenter.makedocs`](@ref) to a [`HTML`](@ref), which accepts the following
keyword arguments: `analytics`, `assets`, `canonical`, `disable_git`, `edit_branch` and
`prettyurls`.

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
import JSON

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Documenter,
    Utilities,
    Writers

import ...Utilities.DOM: DOM, Tag, @tags
using ...Utilities.MDFlatten

export HTML

"List of Documenter native themes."
const THEMES = ["documenter-light", "documenter-dark"]
"The root directory of the HTML assets."
const ASSETS = normpath(joinpath(@__DIR__, "..", "..", "assets", "html"))
"The directory where all the Sass/SCSS files needed for theme building are."
const ASSETS_SASS = joinpath(ASSETS, "scss")
"Directory for the compiled CSS files of the themes."
const ASSETS_THEMES = joinpath(ASSETS, "themes")

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

**`edit_branch`** specifies which branch, tag or commit the "Edit on GitHub" links
point to. It defaults to `master`. If it set to `nothing`, the current commit will be used.

**`canonical`** specifies the canonical URL for your documentation. We recommend
you set this to the base url of your stable documentation, e.g. `https://juliadocs.github.io/Documenter.jl/stable`.
This allows search engines to know which version to send their users to. [See
wikipedia for more information](https://en.wikipedia.org/wiki/Canonical_link_element).
Default is `nothing`, in which case no canonical link is set.

**`analytics`** can be used specify the Google Analytics tracking ID.

**`assets`** can be used to include additional assets (JS, CSS, ICO etc. files). See below
for more information.

**`sidebar_sitename`** determines whether the site name is shown in the sidebar or not.
Setting it to `false` can be useful when the logo already contains the name of the package.
Defaults to `true`.

# Default and custom assets

Documenter copies all files under the source directory (e.g. `/docs/src/`) over
to the compiled site. It also copies a set of default assets from `/assets/html/`
to the site's `assets/` directory, unless the user already had a file with the
same name, in which case the user's files overrides the Documenter's file.
This could, in principle, be used for customizing the site's style and scripting.

The HTML output also links certain custom assets to the generated HTML documents,
specifically a logo and additional javascript files.
The asset files that should be linked must be placed in `assets/`, under the source
directory (e.g `/docs/src/assets`) and must be on the top level (i.e. files in
the subdirectories of `assets/` are not linked).

For the **logo**, Documenter checks for the existence of `assets/logo.{svg,png,webp,gif,jpg,jpeg}`,
in this order. The first one it finds gets displayed at the top of the navigation sidebar.
It will also check for `assets/logo-dark.{svg,png,webp,gif,jpg,jpeg}` and use that for dark
themes.

Additional JS, ICO, and CSS assets can be included in the generated pages using the
`assets` keyword for `makedocs`. `assets` must be a `Vector{String}` and will include
each listed asset in the `<head>` of every page in the order in which they are listed.
The type of the asset (i.e. whether it is going to be included with a `<script>` or a
`<link>` tag) is determined by the file's extension -- either `.js`, `.ico`, or `.css`.
Adding an ICO asset is primarilly useful for setting a custom `favicon`.
"""
struct HTML <: Documenter.Writer
    prettyurls    :: Bool
    disable_git   :: Bool
    edit_branch   :: Union{String, Nothing}
    canonical     :: Union{String, Nothing}
    assets        :: Vector{String}
    analytics     :: String
    collapselevel :: Int
    sidebar_sitename :: Bool

    function HTML(;
            prettyurls    :: Bool = true,
            disable_git   :: Bool = false,
            edit_branch   :: Union{String, Nothing} = "master",
            canonical     :: Union{String, Nothing} = nothing,
            assets        :: Vector{String} = String[],
            analytics     :: String = "",
            collapselevel :: Integer = 2,
            sidebar_sitename :: Bool = true,
        )
        collapselevel >= 1 || thrown(ArgumentError("collapselevel must be >= 1"))
        new(prettyurls, disable_git, edit_branch, canonical, assets, analytics,
            collapselevel, sidebar_sitename)
    end
end

const requirejs_cdn = "https://cdnjs.cloudflare.com/ajax/libs/require.js/2.2.0/require.min.js"
const google_fonts = "https://fonts.googleapis.com/css?family=Lato|Roboto+Mono"
const fontawesome_css = [
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.8.2/css/fontawesome.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.8.2/css/solid.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.8.2/css/brands.min.css",
]
const highlightjs_css = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"
const katex_css = "https://cdn.jsdelivr.net/npm/katex@0.10.2/dist/katex.min.css"

struct SearchRecord
    src :: String
    page :: Documents.Page
    loc :: String
    category :: String
    title :: String
    page_title :: String
    text :: String
end

"""
[`HTMLWriter`](@ref)-specific globals that are passed to [`domify`](@ref) and
other recursive functions.
"""
mutable struct HTMLContext
    doc :: Documents.Document
    settings :: HTML
    scripts :: Vector{String}
    documenter_js :: String
    themeswap_js :: String
    search_js :: String
    search_index :: Vector{SearchRecord}
    search_index_js :: String
    search_navnode :: Documents.NavNode
    local_assets :: Vector{String}
    footnotes :: Vector{Markdown.Footnote}
end

HTMLContext(doc, settings=HTML()) = HTMLContext(doc, settings, [], "", "", "", [], "", Documents.NavNode("search", "Search", nothing), [], [])

function SearchRecord(ctx::HTMLContext, navnode; loc="", title=nothing, category="page", text="")
    page_title = mdflatten(pagetitle(ctx, navnode))
    if title === nothing
        title = page_title
    end
    SearchRecord(
        pretty_url(ctx, get_url(ctx, navnode.page)),
        getpage(ctx, navnode),
        loc,
        lowercase(category),
        title,
        page_title,
        text
    )
end

function SearchRecord(ctx::HTMLContext, navnode, node::Markdown.Header)
    a = getpage(ctx, navnode).mapping[node]
    SearchRecord(ctx, navnode;
        loc="$(a.id)-$(a.nth)",
        title=mdflatten(node),
        category="section")
end

function SearchRecord(ctx, navnode, node)
    SearchRecord(ctx, navnode; text=mdflatten(node))
end

function JSON.lower(rec::SearchRecord)
    # Replace any backslashes in links, if building the docs on Windows
    src = replace(rec.src, '\\' => '/')
    ref = string(src, '#', rec.loc)
    Dict{String, String}(
        "location" => ref,
        "page" => rec.page_title,
        "title" => rec.title,
        "category" => rec.category,
        "text" => rec.text
    )
end

"""
Returns a page (as a [`Documents.Page`](@ref) object) using the [`HTMLContext`](@ref).
"""
getpage(ctx, path) = ctx.doc.blueprint.pages[path]
getpage(ctx, navnode::Documents.NavNode) = getpage(ctx, navnode.page)


function render(doc::Documents.Document, settings::HTML=HTML())
    @info "HTMLWriter: rendering HTML pages."
    !isempty(doc.user.sitename) || error("HTML output requires `sitename`.")

    ctx = HTMLContext(doc, settings)
    ctx.search_index_js = "search_index.js"

    ctx.themeswap_js = copy_asset("themeswap.js", doc)
    ctx.documenter_js = copy_asset("documenter.js", doc)
    ctx.search_js = copy_asset("search.js", doc)

    for theme in THEMES
        copy_asset("themes/$(theme).css", doc)
    end
    append!(ctx.local_assets, settings.assets)

    for page in keys(doc.blueprint.pages)
        idx = findfirst(nn -> nn.page == page, doc.internal.navlist)
        nn = (idx === nothing) ? Documents.NavNode(page, nothing, nothing) : doc.internal.navlist[idx]
        @debug "Rendering $(page) [$(repr(idx))]"
        render_page(ctx, nn)
    end

    render_search(ctx)

    open(joinpath(doc.user.build, ctx.search_index_js), "w") do io
        println(io, "var documenterSearchIndex = {\"docs\":")
        # convert Vector{SearchRecord} to a JSON string, and escape two Unicode
        # characters since JSON is not a JS subset, and we want JS here
        # ref http://timelessrepo.com/json-isnt-a-javascript-subset
        escapes = ('\u2028' => "\\u2028", '\u2029' => "\\u2029")
        js = reduce(replace, escapes, init=JSON.json(ctx.search_index))
        println(io, js, "\n}")
    end
end

"""
Copies an asset from Documenters `assets/html/` directory to `doc.user.build`.
Returns the path of the copied asset relative to `.build`.
"""
function copy_asset(file, doc)
    src = joinpath(Utilities.assetsdir(), "html", file)
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
        cp(src, dst, force=true)
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
    page = getpage(ctx, navnode)
    head = render_head(ctx, navnode)
    sidebar = render_sidebar(ctx, navnode)
    navbar = render_navbar(ctx, navnode, true)
    article = render_article(ctx, navnode)
    footer = render_footer(ctx, navnode)
    htmldoc = render_html(ctx, navnode, head, sidebar, navbar, article, footer)
    open_output(ctx, navnode) do io
        print(io, htmldoc)
    end
end

## Search page
function render_search(ctx)
    @tags article body h1 header hr html li nav p span ul script

    src = get_url(ctx, ctx.search_navnode)

    head = render_head(ctx, ctx.search_navnode)
    sidebar = render_sidebar(ctx, ctx.search_navnode)
    navbar = render_navbar(ctx, ctx.search_navnode, false)
    article = article(
        p["#documenter-search-info"]("Loading search..."),
        ul["#documenter-search-results"]
    )
    footer = render_footer(ctx, ctx.search_navnode)
    scripts = [
        script[:src => relhref(src, ctx.search_index_js)],
        script[:src => relhref(src, ctx.search_js)],
    ]
    htmldoc = render_html(ctx, ctx.search_navnode, head, sidebar, navbar, article, footer, scripts)
    open_output(ctx, ctx.search_navnode) do io
        print(io, htmldoc)
    end
end

## Rendering HTML elements
# ------------------------------------------------------------------------------

"""
Renders the main `<html>` tag.
"""
function render_html(ctx, navnode, head, sidebar, navbar, article, footer, scripts::Vector{DOM.Node}=DOM.Node[])
    @tags html body div
    DOM.HTMLDocument(
        html[:lang=>"en"](
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
            select["#documenter-themepicker"](option[:value=>theme](theme) for theme in THEMES)
        )
    )

    now_full, now_short = Dates.format(now(), dateformat"E d U Y HH:MM"), Dates.format(now(), dateformat"E d U Y")
    buildinfo = p(
        "This document was generated with ",
        a[:href => "https://github.com/JuliaDocs/Documenter.jl"]("Documenter.jl"),
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

    page_title = "$(mdflatten(pagetitle(ctx, navnode))) · $(ctx.doc.user.sitename)"
    css_links = [
        google_fonts,
        fontawesome_css...,
        highlightjs_css,
        katex_css,
    ]
    head(
        meta[:charset=>"UTF-8"],
        meta[:name => "viewport", :content => "width=device-width, initial-scale=1.0"],
        title(page_title),

        analytics_script(ctx.settings.analytics),

        canonical_link_element(ctx.settings.canonical, src),

        # Stylesheets.
        map(css_links) do each
            link[:href => each, :rel => "stylesheet", :type => "text/css"]
        end,

        script("documenterBaseURL=\"$(relhref(src, "."))\""),
        script[
            :src => requirejs_cdn,
            Symbol("data-main") => relhref(src, ctx.documenter_js)
        ],

        script[:src => relhref(src, "siteinfo.js")],
        script[:src => relhref(src, "../versions.js")],

        # Custom user-provided assets.
        asset_links(src, ctx.local_assets),
        # Themes. Note: we reverse the make sure that the default theme (first in the array)
        # comes as the last <link> tag.
        map(Iterators.reverse(enumerate(THEMES))) do (i, theme)
            e = link[".docs-theme-link",
                :rel => "stylesheet", :type => "text/css",
                :href => relhref(src, "assets/themes/$(theme).css"),
                Symbol("data-theme-name") => theme,
            ]
            (i == 1) && push!(e.attributes, Symbol("data-theme-primary") => "")
            return e
        end,
        script[:src => relhref(src, ctx.themeswap_js)],
    )
end

function asset_links(src::AbstractString, assets::Vector)
    @tags link script
    links = DOM.Node[]
    for each in assets
        ext = splitext(each)[end]
        url = relhref(src, each)
        node =
            ext == ".ico" ? link[:href  => url, :rel => "icon", :type => "image/x-icon"] :
            ext == ".css" ? link[:href  => url, :rel => "stylesheet", :type => "text/css"] :
            ext == ".js"  ? script[:src => url] : continue # Skip non-js/css files.
        push!(links, node)
    end
    return links
end

analytics_script(tracking_id::AbstractString) =
    isempty(tracking_id) ? Tag(Symbol("#RAW#"))("") : Tag(:script)(
        """
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

        ga('create', '$(tracking_id)', 'auto');
        ga('send', 'pageview');
        """
    )

function canonical_link_element(canonical_link, src)
   @tags link
   if canonical_link === nothing
      return Tag(Symbol("#RAW#"))("")
   else
      canonical_link_stripped = rstrip(canonical_link, '/')
      href = "$canonical_link_stripped/$src"
      return link[:rel => "canonical", :href => href]
   end
end

# Navigation menu
# ------------------------------------------------------------------------------

struct NavMenuContext
    htmlctx :: HTMLContext
    current :: Documents.NavNode
    idstack :: Vector{Int}
end
NavMenuContext(ctx::HTMLContext, current::Documents.NavNode) = NavMenuContext(ctx, current, [])

function render_sidebar(ctx, navnode)
    @tags a form img input nav div select option span
    src = get_url(ctx, navnode)
    navmenu = nav[".docs-sidebar"]

    # Logo
    logo = find_image_asset(ctx, "logo")
    logo_dark = find_image_asset(ctx, "logo-dark")
    if logo !== nothing
        # the logo will point to the first page in the navigation menu
        href = navhref(ctx, first(ctx.doc.internal.navlist), navnode)
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
            span[".docs-autofit"](ctx.doc.user.sitename)
        ))
    end

    # Search box
    push!(navmenu.nodes,
        form[".docs-search", :action => navhref(ctx, ctx.search_navnode, navnode)](
            input[
                "#documenter-search-query.docs-search-query",
                :name => "q",
                :type => "text",
                :placeholder => "Search docs",
            ],
        )
    )

    # The menu itself
    menu = navitem(NavMenuContext(ctx, navnode, ))
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
function navitem(nctx, nn::Documents.NavNode)
    @tags ul li span a input label i
    ctx, current = nctx.htmlctx, nctx.current
    # We'll do the children first, primarily to determine if this node has any that are
    # visible. If it does not and it itself is not visible (including current), then
    # we'll hide this one as well, returning an empty string Node.
    children = navitem(nctx, nn.children)
    if nn !== current && !nn.visible && children.name === DOM.TEXT
        return DOM.Node("")
    end

    # construct this item
    title = mdconvert(pagetitle(ctx, nn); droplinks=true)
    currentclass = (nn === current) ? ".is-active" : ""
    item = if length(nctx.idstack) >= ctx.settings.collapselevel && children.name !== DOM.TEXT
        menuid = "menuitem-$(join(nctx.idstack, '-'))"
        input_attr = ["#$(menuid).collapse-toggle", :type => "checkbox"]
        nn in Documents.navpath(nctx.current) && push!(input_attr, :checked)
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
        subs = collect_subsections(ctx.doc.blueprint.pages[current.page])
        internal_links = map(subs) do s
            istoplevel, anchor, text = s
            _li = istoplevel ? li[".toplevel"] : li[]
            _li(a[".tocitem", :href => anchor](span(mdconvert(text; droplinks=true))))
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

    # The breadcrumb (navigation links on top)
    navpath = Documents.navpath(navnode)
    header_links = map(navpath) do nn
        title = mdconvert(pagetitle(ctx, nn); droplinks=true)
        nn.page === nothing ? li(a[".is-disabled"](title)) : li(a[:href => navhref(ctx, nn, navnode)](title))
    end
    header_links[end] = header_links[end][".is-active"]
    breadcrumb = nav[".breadcrumb"](
        ul[".is-hidden-mobile"](header_links),
        ul[".is-hidden-tablet"](header_links[end]) # when on mobile, we only show the page title, basically
    )

    # The "Edit on GitHub" links and the hamburger to open the sidebar (on mobile) float right
    navbar_right = div[".docs-right"]

    # Set the logo and name for the "Edit on.." button.
    if edit_page_link && !ctx.settings.disable_git
        host_type = Utilities.repo_host_from_url(ctx.doc.user.repo)
        if host_type == Utilities.RepoGitlab
            host = "GitLab"
            logo = "\uf296"
        elseif host_type == Utilities.RepoGithub
            host = "GitHub"
            logo = "\uf09b"
        elseif host_type == Utilities.RepoBitbucket
            host = "BitBucket"
            logo = "\uf171"
        else
            host = ""
            logo = "\uf15c"
        end
        hoststring = isempty(host) ? " source" : " on $(host)"

        pageurl = get(getpage(ctx, navnode).globals.meta, :EditURL, getpage(ctx, navnode).source)
        url = if Utilities.isabsurl(pageurl)
            pageurl
        else
            if !(pageurl == getpage(ctx, navnode).source)
                # need to set users path relative the page itself
                pageurl = joinpath(first(splitdir(getpage(ctx, navnode).source)), pageurl)
            end
            Utilities.url(ctx.doc.user.repo, pageurl, commit=ctx.settings.edit_branch)
        end
        if url !== nothing
            edit_verb = (ctx.settings.edit_branch === nothing) ? "View" : "Edit"
            title = "$(edit_verb)$hoststring"
            push!(navbar_right.nodes,
                a[".docs-edit-link", :href => url, :title => title](
                    span[".docs-icon.fab"](logo),
                    span[".docs-label.is-hidden-touch"](title)
                )
            )
        end
    end

    # Settings cog
    push!(navbar_right.nodes, a[
        "#documenter-settings-button.docs-settings-button.fas.fa-cog",
        :href => "#", :title => "Settings",
    ])

    # Hamburger on mobile
    push!(navbar_right.nodes, a[
        "#documenter-sidebar-button.docs-sidebar-button.fa.fa-bars.is-hidden-desktop",
        :href => "#"
    ])

    # Construct the main <header> node that should be the first element in div.docs-main
    header[".docs-navbar"](breadcrumb, navbar_right)
end

function render_footer(ctx, navnode)
    @tags a div nav
    # Navigation links (previous/next page), if there are any
    navlinks = DOM.Node[]
    if navnode.prev !== nothing
        title = mdconvert(pagetitle(ctx, navnode.prev); droplinks=true)
        link = a[".docs-footer-prevpage", :href => navhref(ctx, navnode.prev, navnode)]("« ", title)
        push!(navlinks, link)
    end
    if navnode.next !== nothing
        title = mdconvert(pagetitle(ctx, navnode.next); droplinks=true)
        link = a[".docs-footer-nextpage", :href => navhref(ctx, navnode.next, navnode)](title, " »")
        push!(navlinks, link)
    end
    return isempty(navlinks) ? "" : nav[".docs-footer"](navlinks)
end

# Article (page contents)
# ------------------------------------------------------------------------------

function render_article(ctx, navnode)
    @tags article section ul li hr span a div p

    # Build the page itself (and collect any footnotes)
    empty!(ctx.footnotes)
    art_body = article["#documenter-page.content"](domify(ctx, navnode))
    # Footnotes, if there are any
    if !isempty(ctx.footnotes)
        fnotes = map(ctx.footnotes) do f
            fid = "footnote-$(f.id)"
            citerefid = "citeref-$(f.id)"
            if length(f.text) == 1 && first(f.text) isa Markdown.Paragraph
                li["#$(fid).footnote"](
                    a[".tag.is-link", :href => "#$(citerefid)"](f.id),
                    mdconvert(f.text[1].content),
                )
            else
                li["#$(fid).footnote"](
                    a[".tag.is-link", :href => "#$(citerefid)"](f.id),
                    mdconvert(f.text),
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
function generate_version_file(versionfile::AbstractString, entries)
    open(versionfile, "w") do buf
        println(buf, "var DOC_VERSIONS = [")
        for folder in entries
            println(buf, "  \"", folder, "\",")
        end
        println(buf, "];")
    end
end

function generate_siteinfo_file(dir::AbstractString, version::AbstractString)
    open(joinpath(dir, "siteinfo.js"), "w") do buf
        println(buf, "var DOCUMENTER_CURRENT_VERSION = \"$(version)\";")
    end
end

## domify(...)
# ------------

"""
Converts recursively a [`Documents.Page`](@ref), `Markdown` or Documenter
`*Node` objects into HTML DOM.
"""
function domify(ctx, navnode)
    page = getpage(ctx, navnode)
    map(page.elements) do elem
        rec = SearchRecord(ctx, navnode, elem)
        push!(ctx.search_index, rec)
        domify(ctx, navnode, page.mapping[elem])
    end
end

function domify(ctx, navnode, node)
    fixlinks!(ctx, navnode, node)
    mdconvert(node, Markdown.MD(); footnotes=ctx.footnotes)
end

function domify(ctx, navnode, anchor::Anchors.Anchor)
    @tags a
    aid = "$(anchor.id)-$(anchor.nth)"
    if isa(anchor.object, Markdown.Header)
        h = anchor.object
        fixlinks!(ctx, navnode, h)
        DOM.Tag(Symbol("h$(Utilities.header_level(h))"))[:id => aid](
            mdconvert(h.text, h),
            a[".docs-heading-anchor", :href => "#$aid", :title => "Permalink"]
        )
    else
        a[".nav-anchor", :id => aid, :href => "#$aid"](domify(ctx, navnode, anchor.object))
    end
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
    ul(map(e -> isa(e, ListBuilder) ? domify(e) : li(e), lb.es))
end

function domify(ctx, navnode, contents::Documents.ContentsNode)
    @tags a
    navnode_dir = dirname(navnode.page)
    navnode_url = get_url(ctx, navnode)
    lb = ListBuilder()
    for (count, path, anchor) in contents.elements
        path = joinpath(navnode_dir, path) # links in ContentsNodes are relative to current page
        path = pretty_url(ctx, relhref(navnode_url, get_url(ctx, path)))
        header = anchor.object
        url = string(path, '#', anchor.id, '-', anchor.nth)
        node = a[:href=>url](mdconvert(header.text; droplinks=true))
        level = Utilities.header_level(header)
        push!(lb, level, node)
    end
    domify(lb)
end

function domify(ctx, navnode, index::Documents.IndexNode)
    @tags a code li ul
    navnode_dir = dirname(navnode.page)
    navnode_url = get_url(ctx, navnode)
    lis = map(index.elements) do el
        object, doc, path, mod, cat = el
        path = joinpath(navnode_dir, path) # links in IndexNodes are relative to current page
        path = pretty_url(ctx, relhref(navnode_url, get_url(ctx, path)))
        url = string(path, "#", Utilities.slugify(object))
        li(a[:href=>url](code("$(object.binding)")))
    end
    ul(lis)
end

function domify(ctx, navnode, docs::Documents.DocsNodes)
    [domify(ctx, navnode, node) for node in docs.nodes]
end

function domify(ctx, navnode, node::Documents.DocsNode)
    @tags a code article header span

    # push to search index
    rec = SearchRecord(ctx, navnode;
        loc=node.anchor.id,
        title=string(node.object.binding),
        category=Utilities.doccat(node.object),
        text = mdflatten(node.docstr))

    push!(ctx.search_index, rec)

    article[".docstring"](
        header(
            a[".docstring-binding", :id=>node.anchor.id, :href=>"#$(node.anchor.id)"](code("$(node.object.binding)")),
            " — ", # &mdash;
            span[".docstring-category"]("$(Utilities.doccat(node.object))"),
            "."
        ),
        domify_doc(ctx, navnode, node.docstr)
    )
end

function domify_doc(ctx, navnode, md::Markdown.MD)
    @tags a section footer div
    if haskey(md.meta, :results)
        # The `:results` field contains a vector of `Docs.DocStr` objects associated with
        # each markdown object. The `DocStr` contains data such as file and line info that
        # we need for generating correct source links.
        map(zip(md.content, md.meta[:results])) do md
            markdown, result = md
            ret = section(div(domify(ctx, navnode, Writers.MarkdownWriter.dropheaders(markdown))))
            # When a source link is available then print the link.
            if !ctx.settings.disable_git
                url = Utilities.url(ctx.doc.internal.remote, ctx.doc.user.repo, result)
                if url !== nothing
                    push!(ret.nodes, a[".docs-sourcelink", :target=>"_blank", :href=>url]("source"))
                end
            end
            return ret
        end
    else
        # Docstrings with no `:results` metadata won't contain source locations so we don't
        # try to print them out. Just print the basic docstring.
        section(domify(ctx, navnode, Writers.MarkdownWriter.dropheaders(md)))
    end
end

function domify(ctx, navnode, node::Documents.EvalNode)
    node.result === nothing ? DOM.Node[] : domify(ctx, navnode, node.result)
end

# nothing to show for MetaNodes, so we just return an empty list
domify(ctx, navnode, node::Documents.MetaNode) = DOM.Node[]

function domify(ctx, navnode, raw::Documents.RawNode)
    raw.name === :html ? Tag(Symbol("#RAW#"))(raw.text) : DOM.Node[]
end


# Utilities
# ------------------------------------------------------------------------------

"""
Opens the output file of the `navnode` in write node. If necessary, the path to the output
file is created before opening the file.
"""
function open_output(f, ctx, navnode)
    path = joinpath(ctx.doc.user.build, get_url(ctx, navnode))
    isdir(dirname(path)) || mkpath(dirname(path))
    open(f, path, "w")
end

"""
Get the relative hyperlink between two [`Documents.NavNode`](@ref)s. Assumes that both
[`Documents.NavNode`](@ref)s have an associated [`Documents.Page`](@ref) (i.e. `.page`
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
Returns the full path of a [`Documents.NavNode`](@ref) relative to `src/`.
"""
get_url(ctx, navnode::Documents.NavNode) = get_url(ctx, navnode.page)

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
Tries to guess the page title by looking at the `<h1>` headers and returns the
header contents of the first `<h1>` on a page (or `nothing` if the algorithm
was unable to find any `<h1>` headers).
"""
function pagetitle(page::Documents.Page)
    title = nothing
    for element in page.elements
        if isa(element, Markdown.Header{1})
            title = element.text
            break
        end
    end
    title
end

function pagetitle(ctx, navnode::Documents.NavNode)
    if navnode.title_override !== nothing
        # parse title_override as markdown
        md = Markdown.parse(navnode.title_override)
        # Markdown.parse results in a paragraph so we need to strip that
        if !(length(md.content) === 1 && isa(first(md.content), Markdown.Paragraph))
            error("Bad Markdown provided for page title: '$(navnode.title_override)'")
        end
        return first(md.content).content
    end

    if navnode.page !== nothing
        title = pagetitle(getpage(ctx, navnode))
        title === nothing || return title
    end

    "-"
end

"""
Returns an ordered list of tuples, `(toplevel, anchor, text)`, corresponding to level 1 and 2
headings on the `page`. Note that if the first header on the `page` is a level 1 header then
it is not included -- it is assumed to be the page title and so does not need to be included
in the navigation menu twice.
"""
function collect_subsections(page::Documents.Page)
    sections = []
    title_found = false
    for element in page.elements
        if isa(element, Markdown.Header) && Utilities.header_level(element) < 3
            toplevel = Utilities.header_level(element) === 1
            # Don't include the first header if it is `h1`.
            if toplevel && isempty(sections) && !title_found
                title_found = true
                continue
            end
            anchor = page.mapping[element]
            push!(sections, (toplevel, "#$(anchor.id)-$(anchor.nth)", element.text))
        end
    end
    return sections
end


# mdconvert
# ------------------------------------------------------------------------------

const md_block_nodes = [
    Markdown.MD,
    Markdown.BlockQuote,
    Markdown.List,
    Markdown.Admonition,
]

"""
[`MDBlockContext`](@ref) is a union of all the Markdown nodes whose children should
be blocks. It can be used to dispatch on all the block-context nodes at once.
"""
const MDBlockContext = Union{md_block_nodes...}

"""
Convert a markdown object to a `DOM.Node` object.

The `parent` argument is passed to allow for context-dependant conversions.
"""
mdconvert(md; kwargs...) = mdconvert(md, md; kwargs...)

mdconvert(text::AbstractString, parent; kwargs...) = DOM.Node(text)

mdconvert(vec::Vector, parent; kwargs...) = [mdconvert(x, parent; kwargs...) for x in vec]

mdconvert(md::Markdown.MD, parent; kwargs...) = mdconvert(md.content, md; kwargs...)

mdconvert(b::Markdown.BlockQuote, parent; kwargs...) = Tag(:blockquote)(mdconvert(b.content, b; kwargs...))

mdconvert(b::Markdown.Bold, parent; kwargs...) = Tag(:strong)(mdconvert(b.text, parent; kwargs...))

function mdconvert(c::Markdown.Code, parent::MDBlockContext; kwargs...)
    @tags pre code
    language = isempty(c.language) ? "none" : c.language
    pre(code[".language-$(language)"](c.code))
end
mdconvert(c::Markdown.Code, parent; kwargs...) = Tag(:code)(c.code)

mdconvert(h::Markdown.Header{N}, parent; kwargs...) where {N} = DOM.Tag(Symbol("h$N"))(mdconvert(h.text, h; kwargs...))

mdconvert(::Markdown.HorizontalRule, parent; kwargs...) = Tag(:hr)()

function mdconvert(i::Markdown.Image, parent; kwargs...)
    @tags video img a

    if occursin(r"\.(webm|mp4|ogg|ogm|ogv|avi)$", i.url)
        video[:src => i.url, :controls => "true", :title => i.alt](
            a[:href => i.url](i.alt)
        )
    else
        img[:src => i.url, :alt => i.alt]
    end
end

mdconvert(i::Markdown.Italic, parent; kwargs...) = Tag(:em)(mdconvert(i.text, i; kwargs...))

mdconvert(m::Markdown.LaTeX, ::MDBlockContext; kwargs...)   = Tag(:div)(string("\\[", m.formula, "\\]"))
mdconvert(m::Markdown.LaTeX, parent; kwargs...) = Tag(:span)(string('$', m.formula, '$'))

mdconvert(::Markdown.LineBreak, parent; kwargs...) = Tag(:br)()

function mdconvert(link::Markdown.Link, parent; droplinks=false, kwargs...)
    link_text = mdconvert(link.text, link; droplinks=droplinks, kwargs...)
    droplinks ? link_text : Tag(:a)[:href => link.url](link_text)
end

mdconvert(list::Markdown.List, parent; kwargs...) = (Markdown.isordered(list) ? Tag(:ol) : Tag(:ul))(map(Tag(:li), mdconvert(list.items, list; kwargs...)))

mdconvert(paragraph::Markdown.Paragraph, parent; kwargs...) = Tag(:p)(mdconvert(paragraph.content, paragraph; kwargs...))

# For compatibility with versions before Markdown.List got the `loose field, Julia PR #26598
const list_has_loose_field = :loose in fieldnames(Markdown.List)
function mdconvert(paragraph::Markdown.Paragraph, parent::Markdown.List; kwargs...)
    content = mdconvert(paragraph.content, paragraph; kwargs...)
    return (list_has_loose_field && !parent.loose) ? content : Tag(:p)(content)
end

function mdconvert(t::Markdown.Table, parent; kwargs...)
    @tags table tr th td
    alignment_style = map(t.align) do align
        if align == :r
            "text-align: right"
        elseif align == :c
            "text-align: center"
        else
            "text-align: left"
        end
    end
    table(
        tr(map(enumerate(t.rows[1])) do (i, x)
            th[:style => alignment_style[i]](mdconvert(x, t; kwargs...))
        end),
        map(t.rows[2:end]) do x
            tr(map(enumerate(x)) do (i, y) # each cell in a row
                td[:style => alignment_style[i]](mdconvert(y, x; kwargs...))
            end)
        end
    )
end

mdconvert(expr::Union{Expr,Symbol}, parent; kwargs...) = string(expr)

function mdconvert(f::Markdown.Footnote, parent; footnotes = nothing, kwargs...)
    @tags sup a
    if f.text === nothing # => Footnote link
        return sup[".footnote-reference"](a["#citeref-$(f.id)", :href => "#footnote-$(f.id)"]("[$(f.id)]"))
    elseif footnotes !== nothing # Footnote definition
        push!(footnotes, f)
    else # => Footnote definition, but nowhere to put it
        @error "Bad footnote definition."
    end
    return []
end

function mdconvert(a::Markdown.Admonition, parent; kwargs...)
    @tags header div
    colorclass =
        (a.category == "danger")  ? "is-danger"  :
        (a.category == "warning") ? "is-warning" :
        (a.category == "note")    ? "is-info"    :
        (a.category == "info")    ? "is-info"    :
        (a.category == "tip")     ? "is-success" :
        (a.category == "compat")  ? "is-compat"  : ""
    div[".admonition.$(colorclass)"](
        header[".admonition-header"](a.title),
        div[".admonition-body"](mdconvert(a.content, a; kwargs...))
    )
end

mdconvert(html::Documents.RawHTML, parent; kwargs...) = Tag(Symbol("#RAW#"))(html.code)

# Select the "best" representation for HTML output.
mdconvert(mo::Documents.MultiOutput, parent; kwargs...) =
    Base.invokelatest(mdconvert, mo.content, parent; kwargs...)
function mdconvert(d::Dict{MIME,Any}, parent; kwargs...)
    if haskey(d, MIME"text/html"())
        out = Documents.RawHTML(d[MIME"text/html"()])
    elseif haskey(d, MIME"image/svg+xml"())
        out = Documents.RawHTML(d[MIME"image/svg+xml"()])
    elseif haskey(d, MIME"image/png"())
        out = Documents.RawHTML(string("<img src=\"data:image/png;base64,", d[MIME"image/png"()], "\" />"))
    elseif haskey(d, MIME"image/webp"())
        out = Documents.RawHTML(string("<img src=\"data:image/webp;base64,", d[MIME"image/webp"()], "\" />"))
    elseif haskey(d, MIME"image/gif"())
        out = Documents.RawHTML(string("<img src=\"data:image/gif;base64,", d[MIME"image/gif"()], "\" />"))
    elseif haskey(d, MIME"image/jpeg"())
        out = Documents.RawHTML(string("<img src=\"data:image/jpeg;base64,", d[MIME"image/jpeg"()], "\" />"))
    elseif haskey(d, MIME"text/latex"())
        out = Utilities.mdparse(d[MIME"text/latex"()]; mode = :single)
    elseif haskey(d, MIME"text/markdown"())
        out = Markdown.parse(d[MIME"text/markdown"()])
    elseif haskey(d, MIME"text/plain"())
        out = Markdown.Code(d[MIME"text/plain"()])
    else
        error("this should never happen.")
    end
    return mdconvert(out, parent; kwargs...)
end

# Fallback
function mdconvert(x, parent; kwargs...)
    @debug "Strange inline Markdown node (typeof(x) = $(typeof(x))), falling back to repr()" x
    repr(x)
end

# fixlinks!
# ------------------------------------------------------------------------------

"""
Replaces URLs in `Markdown.Link` elements (if they point to a local `.md` page) with the
actual URLs.
"""
function fixlinks!(ctx, navnode, link::Markdown.Link)
    fixlinks!(ctx, navnode, link.text)
    Utilities.isabsurl(link.url) && return

    # links starting with a # are references within the same file -- there's nothing to fix
    # for such links
    startswith(link.url, '#') && return

    s = split(link.url, "#", limit = 2)
    if Sys.iswindows() && ':' in first(s)
        @warn "invalid local link: colons not allowed in paths on Windows in $(Utilities.locrepr(navnode.page))" link = link.url
        return
    end
    path = normpath(joinpath(dirname(navnode.page), first(s)))

    if endswith(path, ".md") && path in keys(ctx.doc.blueprint.pages)
        # make sure that links to different valid pages are correct
        path = pretty_url(ctx, relhref(get_url(ctx, navnode), get_url(ctx, path)))
    elseif isfile(joinpath(ctx.doc.user.build, path))
        # update links to other files that are present in build/ (e.g. either user
        # provided files or generated by code examples)
        path = relhref(get_url(ctx, navnode), path)
    else
        @warn "invalid local link: unresolved path in $(Utilities.locrepr(navnode.page))" link = link.url
    end

    # Replace any backslashes in links, if building the docs on Windows
    path = replace(path, '\\' => '/')
    link.url = (length(s) > 1) ? "$path#$(last(s))" : String(path)
end

function fixlinks!(ctx, navnode, img::Markdown.Image)
    Utilities.isabsurl(img.url) && return

    if Sys.iswindows() && ':' in img.url
        @warn "invalid local image: colons not allowed in paths on Windows in $(Utilities.locrepr(navnode.page))" link = img.url
        return
    end

    path = joinpath(dirname(navnode.page), img.url)
    if isfile(joinpath(ctx.doc.user.build, path))
        path = relhref(get_url(ctx, navnode), path)
        # Replace any backslashes in links, if building the docs on Windows
        img.url = replace(path, '\\' => '/')
    else
        @warn "invalid local image: unresolved path in $(Utilities.locrepr(navnode.page))" link = img.url
    end
end

fixlinks!(ctx, navnode, md::Markdown.MD) = fixlinks!(ctx, navnode, md.content)
function fixlinks!(ctx, navnode, a::Markdown.Admonition)
    fixlinks!(ctx, navnode, a.title)
    fixlinks!(ctx, navnode, a.content)
end
fixlinks!(ctx, navnode, b::Markdown.BlockQuote) = fixlinks!(ctx, navnode, b.content)
fixlinks!(ctx, navnode, b::Markdown.Bold) = fixlinks!(ctx, navnode, b.text)
fixlinks!(ctx, navnode, f::Markdown.Footnote) = fixlinks!(ctx, navnode, f.text)
fixlinks!(ctx, navnode, h::Markdown.Header) = fixlinks!(ctx, navnode, h.text)
fixlinks!(ctx, navnode, i::Markdown.Italic) = fixlinks!(ctx, navnode, i.text)
fixlinks!(ctx, navnode, list::Markdown.List) = fixlinks!(ctx, navnode, list.items)
fixlinks!(ctx, navnode, p::Markdown.Paragraph) = fixlinks!(ctx, navnode, p.content)
fixlinks!(ctx, navnode, t::Markdown.Table) = fixlinks!(ctx, navnode, t.rows)

fixlinks!(ctx, navnode, mds::Vector) = map(md -> fixlinks!(ctx, navnode, md), mds)
fixlinks!(ctx, navnode, md) = nothing

# TODO: do some regex-magic in raw HTML blocks? Currently ignored.
#fixlinks!(ctx, navnode, md::Documents.RawHTML) = ...

end
