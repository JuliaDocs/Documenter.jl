using Documenter
using Test

const pages = [
    "Home" => "index.md",
]

makedocs(sitename = "Test", pages = pages, doctest = true)

@testset "clear_modules!" begin
    # force a full GC
    GC.gc(true)
    # check that the finalizer was run
    @test Main.finalizer_count[1] == 1
end
