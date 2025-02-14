using Documenter

const pages = [
    "Home" => "index.md",
    "File" => "other.md",
]

@info "Building symlinks based docu"
makedocs(sitename = "Test", pages = pages)

@info "Testing symlinks"
@testset "Symlinks" begin
    # check that the symlinked page is built at all
    @test isdir("symlinks/build/other")
    @test isfile("symlinks/build/other/index.html")

    # check that it contains what we want
    filecontents = read("symlinks/build/other/index.html", String)
    @test occursin("another test", filecontents)
end
