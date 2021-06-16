using Test

# DOCUMENTER_TEST_EXAMPLES can be used to control which builds are performed in
# make.jl. But for the tests we need to make sure that all the relevant builds
# ran.
haskey(ENV, "DOCUMENTER_TEST_EXAMPLES") && error("DOCUMENTER_TEST_EXAMPLES env. variable is set")

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
    @testset "HTML: deploy/$name" for (doc, name) in [
        (Main.examples_html_doc, "html"),
        (Main.examples_html_mathjax2_custom_doc, "html-mathjax2-custom"),
        (Main.examples_html_mathjax3_doc, "html-mathjax3"),
        (Main.examples_html_mathjax3_custom_doc, "html-mathjax3-custom")
    ]
        @test isa(doc, Documenter.Documents.Document)

        let build_dir = joinpath(examples_root, "builds", name)
            @test joinpath(build_dir, "index.html") |> isfile
            @test joinpath(build_dir, "omitted", "index.html") |> isfile
            @test joinpath(build_dir, "hidden", "index.html") |> isfile
            @test joinpath(build_dir, "lib", "autodocs", "index.html") |> isfile
            @test joinpath(build_dir, "man", "style", "index.html") |> isfile

            # Test existence of some HTML elements
            man_style_html = String(read(joinpath(build_dir, "man", "style", "index.html")))
            @test occursin("is-category-myadmonition", man_style_html)
            @test occursin(Documenter.Writers.HTMLWriter.OUTDATED_VERSION_ATTR, man_style_html)

            index_html = read(joinpath(build_dir, "index.html"), String)
            @test occursin(Documenter.Writers.HTMLWriter.OUTDATED_VERSION_ATTR, index_html)
            @test occursin("documenter-example-output", index_html)
            @test occursin("1392-test-language", index_html)
            @test !occursin("1392-extra-info", index_html)

            example_output_html = read(joinpath(build_dir, "example-output", "index.html"), String)
            @test occursin("documenter-example-output", example_output_html)

            # Assets
            @test joinpath(build_dir, "assets", "documenter.js") |> isfile
            documenter_js = read(joinpath(build_dir, "assets", "documenter.js"), String)
            if name == "html-mathjax3"
                @test occursin("https://cdnjs.cloudflare.com/ajax/libs/mathjax/3", documenter_js)
            elseif name == "html-mathjax2-custom"
                @test occursin("https://cdn.jsdelivr.net/npm/mathjax@2/MathJax", documenter_js)
            elseif name == "html-mathjax3-custom"
                @test occursin("script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js';", documenter_js)
            else # name == "html", uses MathJax2
                @test occursin("https://cdnjs.cloudflare.com/ajax/libs/mathjax/2", documenter_js)
            end

            # This build includes erlang and erlang-repl highlighting
            documenterjs = String(read(joinpath(build_dir, "assets", "documenter.js")))
            @test occursin("languages/julia.min", documenterjs)
            @test occursin("languages/julia-repl.min", documenterjs)
            @test occursin("languages/erlang-repl.min", documenterjs)
            @test occursin("languages/erlang.min", documenterjs)
        end
    end

    @testset "HTML: local" begin
        doc = Main.examples_html_local_doc

        @test isa(doc, Documenter.Documents.Document)

        let build_dir = joinpath(examples_root, "builds", "html-local")

            index_html = read(joinpath(build_dir, "index.html"), String)
            @test occursin("<strong>bold</strong> output from MarkdownOnly", index_html)
            @test occursin("documenter-example-output", index_html)

            @test isfile(joinpath(build_dir, "index.html"))
            @test isfile(joinpath(build_dir, "omitted.html"))
            @test isfile(joinpath(build_dir, "hidden.html"))
            @test isfile(joinpath(build_dir, "lib", "autodocs.html"))

            # Assets
            @test joinpath(build_dir, "assets", "documenter.js") |> isfile
            documenterjs = String(read(joinpath(build_dir, "assets", "documenter.js")))
            @test occursin("languages/julia.min", documenterjs)
            @test occursin("languages/julia-repl.min", documenterjs)
        end
    end

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
        @test doc.user.format == [Documenter.Writers.MarkdownWriter.Markdown()]

        @test realpath(doc.internal.assets) == realpath(joinpath(dirname(@__FILE__), "..", "..", "assets"))

        @test length(doc.blueprint.pages) == 20

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

        @test length(doc.internal.objects) == 42
    end
end
