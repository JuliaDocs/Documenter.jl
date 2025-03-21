using Test
using Documenter
include("../TestUtilities.jl"); using Main.TestUtilities

const pages = [
    "Home" => "index.md",
    "File" => "other.md",
]

@quietly makedocs(sitename = "Test", pages = pages)

@testset "Symlinks" begin
    # check that the symlinked page is built at all
    other = joinpath(@__DIR__, "build", "other")
    @test isdir(other)
    other_index = joinpath(other, "index.html")
    @test isfile(other_index)

    # check that it contains what we want
    filecontents = read(other_index, String)
    @test occursin("another test", filecontents)
end
