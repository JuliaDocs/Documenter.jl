module NavNodeTests

using Test

import Documenter: Documenter, Builder, NavNode

mutable struct FakeDocumentBlueprint
    pages::Dict{String, Nothing}
    FakeDocumentBlueprint() = new(Dict())
end
mutable struct FakeDocumentInternal
    navlist::Vector{NavNode}
    FakeDocumentInternal() = new([])
end
mutable struct FakeDocument
    internal::FakeDocumentInternal
    blueprint::FakeDocumentBlueprint
    FakeDocument() = new(FakeDocumentInternal(), FakeDocumentBlueprint())
end

@testset "NavNode" begin
    @test fieldtype(FakeDocumentInternal, :navlist) == fieldtype(Documenter.Internal, :navlist)

    pages = [
        "page1.md",
        "Page2" => "page2.md",
        "Section" => [
            "page3.md",
            "Page4" => "page4.md",
            "Subsection" => [
                "page5.md",
            ],
        ],
        "page6.md",
    ]
    doc = FakeDocument()
    doc.blueprint.pages = Dict(map(i -> "page$i.md" => nothing, 1:8))
    navtree = Documenter.walk_navpages(pages, nothing, doc)
    navlist = doc.internal.navlist

    @test length(navlist) == 6
    for (i, navnode) in enumerate(navlist)
        @test navnode.page == "page$i.md"
    end

    @test isa(navtree, Vector{NavNode})
    @test length(navtree) == 4
    @test navtree[1] === navlist[1]
    @test navtree[2] === navlist[2]
    @test navtree[4] === navlist[6]

    section = navtree[3]
    @test section.title_override == "Section"
    @test section.page === nothing
    @test length(section.children) == 3

    navpath = Documenter.navpath(navlist[5])
    @test length(navpath) == 3
    @test navpath[1] === section
    @test navpath[3] === navlist[5]

    @test repr(navlist[1]) == "NavNode(\"page1.md\", nothing, nothing)"
    @test repr(navlist[2]) == "NavNode(\"page2.md\", \"Page2\", nothing)"
    @test repr(navlist[3]) == "NavNode(\"page3.md\", nothing, NavNode(nothing, ...))"
    @test repr(navlist[4]) == "NavNode(\"page4.md\", \"Page4\", NavNode(nothing, ...))"
    @test repr(navlist[5]) == "NavNode(\"page5.md\", nothing, NavNode(nothing, ...))"
    @test repr(navlist[6]) == "NavNode(\"page6.md\", nothing, nothing)"
end

end
