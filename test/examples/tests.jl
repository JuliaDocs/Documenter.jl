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

function latex_filename(doc::Documenter.Documents.Document)
    @test length(doc.user.format) == 1
    settings = first(doc.user.format)
    @test settings isa Documenter.LaTeX
    fileprefix = Documenter.Writers.LaTeXWriter.latex_fileprefix(doc, settings)
    return "$(fileprefix).tex"
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
            @test occursin(
                raw"<p>I will pay <span>$</span>1 if <span>$x^2$</span> is displayed correctly. People may also write <span>$</span>s or even money bag<span>$</span><span>$</span>.</p>",
                index_html,
            )

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

    @testset "HTML: repo-*" begin
        @test examples_html_repo_git_doc.user.remote === Remotes.GitHub("JuliaDocs", "Documenter.jl")
        @test examples_html_repo_gha_doc.user.remote === Remotes.GitHub("foo", "bar")
        @test examples_html_repo_travis_doc.user.remote === Remotes.GitHub("bar", "baz")
        @test examples_html_repo_nothing_doc.user.remote === nothing
        @test examples_html_repo_error_doc.user.remote === nothing
    end

    @testset "PDF/LaTeX: TeX only" begin
        doc = Main.examples_latex_texonly_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_texonly")
            filename = latex_filename(doc)
            @test joinpath(build_dir, filename) |> isfile
            @test joinpath(build_dir, "documenter.sty") |> isfile
        end
    end
end
