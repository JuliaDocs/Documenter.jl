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

# Diffing of output TeX files:
using Documenter.Utilities.TextDiff: Diff, Lines
function onormalize_tex(s)
    # We strip URLs and hyperlink hashes, since those may change over time
    s = replace(s, r"\\(href|hyperlink|hypertarget){[A-Za-z0-9#/_:.-]+}" => s"\\\1{}")
    # We also write the current Julia version into the TeX file
    s = replace(s, r"\\newcommand{\\JuliaVersion}{[A-Za-z0-9+.-]+}" => "\\newcommand{\\JuliaVersion}{}")
    # Remove CR parts of newlines, to make Windows happy
    s = replace(s, '\r' => "")
    return s
end
function printdiff(s1, s2)
    # We fall back: colordiff -> diff -> Documenter's TextDiff
    diff_cmd = Sys.which("colordiff")
    isnothing(diff_cmd) && (diff_cmd = Sys.which("diff"))
    if isnothing(diff_cmd)
        show(Diff{Lines}(s1, s2))
    else
        mktempdir() do path
            a, b = joinpath(path, "a"), joinpath(path, "b")
            write(a, s1); write(b, s2)
            run(ignorestatus(`$(diff_cmd) $a $b`))
        end
    end
end
function compare_files(a, b)
    a_str, b_str = read(a, String), read(b, String)
    a_str_normalized, b_str_normalized = onormalize_tex(a_str), onormalize_tex(b_str)
    a_str_normalized == b_str_normalized && return true
    @error "Generated files did not agree with reference, diff follows." a b
    printdiff(a_str_normalized, b_str_normalized)
    println('='^40, " end of diff ", '='^40)
    if haskey(ENV, "DOCUMENTER_FIXTESTS")
        @info "Updating reference file: $(b)"
        cp(a, b, force=true)
    end
    return false
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

<<<<<<< HEAD
    @testset "PDF/LaTeX: TeX only" begin
        doc = Main.examples_latex_texonly_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_texonly")
            @test joinpath(build_dir, latex_filename(doc)) |> isfile
            @test joinpath(build_dir, "documenter.sty") |> isfile
        end
    end

    @testset "PDF/LaTeX: simple (TeX only)" begin
        doc = Main.examples_latex_simple_texonly_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_simple_texonly")
            @test joinpath(build_dir, "documenter.sty") |> isfile
            texfile = joinpath(build_dir, latex_filename(doc))
            @test isfile(texfile)
            @test compare_files(texfile, joinpath(@__DIR__, "references", "latex_simple.tex"))
        end
    end

    @testset "PDF/LaTeX: showcase (TeX only)" begin
        doc = Main.examples_latex_showcase_texonly_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_showcase_texonly")
            @test joinpath(build_dir, "documenter.sty") |> isfile
            texfile = joinpath(build_dir, latex_filename(doc))
            @test isfile(texfile)
            @test compare_files(texfile, joinpath(@__DIR__, "references", "latex_showcase.tex"))
        end
    end

    @testset "CrossReferences" begin
        xref_file = joinpath(examples_root, "builds", "html", "xrefs", "index.html")
        @test isfile(xref_file)
        xref_file_html = read(xref_file, String)
        # Make sure that all the cross-reference links were updated:
        @test !occursin("@ref", xref_file_html)
    end
end
