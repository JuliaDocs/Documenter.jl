module TopMenuTests

using Test

import Documenter: Documenter, Builder, NavNode, TopMenuSection
import Documenter.HTMLWriter: first_page_navnode

# FakeDocument structure to test top_menu functionality
mutable struct FakeDocumentBlueprint
    pages::Dict{String, Nothing}
    FakeDocumentBlueprint() = new(Dict())
end

mutable struct FakeDocumentUser
    pages::Vector{Any}
    top_menu::Vector{Any}
    FakeDocumentUser() = new(Any[], Any[])
end

mutable struct FakeDocumentInternal
    navlist::Vector{NavNode}
    navtree::Vector{NavNode}
    top_menu_sections::Vector{TopMenuSection}
    FakeDocumentInternal() = new([], [], [])
end

mutable struct FakeDocument
    user::FakeDocumentUser
    internal::FakeDocumentInternal
    blueprint::FakeDocumentBlueprint
    FakeDocument() = new(FakeDocumentUser(), FakeDocumentInternal(), FakeDocumentBlueprint())
end

@testset "TopMenuSection" begin
    # Test basic TopMenuSection construction
    section = TopMenuSection("Test Section")
    @test section.title == "Test Section"
    @test isempty(section.navtree)
    @test isempty(section.navlist)
    @test section.first_page === nothing

    # Test full TopMenuSection construction
    navnode = NavNode("page.md", "Page", nothing)
    section = TopMenuSection("Test", [navnode], [navnode], "page.md")
    @test section.title == "Test"
    @test length(section.navtree) == 1
    @test length(section.navlist) == 1
    @test section.first_page == "page.md"
end

@testset "TopMenu walk_navpages" begin
    # Test that walk_navpages works with custom navlist
    pages = [
        "page1.md",
        "Page2" => "page2.md",
    ]
    doc = FakeDocument()
    doc.blueprint.pages = Dict(
        "page1.md" => nothing,
        "page2.md" => nothing,
    )

    custom_navlist = NavNode[]
    navtree = Documenter.walk_navpages(pages, nothing, doc; navlist = custom_navlist)

    @test length(custom_navlist) == 2
    @test custom_navlist[1].page == "page1.md"
    @test custom_navlist[2].page == "page2.md"
    @test custom_navlist[2].title_override == "Page2"

    # When using custom navlist, doc.internal.navlist should be empty
    @test isempty(doc.internal.navlist)
end

@testset "TopMenu backward compatibility" begin
    # Test that walk_navpages works without navlist argument (default behavior)
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

    # Default behavior: nodes should be in doc.internal.navlist
    @test length(doc.internal.navlist) == 2
    @test doc.internal.navlist[1].page == "page1.md"
    @test doc.internal.navlist[2].page == "page2.md"
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
