"""
Provides the [`render`](@ref) methods to write the documentation as HTML files
(`MIME"text/html"`).

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

For **scripts**, every `assets/*.js` gets a `<script>` link in the `<head>` tag
of every page (except if it matches one of Documenter's default scripts;
the filtering is done in [`user_scripts`](@ref)).

Note that only javascript files are linked to the generated HTML. Any related CSS
must be loaded by the script. With jQuery this could be done with the following
snippet

```javascript
\$('head').append(\$('<link rel="stylesheet">').attr('href', documenterBaseURL + "/assets/<file>.css"))
```
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

import ..Writers: Writer, render
import ...Utilities.DOM: DOM, Tag, @tags
using ...Utilities.MDFlatten

const requirejs_cdn = "https://cdnjs.cloudflare.com/ajax/libs/require.js/2.2.0/require.min.js"

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
    user_scripts :: Vector{Compat.String}
end
HTMLContext(doc) = HTMLContext(doc, "", [], "", "", "", IOBuffer(), "", [])

"""
Returns a page (as a [`Documents.Page`](@ref) object) using the [`HTMLContext`](@ref).
"""
getpage(ctx, path) = ctx.doc.internal.pages[path]
getpage(ctx, navnode::Documents.NavNode) = getpage(ctx, get(navnode.page))


function render(::Writer{Formats.HTML}, doc::Documents.Document)
    !isempty(doc.user.sitename) || error("HTML output requires `sitename`.")

    ctx = HTMLContext(doc)
    ctx.search_index_js = "search_index.js"

    ctx.documenter_css = copy_asset("documenter.css", doc)
    copy_asset("style.css", doc)

    let logo = joinpath("assets", "logo.png")
        if isfile(joinpath(doc.user.build, logo))
            ctx.logo = logo
        end
    end

    ctx.documenter_js = copy_asset("documenter.js", doc)
    ctx.search_js = copy_asset("search.js", doc)
    ctx.user_scripts = user_scripts(doc)

    for navnode in doc.internal.navlist
        render_page(ctx, navnode)
    end

    render_search(ctx)

    open(joinpath(doc.user.build, ctx.search_index_js), "w") do io
        println(io, "var documenterSearchIndex = {\"docs\": [\n")
        write(io, takebuf_string(ctx.search_index))
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
    normpath(joinpath("assets", file))
end

"""
Creates a list of `.js` files provided by the user under `assets`. Returns a list
of paths relative to the site root.
"""
function user_scripts(doc)
    documenter_assetsdir = joinpath(Utilities.assetsdir(), "html")
    local_assetsdir = joinpath(doc.user.source, "assets")
    isdir(local_assetsdir) || return []
    scripts = filter(readdir(local_assetsdir)) do file
        # we'll make sure that it's
        #   1. a file (i.e. not a directory),
        #   2. a script, determined by the extension
        #   3. not one of the default assets, which get handled separately
        isfile(joinpath(local_assetsdir, file)) &&
            last(splitext(file)) == ".js" &&
            !isfile(joinpath(documenter_assetsdir, file))
    end
    [joinpath("assets", script) for script in scripts]
end

# Page
# ------------------------------------------------------------------------------

"""
Constructs and writes the page referred to by the `navnode` to `.build`.
"""
function render_page(ctx, navnode)
    @tags html body

    page = getpage(ctx, navnode)

    head = render_head(ctx, navnode, ctx.user_scripts)
    navmenu = render_navmenu(ctx, navnode)
    article = render_article(ctx, navnode)

    htmldoc = DOM.HTMLDocument(
        html[:lang=>"en"](
            head,
            body(navmenu, article)
        )
    )
    open(Formats.extension(Formats.HTML, page.build), "w") do io
        print(io, htmldoc)
    end
end

function render_head(ctx, navnode, additional_scripts)
    @tags head meta link script title
    src = get(navnode.page)
    page_title = "$(mdflatten(pagetitle(ctx, navnode))) · $(ctx.doc.user.sitename) documentation"
    head(
        meta[:charset=>"UTF-8"],
        meta[:name => "viewport", :content => "width=device-width, initial-scale=1.0"],
        title(page_title),

        link[
            :href => relhref(src, ctx.documenter_css),
            :rel => "stylesheet",
            :type => "text/css"
        ],

        script("documenterBaseURL=\"$(relhref(src, "."))\""),
        script[
            :src => requirejs_cdn,
            Symbol("data-main") => relhref(src, ctx.documenter_js)
        ],
        map(additional_scripts) do s
            script[:src => relhref(src, s)]
        end
    )
end

## Search page
# ------------

function render_search(ctx)
    @tags article body h1 header hr html li nav p span ul
    navnode = Documents.NavNode("search", "Search", nothing)

    additional_scripts = vcat([ctx.search_js, ctx.search_index_js], ctx.user_scripts)
    head = render_head(ctx, navnode, additional_scripts)
    navmenu = render_navmenu(ctx, navnode)
    article = article(
        header(
            nav(ul(li("Search"))),
            hr()
        ),
        h1("Search"),
        p["#search-info"]("Number of results: ", span["#search-results-number"]("-")),
        ul["#search-results"]
    )

    htmldoc = DOM.HTMLDocument(
        html[:lang=>"en"](
            head,
            body(navmenu, article)
        )
    )
    open(Formats.extension(Formats.HTML, joinpath(ctx.doc.user.build, "search")), "w") do io
        print(io, htmldoc)
    end
end

# Navigation menu
# ------------------------------------------------------------------------------

function render_navmenu(ctx, navnode)
    @tags a form h1 img input nav
    src = get(navnode.page)
    navmenu = nav[".toc"]
    if !isempty(ctx.logo)
        push!(navmenu.nodes,
            a[:href => ""]( # TODO: link to github?
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
            input[
                "#search-query",
                :name => "q",
                :type => "text",
                :placeholder => "Search docs"
            ]
        )
    )
    push!(navmenu.nodes, navitem(ctx, navnode))
    navmenu
end

"""
[`navitem`](@ref) returns the lists and list items of the navigation menu.
It gets called recursively to construct the whole tree.
"""
navitem(ctx, current) = navitem(ctx, current, ctx.doc.internal.navtree)
navitem(ctx, current, nns::Vector) = DOM.Tag(:ul)(map(nn -> navitem(ctx, current, nn), nns))
function navitem(ctx, current, nn::Documents.NavNode)
    @tags ul li span a

    # construct this item
    title = mdconvert(pagetitle(ctx, nn))
    link = if isnull(nn.page)
        span[".toctext"](title)
    else
        a[".toctext", :href => navhref(nn, current)](title)
    end
    item = (nn === current) ? li[".current"](link) : li(link)

    # add the subsections (2nd level headings) from the page
    if nn === current && !isnull(nn.page)
        subs = collect_subsections(ctx.doc.internal.pages[get(nn.page)])
        internal_links = map(subs) do _
            anchor, text = _
            li(a[".toctext", :href => anchor](mdconvert(text)))
        end
        push!(item.nodes, ul[".internal"](internal_links))
    end

    # add the subsections, if any, as a single list
    if !isempty(nn.children)
        push!(item.nodes, navitem(ctx, current, nn.children))
    end

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
            Formats.extension(Formats.HTML, get(navnode.page)),
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
    ref = isempty(sib.src) ? sib.src : "$(sib.src)#$(sib.loc)"
    text = takebuf_string(sib.buffer)
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
        path = Formats.extension(ctx.doc.user.format, path)
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
        page = Formats.extension(ctx.doc.user.format, page)
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


# Utilities
# ------------------------------------------------------------------------------

"""
Get the relative hyperlink between two [`Documents.NavNode`](@ref)s. Assumes that both
[`Documents.NavNode`](@ref)s have an associated [`Documents.Page`](@ref) (i.e. `.page` is not null).
"""
navhref(to, from) = Formats.extension(Formats.HTML, relhref(get(from.page), get(to.page)))

"""
Calculates a relative HTML link from one path to another.
"""
function relhref(from, to)
    pagedir = dirname(from)
    relpath(to, isempty(pagedir) ? "." : pagedir)
end

"""
Tries to guess the page title by looking at the `<h1>` headers and returns the
header contents as a `Nullable` (nulled if the algorithm was unable to determine
the header).
"""
function pagetitle(page::Documents.Page)
    for e in page.elements
        isa(e, Base.Markdown.Header{1}) && return Nullable{Any}(e.text)
    end
    return Nullable{Any}()
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
Returns a list of tuples `(anchor, text)`, corresponding to all level 2 headers.
"""
function collect_subsections(page::Documents.Page)
    # TODO: Should probably be replaced by a proper outline algorithm.
    #       Currently we ignore the case when there are multiple h1-s.
    hs = filter(e -> isa(e, Base.Markdown.Header{2}), page.elements)
    map(hs) do e
        anchor = page.mapping[e]
        "#$(anchor.id)-$(anchor.nth)", e.text
    end
end


# mdconvert
# ------------------------------------------------------------------------------

md_block_nodes = [Markdown.MD, Markdown.BlockQuote, Markdown.List]
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

const ABSURL_REGEX = r"^[[:alpha:]+-.]+://"
function mdconvert(link::Markdown.Link, parent)
    # TODO: fixing the extension should probably be moved to an earlier step
    if ismatch(ABSURL_REGEX, link.url)
        Tag(:a)[:href => link.url](mdconvert(link.text, link))
    else
        s = split(link.url, "#", limit = 2)
        path = first(s)
        path = endswith(path, ".md") ? Formats.extension(Formats.HTML, path) : path
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
    mdconvert(f::Markdown.Footnote, parent)   = footnote(f.id, f.text, parent)
    footnote(id, text::Void, parent) = Tag(:a)[:href => "#footnote-$(id)"]("[$id]")
    footnote(id, text,       parent) = Tag(:span)["#footnote-$(id)"](mdconvert(text, parent))
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
