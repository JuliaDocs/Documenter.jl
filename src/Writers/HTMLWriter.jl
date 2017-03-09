"""
A module for rendering `Document` objects to HTML.

# Page outline

The [`HTMLWriter`](@ref) makes use of the page outline that is determined by the
headings. It is assumed that if the very first block of a page is a level 1 heading,
then it is intended as the page title. This has two consequences:

1. It is then used to automatically determine the page title in the navigation menu
   and in the `<title>` tag, unless specified in the `.pages` option.
2. If the first heading is interpreted as being the page title, it is not displayed
   in the navigation sidebar.

# Default and custom assets

Documenter copies all files under the source directory (e.g. `/docs/src/`) over
to the compiled site. It also copies a set of default assets from `/assets/html/`
to the site's `assets/` directory, unless the user already had a file with the
same name, in which case the user's files overrides the Documenter's file.
This could, in principle, be used for customizing the site's style and scripting.

The HTML output also links certain custom assets to the generated HTML documents,
specfically a logo and additional javascript files.
The asset files that should be linked must be placed in `assets/`, under the source
directory (e.g `/docs/src/assets`) and must be on the top level (i.e. files in
the subdirectories of `assets/` are not linked).

For the **logo**, Documenter checks for the existence of `assets/logo.png`.
If that's present, it gets displayed in the navigation bar.

Additional JS and CSS assets can be included in the generated pages using the `assets`
keyword for `makedocs`. `assets` must be a `Vector{String}` and will include each listed
asset in the `<head>` of every page in the order in which they are listed. The type of
the asset (i.e. whether it is going to be included with a `<script>` or a `<link>` tag)
is determined by the file's extension -- either `.js` or `.css`.
"""
module HTMLWriter

using Compat

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities,
    Writers

import ...Utilities.DOM: DOM, Tag, @tags
using ...Utilities.MDFlatten

const requirejs_cdn = "https://cdnjs.cloudflare.com/ajax/libs/require.js/2.2.0/require.min.js"
const normalize_css = "https://cdnjs.cloudflare.com/ajax/libs/normalize/4.2.0/normalize.min.css"
const highlightjs_css = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/9.5.0/styles/default.min.css"
const google_fonts = "https://fonts.googleapis.com/css?family=Lato|Ubuntu+Mono"
const fontawesome_css = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.6.3/css/font-awesome.min.css"

"""
[`HTMLWriter`](@ref)-specific globals that are passed to [`domify`](@ref) and
other recursive functions.
"""
type HTMLContext
    doc :: Documents.Document
    logo :: Compat.String
    scripts :: Vector{Compat.String}
    documenter_js :: Compat.String
    documenter_css :: Compat.String
    search_js :: Compat.String
    search_index :: IOBuffer
    search_index_js :: Compat.String
    user_assets :: Vector{Compat.String}
end
HTMLContext(doc) = HTMLContext(doc, "", [], "", "", "", IOBuffer(), "", [])

"""
Returns a page (as a [`Documents.Page`](@ref) object) using the [`HTMLContext`](@ref).
"""
getpage(ctx, path) = ctx.doc.internal.pages[path]
getpage(ctx, navnode::Documents.NavNode) = getpage(ctx, get(navnode.page))


function render(doc::Documents.Document)
    !isempty(doc.user.sitename) || error("HTML output requires `sitename`.")

    ctx = HTMLContext(doc)
    ctx.search_index_js = "search_index.js"

    ctx.documenter_css = copy_asset("documenter.css", doc)

    let logo = joinpath("assets", "logo.png")
        if isfile(joinpath(doc.user.build, logo))
            ctx.logo = logo
        end
    end

    ctx.documenter_js = copy_asset("documenter.js", doc)
    ctx.search_js = copy_asset("search.js", doc)

    ctx.user_assets = doc.user.assets

    for navnode in doc.internal.navlist
        render_page(ctx, navnode)
    end

    render_search(ctx)

    open(joinpath(doc.user.build, ctx.search_index_js), "w") do io
        println(io, "var documenterSearchIndex = {\"docs\": [\n")
        write(io, Utilities.takebuf_str(ctx.search_index))
        println(io, "]}")
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
    # step and they should override documenter's original assets, we only actually
    # perform the copy if <source>/assets/<file> does not exist. Note that checking
    # the existence of <build>/assets/<file> is not sufficient since the <build>
    # directory might be dirty from a previous build.
    if isfile(alt_src)
        Utilities.warn("Not copying '$src', provided by the user.")
    else
        ispath(dirname(dst)) || mkpath(dirname(dst))
        ispath(dst) && Utilities.warn("Overwriting '$dst'.")
        cp(src, dst, remove_destination=true)
    end
    assetpath = normpath(joinpath("assets", file))
    # Replace any backslashes in links, if building the docs on Windows
    return replace(assetpath, '\\', '/')
end

# Page
# ------------------------------------------------------------------------------

"""
Constructs and writes the page referred to by the `navnode` to `.build`.
"""
function render_page(ctx, navnode)
    @tags html body

    page = getpage(ctx, navnode)

    head = render_head(ctx, navnode)
    navmenu = render_navmenu(ctx, navnode)
    article = render_article(ctx, navnode)

    htmldoc = DOM.HTMLDocument(
        html[:lang=>"en"](
            head,
            body(navmenu, article)
        )
    )
    open(Formats.extension(:html, page.build), "w") do io
        print(io, htmldoc)
    end
end

function render_head(ctx, navnode)
    @tags head meta link script title
    src = get(navnode.page)
    page_title = "$(mdflatten(pagetitle(ctx, navnode))) · $(ctx.doc.user.sitename)"
    css_links = [
        normalize_css,
        highlightjs_css,
        google_fonts,
        fontawesome_css,
        relhref(src, ctx.documenter_css),
    ]
    head(
        meta[:charset=>"UTF-8"],
        meta[:name => "viewport", :content => "width=device-width, initial-scale=1.0"],
        title(page_title),

        analytics_script(ctx.doc.user.analytics),

        # Stylesheets.
        map(css_links) do each
            link[:href => each, :rel => "stylesheet", :type => "text/css"]
        end,

        script("documenterBaseURL=\"$(relhref(src, "."))\""),
        script[
            :src => requirejs_cdn,
            Symbol("data-main") => relhref(src, ctx.documenter_js)
        ],

        script[:src => relhref(src, "../versions.js")],

        # Custom user-provided assets.
        asset_links(src, ctx.user_assets)
    )
end

function asset_links(src::AbstractString, assets::Vector)
    @tags link script
    local links = DOM.Node[]
    for each in assets
        local ext = splitext(each)[end]
        local url = relhref(src, each)
        local node =
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

## Search page
# ------------

function render_search(ctx)
    @tags article body h1 header hr html li nav p span ul script
    navnode = Documents.NavNode("search", "Search", nothing)

    head = render_head(ctx, navnode)
    navmenu = render_navmenu(ctx, navnode)
    article = article(
        header(
            nav(ul(li("Search"))),
            hr()
        ),
        h1("Search"),
        p["#search-info"]("Number of results: ", span["#search-results-number"]("loading...")),
        ul["#search-results"]
    )

    htmldoc = DOM.HTMLDocument(
        html[:lang=>"en"](
            head,
            body(navmenu, article),
            script[:src => ctx.search_index_js],
            script[:src => ctx.search_js],
        )
    )
    open(Formats.extension(:html, joinpath(ctx.doc.user.build, "search")), "w") do io
        print(io, htmldoc)
    end
end

# Navigation menu
# ------------------------------------------------------------------------------

function render_navmenu(ctx, navnode)
    @tags a form h1 img input nav div select option
    src = get(navnode.page)
    navmenu = nav[".toc"]
    if !isempty(ctx.logo)
        push!(navmenu.nodes,
            a[:href => relhref(src, "index.html")](
                img[
                    ".logo",
                    :src => relhref(src, ctx.logo),
                    :alt => "$(ctx.doc.user.sitename) logo"
                ]
            )
        )
    end
    push!(navmenu.nodes, h1(ctx.doc.user.sitename))
    push!(navmenu.nodes,
        form[".search", :action => relhref(src, "search.html")](
            select[
                "#version-selector",
                :onChange => "window.location.href=this.value",
            ](
                option[
                    :value => "#",
                    :selected => "selected",
                    :disabled => "disabled",
                ]("Version"),
            ),
            input[
                "#search-query",
                :name => "q",
                :type => "text",
                :placeholder => "Search docs",
            ],
        )
    )
    push!(navmenu.nodes, navitem(ctx, navnode))
    navmenu
end

"""
[`navitem`](@ref) returns the lists and list items of the navigation menu.
It gets called recursively to construct the whole tree.

It always returns a [`DOM.Node`](@ref). If there's nothing to display (e.g. the node is set
to be invisible), it returns an empty text node (`DOM.Node("")`).
"""
navitem(ctx, current) = navitem(ctx, current, ctx.doc.internal.navtree)
function navitem(ctx, current, nns::Vector)
    nodes = map(nn -> navitem(ctx, current, nn), nns)
    filter!(node -> node.name !== DOM.TEXT, nodes)
    isempty(nodes) ? DOM.Node("") : DOM.Tag(:ul)(nodes)
end
function navitem(ctx, current, nn::Documents.NavNode)
    @tags ul li span a

    # We'll do the children first, primarily to determine if this node has any that are
    # visible. If it does not and it itself is not visible (including current), then
    # we'll hide this one as well, returning an empty string Node.
    children = navitem(ctx, current, nn.children)
    if nn !== current && !nn.visible && children.name === DOM.TEXT
        return DOM.Node("")
    end

    # construct this item
    title = mdconvert(pagetitle(ctx, nn))
    link = if isnull(nn.page)
        span[".toctext"](title)
    else
        a[".toctext", :href => navhref(nn, current)](title)
    end
    item = (nn === current) ? li[".current"](link) : li(link)

    # add the subsections (2nd level headings) from the page
    if (nn === current) && !isnull(current.page)
        subs = collect_subsections(ctx.doc.internal.pages[get(current.page)])
        internal_links = map(subs) do _
            istoplevel, anchor, text = _
            _li = istoplevel ? li[".toplevel"] : li[]
            _li(a[".toctext", :href => anchor](mdconvert(text)))
        end
        push!(item.nodes, ul[".internal"](internal_links))
    end

    # add the visible subsections, if any, as a single list
    (children.name === DOM.TEXT) || push!(item.nodes, children)

    item
end


# Article (page contents)
# ------------------------------------------------------------------------------

function render_article(ctx, navnode)
    @tags article header footer nav ul li hr span a

    header_links = map(Documents.navpath(navnode)) do nn
        title = mdconvert(pagetitle(ctx, nn))
        isnull(nn.page) ? li(title) : li(a[:href => navhref(nn, navnode)](title))
    end

    topnav = nav(ul(header_links))
    Utilities.unwrap(Utilities.url(ctx.doc.user.repo, getpage(ctx, navnode).source)) do url
        push!(topnav.nodes, a[".edit-page", :href => url](span[".fa"]("\uf09b"), " Edit on GitHub"))
    end
    art_header = header(topnav, hr())

    # build the footer with nav links
    art_footer = footer(hr())
    Utilities.unwrap(navnode.prev) do nn
        direction = span[".direction"]("Previous")
        title = span[".title"](mdconvert(pagetitle(ctx, nn)))
        link = a[".previous", :href => navhref(nn, navnode)](direction, title)
        push!(art_footer.nodes, link)
    end

    Utilities.unwrap(navnode.next) do nn
        direction = span[".direction"]("Next")
        title = span[".title"](mdconvert(pagetitle(ctx, nn)))
        link = a[".next", :href => navhref(nn, navnode)](direction, title)
        push!(art_footer.nodes, link)
    end

    pagenodes = domify(ctx, navnode)
    article["#docs"](art_header, pagenodes, art_footer)
end

function generate_version_file(dir::AbstractString)
    local named_folders = []
    local release_folders = []
    local tag_folders = []
    for each in readdir(dir)
        each in ("stable", "latest")        ? push!(named_folders,   each) :
        ismatch(r"release\-\d+\.\d+", each) ? push!(release_folders, each) :
        ismatch(Base.VERSION_REGEX, each)   ? push!(tag_folders,     each) : nothing
    end
    open(joinpath(dir, "versions.js"), "w") do buf
        println(buf, "var DOC_VERSIONS = [")
        for group in (named_folders, release_folders, tag_folders)
            for folder in sort!(group, rev = true)
                println(buf, "  \"", folder, "\",")
            end
        end
        println(buf, "];")
    end
end

## domify(...)
# ------------

"""
Converts recursively a [`Documents.Page`](@ref), `Base.Markdown` or Documenter
`*Node` objects into HTML DOM.
"""
function domify(ctx, navnode)
    page = getpage(ctx, navnode)
    sib = SearchIndexBuffer(ctx, navnode)
    ret = map(page.elements) do elem
        search_append(sib, elem)
        domify(ctx, navnode, page.mapping[elem])
    end
    search_flush(sib)
    ret
end

type SearchIndexBuffer
    ctx :: HTMLContext
    src :: Compat.String
    page :: Documents.Page
    loc :: Compat.String
    category :: Symbol
    title :: Compat.String
    page_title :: Compat.String
    buffer :: IOBuffer
    function SearchIndexBuffer(ctx, navnode)
        page_title = mdflatten(pagetitle(ctx, navnode))
        new(
            ctx,
            Formats.extension(:html, get(navnode.page)),
            getpage(ctx, navnode),
            "",
            :page,
            page_title,
            page_title,
            IOBuffer()
        )
    end
end

function search_append(sib, node::Markdown.Header)
    search_flush(sib)
    sib.category = :section
    sib.title = mdflatten(node)
    a = sib.page.mapping[node]
    sib.loc = "$(a.id)-$(a.nth)"
end

search_append(sib, node) = mdflatten(sib.buffer, node)

function search_flush(sib)
    # Replace any backslashes in links, if building the docs on Windows
    src = replace(sib.src, '\\', '/')
    ref = isempty(src) ? src : "$(src)#$(sib.loc)"
    text = Utilities.takebuf_str(sib.buffer)
    println(sib.ctx.search_index, """
    {
        "location": "$(jsonescape(ref))",
        "page": "$(jsonescape(sib.page_title))",
        "title": "$(jsonescape(sib.title))",
        "category": "$(jsonescape(string(sib.category)))",
        "text": "$(jsonescape(text))"
    },
    """)
end

function jsonescape(s)
    s = replace(s, '\\', "\\\\")
    s = replace(s, '\n', "\\n")
    replace(s, '"', "\\\"")
end

domify(ctx, navnode, node) = mdconvert(node, Base.Markdown.MD())

function domify(ctx, navnode, anchor::Anchors.Anchor)
    @tags a
    aid = "$(anchor.id)-$(anchor.nth)"
    if isa(anchor.object, Markdown.Header)
        h = anchor.object
        DOM.Tag(Symbol("h$(Utilities.header_level(h))"))(
            a[".nav-anchor", :id => aid, :href => "#$aid"](mdconvert(h.text, h))
        )
    else
        a[".nav-anchor", :id => aid, :href => "#$aid"](domify(ctx, navnode, anchor.object))
    end
end


immutable ListBuilder
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
    lb = ListBuilder()
    for (count, path, anchor) in contents.elements
        path = Formats.extension(:html, path)
        header = anchor.object
        url = string(path, '#', anchor.id, '-', anchor.nth)
        node = a[:href=>url](mdconvert(header.text))
        level = Utilities.header_level(header)
        push!(lb, level, node)
    end
    domify(lb)
end

function domify(ctx, navnode, index::Documents.IndexNode)
    @tags a code li ul
    lis = map(index.elements) do _
        object, doc, page, mod, cat = _
        page = Formats.extension(:html, page)
        url = string(page, "#", Utilities.slugify(object))
        li(a[:href=>url](code("$(object.binding)")))
    end
    ul(lis)
end

function domify(ctx, navnode, docs::Documents.DocsNodes)
    [domify(ctx, navnode, node) for node in docs.nodes]
end

function domify(ctx, navnode, node::Documents.DocsNode)
    @tags a code div section span

    # push to search index
    sib = SearchIndexBuffer(ctx, navnode)
    sib.loc = node.anchor.id
    sib.title = string(node.object.binding)
    sib.category = Utilities.doccat(node.object)
    mdflatten(sib.buffer, node.docstr)
    search_flush(sib)

    section[".docstring"](
        div[".docstring-header"](
            a[".docstring-binding", :id=>node.anchor.id, :href=>"#$(node.anchor.id)"](code("$(node.object.binding)")),
            " — ", # &mdash;
            span[".docstring-category"]("$(Utilities.doccat(node.object))"),
            "."
        ),
        domify_doc(ctx, navnode, node.docstr)
    )
end

function domify_doc(ctx, navnode, md::Markdown.MD)
    @tags a br
    if haskey(md.meta, :results)
        # The `:results` field contains a vector of `Docs.DocStr` objects associated with
        # each markdown object. The `DocStr` contains data such as file and line info that
        # we need for generating correct source links.
        map(zip(md.content, md.meta[:results])) do _
            markdown, result = _
            ret = Any[domify(ctx, navnode, Writers.MarkdownWriter.dropheaders(markdown))]
            # When a source link is available then print the link.
            Utilities.unwrap(Utilities.url(ctx.doc.internal.remote, ctx.doc.user.repo, result)) do url
                push!(ret, a[".source-link", :target=>"_blank", :href=>url]("source"))
                push!(ret, br())
            end
            ret
        end
    else
        # Docstrings with no `:results` metadata won't contain source locations so we don't
        # try to print them out. Just print the basic docstring.
        domify(ctx, navnode, Writers.MarkdownWriter.dropheaders(md))
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
Get the relative hyperlink between two [`Documents.NavNode`](@ref)s. Assumes that both
[`Documents.NavNode`](@ref)s have an associated [`Documents.Page`](@ref) (i.e. `.page` is not null).
"""
navhref(to, from) = Formats.extension(:html, relhref(get(from.page), get(to.page)))

"""
Calculates a relative HTML link from one path to another.
"""
function relhref(from, to)
    pagedir = dirname(from)
    # The regex separator replacement is necessary since otherwise building the docs on
    # Windows will result in paths that have `//` separators which break asset inclusion.
    replace(relpath(to, isempty(pagedir) ? "." : pagedir), r"[/\\]+", "/")
end

"""
Tries to guess the page title by looking at the `<h1>` headers and returns the
header contents of the first `<h1>` on a page as a `Nullable` (nulled if the algorithm
was unable to find any `<h1>` headers).
"""
function pagetitle(page::Documents.Page)
    title = Nullable{Any}()
    for element in page.elements
        if isa(element, Base.Markdown.Header{1})
            title = Nullable{Any}(element.text)
            break
        end
    end
    title
end

function pagetitle(ctx, navnode::Documents.NavNode)
    isnull(navnode.title_override) || return get(navnode.title_override)

    if !isnull(navnode.page)
        title = pagetitle(getpage(ctx, navnode))
        isnull(title) || return get(title)
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
        if isa(element, Base.Markdown.Header) && Utilities.header_level(element) < 3
            local toplevel = Utilities.header_level(element) === 1
            # Don't include the first header if it is `h1`.
            if toplevel && isempty(sections) && !title_found
                title_found = true
                continue
            end
            local anchor = page.mapping[element]
            push!(sections, (toplevel, "#$(anchor.id)-$(anchor.nth)", element.text))
        end
    end
    return sections
end


# mdconvert
# ------------------------------------------------------------------------------

const md_block_nodes = [Markdown.MD, Markdown.BlockQuote]
fieldtype(Markdown.List, :ordered) == Int && push!(md_block_nodes, Markdown.List)
if isdefined(Base.Markdown, :Admonition) push!(md_block_nodes, Markdown.Admonition) end

"""
[`MDBlockContext`](@ref) is a union of all the Markdown nodes whose children should
be blocks. It can be used to dispatch on all the block-context nodes at once.
"""
typealias MDBlockContext Union{md_block_nodes...}

"""
Convert a markdown object to a `DOM.Node` object.

The `parent` argument is passed to allow for context-dependant conversions.
"""
mdconvert(md) = mdconvert(md, md)

mdconvert(text::AbstractString, parent) = DOM.Node(text)

mdconvert(vec::Vector, parent) = [mdconvert(x, parent) for x in vec]

mdconvert(md::Markdown.MD, parent) = Tag(:div)(mdconvert(md.content, md))

mdconvert(b::Markdown.BlockQuote, parent) = Tag(:blockquote)(mdconvert(b.content, b))

mdconvert(b::Markdown.Bold, parent) = Tag(:strong)(mdconvert(b.text, parent))

function mdconvert(c::Markdown.Code, parent::MDBlockContext)
    @tags pre code
    language = isempty(c.language) ? "none" : c.language
    language = language == "jldoctest" ? "julia" : language
    pre(code[".language-$(language)"](c.code))
end
mdconvert(c::Markdown.Code, parent) = Tag(:code)(c.code)

mdconvert{N}(h::Markdown.Header{N}, parent) = DOM.Tag(Symbol("h$N"))(mdconvert(h.text, h))

mdconvert(::Markdown.HorizontalRule, parent) = Tag(:hr)()

mdconvert(i::Markdown.Image, parent) = Tag(:img)[:src => i.url, :alt => i.alt]

mdconvert(i::Markdown.Italic, parent) = Tag(:em)(mdconvert(i.text, i))

mdconvert(m::Markdown.LaTeX, ::MDBlockContext)   = Tag(:div)(string("\\[", m.formula, "\\]"))
mdconvert(m::Markdown.LaTeX, parent) = Tag(:span)(string('$', m.formula, '$'))

mdconvert(::Markdown.LineBreak, parent) = Tag(:br)()

function mdconvert(link::Markdown.Link, parent)
    # TODO: fixing the extension should probably be moved to an earlier step
    if Utilities.isabsurl(link.url)
        Tag(:a)[:href => link.url](mdconvert(link.text, link))
    else
        s = split(link.url, "#", limit = 2)
        path = first(s)
        path = endswith(path, ".md") ? Formats.extension(:html, path) : path
        # Replace any backslashes in links, if building the docs on Windows
        path = replace(path, '\\', '/')
        url = (length(s) > 1) ? "$path#$(last(s))" : Compat.String(path)
        Tag(:a)[:href => url](mdconvert(link.text, link))
    end
end

mdconvert(list::Markdown.List, parent) = (isordered(list) ? Tag(:ol) : Tag(:ul))(map(Tag(:li), mdconvert(list.items, list)))

mdconvert(paragraph::Markdown.Paragraph, parent) = Tag(:p)(mdconvert(paragraph.content, paragraph))

mdconvert(t::Markdown.Table, parent) = Tag(:table)(
    Tag(:tr)(map(_ -> Tag(:th)(mdconvert(_, t)), t.rows[1])),
    map(_ -> Tag(:tr)(map(__ -> Tag(:td)(mdconvert(__, _)), _)), t.rows[2:end])
)

mdconvert(expr::Union{Expr,Symbol}, parent) = string(expr)

# Only available on Julia 0.5.
if isdefined(Base.Markdown, :Footnote)
    mdconvert(f::Markdown.Footnote, parent) = footnote(f.id, f.text, parent)
    footnote(id, text::Void, parent) = Tag(:a)[:href => "#footnote-$(id)"]("[$id]")
    function footnote(id, text, parent)
        Tag(:div)[".footnote#footnote-$(id)"](
            Tag(:a)[:href => "#footnote-$(id)"](Tag(:strong)("[$id]")),
            mdconvert(text, parent),
        )
    end
end

if isdefined(Base.Markdown, :Admonition)
    function mdconvert(a::Markdown.Admonition, parent)
        @tags div
        div[".admonition.$(a.category)"](
            div[".admonition-title"](a.title),
            div[".admonition-text"](mdconvert(a.content, a))
        )
    end
end

if isdefined(Base.Markdown, :isordered)
    import Base.Markdown: isordered
else
    isordered(a::Markdown.List) = a.ordered::Bool
end

mdconvert(html::Documents.RawHTML, parent) = Tag(Symbol("#RAW#"))(html.code)

end
