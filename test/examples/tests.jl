using Compat.Test
using Compat

# Compat for Julia 0.6
if !isdefined(Base, Symbol("@isdefined"))
    macro isdefined(x)
        :(isdefined($(esc(QuoteNode(x)))))
    end
end

# When the file is run separately we need to include make.jl which actually builds
# the docs and defines a few modules that are referred to in the docs. The make.jl
# has to be expected in the context of the Main module.
if (@__MODULE__) === Main && !@isdefined examples_root
    include("make.jl")
elseif (@__MODULE__) !== Main && isdefined(Main, :examples_root)
    using Documenter
    const examples_root = Main.examples_root
elseif (@__MODULE__) !== Main && !isdefined(Main, :examples_root)
    error("examples/make.jl has not been loaded into Main.")
end

@testset "Examples" begin
    @testset "Markdown" begin
        doc = Main.examples_markdown_doc

        @test isa(doc, Documenter.Documents.Document)

        let build_dir  = joinpath(examples_root, "builds", "markdown"),
            source_dir = joinpath(examples_root, "src")

            @test isdir(build_dir)
            @test isdir(joinpath(build_dir, "assets"))
            @test isdir(joinpath(build_dir, "lib"))
            @test isdir(joinpath(build_dir, "man"))

            @test isfile(joinpath(build_dir, "index.md"))
            @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
            @test isfile(joinpath(build_dir, "assets", "Documenter.css"))
            @test isfile(joinpath(build_dir, "assets", "custom.css"))
            @test isfile(joinpath(build_dir, "assets", "custom.js"))
            @test isfile(joinpath(build_dir, "lib", "functions.md"))
            @test isfile(joinpath(build_dir, "man", "tutorial.md"))
            @test isfile(joinpath(build_dir, "man", "data.csv"))
            @test isfile(joinpath(build_dir, "man", "julia.svg"))

            @test (==)(
                read(joinpath(source_dir, "man", "data.csv"), String),
                read(joinpath(build_dir,  "man", "data.csv"), String),
            )
        end

        @test doc.user.root   == examples_root
        @test doc.user.source == "src"
        @test doc.user.build  == "builds/markdown"
        @test doc.user.clean  == true
        @test doc.user.format == [:markdown]

        @test realpath(doc.internal.assets) == realpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

        @test length(doc.internal.pages) == 10

        let headers = doc.internal.headers
            @test Documenter.Anchors.exists(headers, "Documentation")
            @test Documenter.Anchors.exists(headers, "Documentation")
            @test Documenter.Anchors.exists(headers, "Index-Page")
            @test Documenter.Anchors.exists(headers, "Functions-Contents")
            @test Documenter.Anchors.exists(headers, "Tutorial-Contents")
            @test Documenter.Anchors.exists(headers, "Index")
            @test Documenter.Anchors.exists(headers, "Tutorial")
            @test Documenter.Anchors.exists(headers, "Function-Index")
            @test Documenter.Anchors.exists(headers, "Functions")
            @test Documenter.Anchors.isunique(headers, "Functions")
            @test Documenter.Anchors.isunique(headers, "Functions", joinpath("builds", "markdown", "lib", "functions.md"))
            let name = "Foo", path = joinpath("builds", "markdown", "lib", "functions.md")
                @test Documenter.Anchors.exists(headers, name, path)
                @test !Documenter.Anchors.isunique(headers, name)
                @test !Documenter.Anchors.isunique(headers, name, path)
                @test length(headers.map[name][path]) == 4
            end
        end

        @test length(doc.internal.objects) == 38
    end

    @testset "HTML" begin
        doc = Main.examples_html_doc

        @test isa(doc, Documenter.Documents.Document)

        # TODO: test the HTML build
    end

    @testset "HTML: html-pretty-urls" begin
        doc = Main.examples_html_doc

        @test isa(doc, Documenter.Documents.Document)

        # TODO: test the HTML build with pretty URLs
    end
end
