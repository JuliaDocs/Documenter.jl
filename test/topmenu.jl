module TopMenuTests

using Test

import Documenter: Documenter, Builder, NavNode, hide, makedocs
import Documenter.HTMLWriter: first_page_navnode, build_top_menu_sections, prev_next_navnodes,
    get_section_navtree

# FakeDocument structure to test top_menu functionality
mutable struct FakeDocumentBlueprint
    pages::Dict{String, Nothing}
    FakeDocumentBlueprint() = new(Dict())
end

mutable struct FakeDocumentUser
    pages::Vector{Any}
    FakeDocumentUser() = new(Any[])
end

mutable struct FakeDocumentInternal
    navlist::Vector{NavNode}
    navtree::Vector{NavNode}
    FakeDocumentInternal() = new([], [])
end

mutable struct FakeDocument
    user::FakeDocumentUser
    internal::FakeDocumentInternal
    blueprint::FakeDocumentBlueprint
    FakeDocument() = new(FakeDocumentUser(), FakeDocumentInternal(), FakeDocumentBlueprint())
end

# Builds the navigation tree for `pages` as makedocs would, with prev/next links set
function navtree_for(pages)
    doc = FakeDocument()
    doc.blueprint.pages = Dict(
        p => nothing for p in [
                "index.md", "a.md", "b.md", "c.md", "d.md", "e.md", "root.md", "root_child.md",
            ]
    )
    navtree = Documenter.walk_navpages(pages, nothing, doc)
    prev = nothing
    for nn in doc.internal.navlist
        nn.prev = prev
        prev === nothing || (prev.next = nn)
        prev = nn
    end
    return navtree, doc.internal.navlist
end

# A minimal stand-in for HTMLContext, with the fields used by the top_menu helpers
function fake_ctx(navtree)
    sections, page_section = build_top_menu_sections(navtree)
    return (;
        doc = (; internal = (; navtree)),
        top_menu_sections = sections,
        top_menu_page_section = page_section,
    )
end

@testset "build_top_menu_sections" begin
    navtree, navlist = navtree_for(
        [
            "Section A" => ["index.md", "a.md"],
            "Section B" => ["Sub" => ["b.md", "c.md"]],
            "Single" => "d.md",
            hide("With Sub-pages" => "root.md", ["root_child.md"]),
            hide("Hidden" => "e.md"),
        ]
    )
    sections, page_section = build_top_menu_sections(navtree)
    @test [s.title for s in sections] == ["Section A", "Section B", "Single", "With Sub-pages", "Hidden"]
    @test [s.visible for s in sections] == [true, true, true, true, false]
    @test [[nn.page for nn in s.navlist] for s in sections] ==
        [["index.md", "a.md"], ["b.md", "c.md"], ["d.md"], ["root.md", "root_child.md"], ["e.md"]]
    @test page_section == Dict(
        "index.md" => 1, "a.md" => 1, "b.md" => 2, "c.md" => 2, "d.md" => 3,
        "root.md" => 4, "root_child.md" => 4, "e.md" => 5,
    )
    # "Title" => [...] sections show their children in the sidebar ...
    @test sections[1].navtree == navtree[1].children
    # ... single-page sections show the page itself ...
    @test sections[3].navtree == [navtree[3]]
    # ... and so do sections that are a page with sub-pages, so that the page is not lost
    @test sections[4].navtree == [navtree[4]]

    # An empty section does not break anything
    navtree, _ = navtree_for(["Section A" => ["index.md"], "Empty" => []])
    sections, page_section = build_top_menu_sections(navtree)
    @test isempty(sections[2].navlist)
    @test page_section == Dict("index.md" => 1)

    # Pages in multiple sections are warned about, and are associated with the first one
    navtree, _ = navtree_for(["Section A" => ["index.md"], "Section B" => ["index.md", "a.md"]])
    sections, page_section = @test_logs (:warn, r"'index.md' appears in multiple top_menu sections") build_top_menu_sections(navtree)
    @test page_section == Dict("index.md" => 1, "a.md" => 2)

    # Top-level entries without a title are an error
    for pages in (["index.md"], ["index.md", "Section" => ["a.md"]], [hide("index.md")])
        navtree, _ = navtree_for(pages)
        @test_throws ErrorException build_top_menu_sections(navtree)
        err = try
            build_top_menu_sections(navtree)
        catch e
            e
        end
        @test occursin("must be a\n`\"Section Title\" => pages` pair", err.msg)
        @test occursin("'index.md' has no title", err.msg)
    end
end

@testset "top_menu sidebar and prev/next" begin
    navtree, navlist = navtree_for(
        [
            "Section A" => ["index.md", "a.md"],
            "Section B" => ["b.md", "c.md"],
            hide("With Sub-pages" => "root.md", ["root_child.md"]),
        ]
    )
    ctx = fake_ctx(navtree)
    index, a, b, c, root, root_child = navlist
    # Globally, the pages are chained across sections ...
    @test a.next === b
    @test b.prev === a
    # ... but with top_menu the prev/next links stay within each section
    @test prev_next_navnodes(ctx, index) == (nothing, a)
    @test prev_next_navnodes(ctx, a) == (index, nothing)
    @test prev_next_navnodes(ctx, b) == (nothing, c)
    @test prev_next_navnodes(ctx, c) == (b, nothing)
    @test prev_next_navnodes(ctx, root) == (nothing, root_child)
    @test prev_next_navnodes(ctx, root_child) == (root, nothing)

    @test get_section_navtree(ctx, a) == navtree[1].children
    @test get_section_navtree(ctx, c) == navtree[2].children
    @test get_section_navtree(ctx, root_child) == [navtree[3]]

    # Pages that are not part of any section (e.g. the search page) fall back to the
    # global navigation
    search = NavNode("search", "Search", nothing)
    @test get_section_navtree(ctx, search) == navtree
    @test prev_next_navnodes(ctx, search) == (nothing, nothing)
end

@testset "top_menu makedocs" begin
    mktempdir() do dir
        srcdir = joinpath(dir, "src")
        mkpath(srcdir)
        write(joinpath(srcdir, "index.md"), "# Index\n\nSome content.")
        build(pages) = makedocs(;
            root = dir, source = srcdir, build = joinpath(dir, "build"),
            sitename = "TopMenu EdgeCase", pages, remotes = nothing, debug = true,
            format = Documenter.HTML(top_menu = true, repolink = nothing),
        )
        # An existing page that is not a "Title" => pages pair is an error
        @test_throws ErrorException build(["index.md"])
        # A section without pages next to a regular one builds fine
        doc = build(["Home" => ["index.md"], "Empty Section" => []])
        @test doc isa Documenter.Document
        @test isfile(joinpath(dir, "build", "index.html"))
    end
end

@testset "walk_navpages" begin
    pages = [
        "page1.md",
        "Page2" => "page2.md",
    ]
    doc = FakeDocument()
    doc.blueprint.pages = Dict(
        "page1.md" => nothing,
        "page2.md" => nothing,
    )

    navtree = Documenter.walk_navpages(pages, nothing, doc)

    @test length(doc.internal.navlist) == 2
    @test doc.internal.navlist[1].page == "page1.md"
    @test doc.internal.navlist[2].page == "page2.md"
    @test doc.internal.navlist[2].title_override == "Page2"
end

@testset "first_page_navnode" begin
    # Node with a page returns itself
    leaf = NavNode("page.md", nothing, nothing)
    @test first_page_navnode(leaf) === leaf

    # Header node with no page and no children returns nothing
    header = NavNode(nothing, "Section", nothing)
    @test first_page_navnode(header) === nothing

    # Header node whose first child has a page returns that child
    child1 = NavNode("child1.md", nothing, nothing)
    child2 = NavNode("child2.md", nothing, nothing)
    header_with_children = NavNode(nothing, "Section", nothing)
    push!(header_with_children.children, child1, child2)
    @test first_page_navnode(header_with_children) === child1

    # Nested: header → header → page
    inner_header = NavNode(nothing, "Inner", nothing)
    deep_leaf = NavNode("deep.md", nothing, nothing)
    push!(inner_header.children, deep_leaf)
    outer_header = NavNode(nothing, "Outer", nothing)
    push!(outer_header.children, inner_header)
    @test first_page_navnode(outer_header) === deep_leaf

    # Node with a page is returned directly even if it also has children
    node_with_page_and_children = NavNode("parent.md", nothing, nothing)
    push!(node_with_page_and_children.children, NavNode("child.md", nothing, nothing))
    @test first_page_navnode(node_with_page_and_children) === node_with_page_and_children
end

end # module
