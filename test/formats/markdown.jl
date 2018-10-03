module MarkdownFormatTests

using Test
using Random

using Documenter

# Documenter package docs
@info("Building Documenter's docs with Markdown.")
const Documenter_root = normpath(joinpath(@__DIR__, "..", "..", "docs"))
build_dir_relpath = relpath(joinpath(@__DIR__, "builds/markdown"), Documenter_root)
doc = makedocs(
    format = :markdown,
    debug   = true,
    root    = Documenter_root,
    modules = Documenter,
    build   = build_dir_relpath,
)

@testset "Markdown" begin
    @test isa(doc, Documenter.Documents.Document)

    let build_dir  = joinpath(Documenter_root, build_dir_relpath),
        source_dir = joinpath(Documenter_root, "src")
        @test isdir(build_dir)
        @test isdir(joinpath(build_dir, "assets"))
        @test isdir(joinpath(build_dir, "lib"))
        @test isdir(joinpath(build_dir, "man"))

        @test isfile(joinpath(build_dir, "index.md"))
        @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
        @test isfile(joinpath(build_dir, "assets", "Documenter.css"))
    end

    @test doc.user.root   == Documenter_root
    @test doc.user.source == "src"
    @test doc.user.build  == build_dir_relpath
    @test doc.user.clean  == true
end

end
