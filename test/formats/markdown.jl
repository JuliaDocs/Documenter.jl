module MarkdownFormatTests

using Compat.Test
using Compat.Random
using Compat: @info

using Documenter

# Documenter package docs
@info("Building Documenter's docs with Markdown.")
const Documenter_root = normpath(joinpath(@__DIR__, "..", "..", "docs"))
build_dir_relpath = relpath(joinpath(@__DIR__, "builds/markdown"), Documenter_root)
doc = makedocs(
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

    mktempdir() do root
        let path = joinpath(root, "docs")
            Documenter.generate("DocumenterTestPackage", dir = path)
            @test isdir(path)
            @test isfile(joinpath(path, "mkdocs.yml"))
            @test isfile(joinpath(path, ".gitignore"))
            @test isfile(joinpath(path, "make.jl"))
            @test isdir(joinpath(path, "src"))
            @test isfile(joinpath(path, "src", "index.md"))
        end
    end

    @test_throws ErrorException Documenter.generate("Documenter")
    @test_throws ErrorException Documenter.generate(randstring())
end

end
