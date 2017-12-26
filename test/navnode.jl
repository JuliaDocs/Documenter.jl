module NavNodeTests

using Compat.Test

using Compat
import Documenter: Documents, Builder
import Documenter.Documents: NavNode

mutable struct FakeDocumentInternal
    pages   :: Dict{String, Nothing}
    navlist :: Vector{NavNode}
    FakeDocumentInternal() = new(Dict(), [])
end
mutable struct FakeDocument
    internal :: FakeDocumentInternal
    FakeDocument() = new(FakeDocumentInternal())
end

@testset "NavNode" begin
    @test fieldtype(FakeDocumentInternal, :navlist) == fieldtype(Documents.Internal, :navlist)

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
    doc.internal.pages = Dict(map(i -> "page$i.md" => nothing, 1:8))
    navtree = Builder.walk_navpages(pages, nothing, doc)
    navlist = doc.internal.navlist

    @test length(navlist) == 6
    for (i,navnode) in enumerate(navlist)
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

    navpath = Documents.navpath(navlist[5])
    @test length(navpath) == 3
    @test navpath[1] === section
    @test navpath[3] === navlist[5]
end

end
