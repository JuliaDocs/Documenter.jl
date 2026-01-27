module TopMenuTests

using Test

import Documenter: Documenter, Builder, NavNode, TopMenuSection

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

end # module
