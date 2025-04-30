using Test
import JSON
using DocInventories: DocInventories, Inventory
import Base64

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

function latex_filename(doc::Documenter.Documenter.Document)
    @test length(doc.user.format) == 1
    settings = first(doc.user.format)
    @test settings isa Documenter.LaTeX
    fileprefix = Documenter.LaTeXWriter.latex_fileprefix(doc, settings)
    return "$(fileprefix).tex"
end

# Diffing of output TeX files:
using Documenter.TextDiff: Diff, Lines
function onormalize_tex(s)
    # We strip hyperlink hashes, since those may change over time
    s = replace(s, r"\\(hyperlink|hypertarget|label|hyperlinkref){[0-9]+}" => s"\\\1{}")
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
    return if isnothing(diff_cmd)
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
    if haskey(ENV, "DOCUMENTER_FIXTESTS")
        @info "Updating reference file: $(b)"
        cp(a, b, force = true)
    end
    a_str, b_str = read(a, String), read(b, String)
    a_str_normalized, b_str_normalized = onormalize_tex(a_str), onormalize_tex(b_str)
    a_str_normalized == b_str_normalized && return true
    @error "Generated files did not agree with reference, diff follows." a b
    printdiff(a_str_normalized, b_str_normalized)
    println('='^40, " end of diff ", '='^40)
    return false
end

all_md_files_in_src = let srcdir = joinpath(@__DIR__, "src"), mdfiles = String[]
    for (root, _, pages) in walkdir(srcdir)
        rootdir = relpath(root, srcdir)
        rootdir == "." && (rootdir = "")
        for page in pages
            endswith(page, ".md") || continue
            push!(mdfiles, joinpath(rootdir, page))
        end
    end
    mdfiles
end
@test length(all_md_files_in_src) == 29

@testset "Examples" begin
    @testset "HTML: deploy/$name" for (doc, name) in [
            (Main.examples_html_doc, "html"),
            (Main.examples_html_meta_custom_doc, "html-meta-custom"),
            (Main.examples_html_mathjax2_custom_doc, "html-mathjax2-custom"),
            (Main.examples_html_mathjax3_doc, "html-mathjax3"),
            (Main.examples_html_mathjax3_custom_doc, "html-mathjax3-custom"),
        ]
        @test isa(doc, Documenter.Documenter.Document)

        let build_dir = joinpath(examples_root, "builds", name)
            # Make sure that each .md file has a corresponding generated HTML file
            @testset "md: $mdfile" for mdfile in all_md_files_in_src
                dir, filename = splitdir(mdfile)
                filename, _ = splitext(filename)
                htmlpath = (filename == "index") ? joinpath(build_dir, dir, "index.html") :
                    joinpath(build_dir, dir, filename, "index.html")
                @test isfile(htmlpath)
            end

            # Test existence of some HTML elements
            man_style_html = String(read(joinpath(build_dir, "man", "style", "index.html")))
            @test occursin("is-category-myadmonition", man_style_html)
            @test occursin(Documenter.HTMLWriter.OUTDATED_VERSION_ATTR, man_style_html)

            index_html = read(joinpath(build_dir, "index.html"), String)
            @test occursin(Documenter.HTMLWriter.OUTDATED_VERSION_ATTR, index_html)
            @test occursin("documenter-example-output", index_html)
            @test occursin("1392-test-language", index_html)
            @test !occursin("1392-extra-info", index_html)
            @test occursin(
                raw"<p>I will pay <span>$</span>1 if <span>$x^2$</span> is displayed correctly. People may also write <span>$</span>s or even money bag<span>$</span><span>$</span>.</p>",
                index_html,
            )

            example_output_html = read(joinpath(build_dir, "example-output", "index.html"), String)
            @test occursin("documenter-example-output", example_output_html)

            # Test for existence of meta tags
            @test occursin("<meta property=\"og:title\"", index_html)
            @test occursin("<meta property=\"twitter:title\"", index_html)
            @test occursin("<meta property=\"og:url\" content=\"https://example.com/stable/\"/>", index_html)
            @test occursin("<meta property=\"twitter:url\" content=\"https://example.com/stable/\"/>", index_html)
            if name == "html-meta-custom"
                @test occursin("<meta name=\"description\" content=\"Example site-wide description.\"/>", index_html)
                @test occursin("<meta property=\"og:description\" content=\"Example site-wide description.\"/>", index_html)
                @test occursin("<meta property=\"twitter:description\" content=\"Example site-wide description.\"/>", index_html)
                @test occursin("<meta property=\"og:image\" content=\"https://example.com/stable/assets/preview.png\"/>", index_html)
                @test occursin("<meta property=\"twitter:image\" content=\"https://example.com/stable/assets/preview.png\"/>", index_html)
                @test occursin("<meta property=\"twitter:card\" content=\"summary_large_image\"/>", index_html)
            else
                @test occursin("<meta name=\"description\" content=\"Documentation for Documenter example.\"/>", index_html)
                @test occursin("<meta property=\"og:description\" content=\"Documentation for Documenter example.\"/>", index_html)
                @test occursin("<meta property=\"twitter:description\" content=\"Documentation for Documenter example.\"/>", index_html)
                @test !occursin("<meta property=\"og:image\"", index_html)
                @test !occursin("<meta property=\"twitter:image\"", index_html)
                @test !occursin("<meta property=\"twitter:card\"", index_html)
            end

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

            # Issue 491
            @test isfile(joinpath(build_dir, "issue491", "index.html"))
            issue_491 = read(joinpath(build_dir, "issue491", "index.html"), String)

            @test occursin("julia&gt; item", issue_491)
            @test occursin("julia&gt; item_item", issue_491)
            @test occursin("julia&gt; admonition", issue_491)
            @test occursin("julia&gt; admonition_blockquote", issue_491)

            @test occursin("expanded_eval", issue_491)
            @test occursin("expanded_example", issue_491)
            @test occursin("expanded_setup", issue_491)
            @test occursin("<p>expanded_raw</p>", issue_491)

            # CollapsedDocStrings
            if name == "html"
                # The `index.md` page does not have `CollapsedDocStrings` in
                # its `@meta` block, ...
                @test !occursin("<div data-docstringscollapsed=\"true\">", index_html)
                # but the `lib/functions.md` page does, ...
                functions_html = read(joinpath(build_dir, "lib", "functions", "index.html"), String)
                # so it should have the JS that clicks the toggle button.
                @test occursin("<div data-docstringscollapsed=\"true\">", functions_html)
            end

            # .documenter-siteinfo.json
            @testset ".documenter-siteinfo.json" begin
                siteinfo_json_file = joinpath(build_dir, ".documenter-siteinfo.json")
                @test isfile(siteinfo_json_file)
                siteinfo_json = JSON.parse(read(siteinfo_json_file, String))
                @test haskey(siteinfo_json, "documenter")
                @test siteinfo_json["documenter"] isa Dict
                @test haskey(siteinfo_json["documenter"], "documenter_version")
                @test haskey(siteinfo_json["documenter"], "julia_version")
                @test haskey(siteinfo_json["documenter"], "generation_timestamp")
            end

            # inventory
            @testset "inventory" begin
                objects_inv = joinpath(build_dir, "objects.inv")
                @test isfile(objects_inv)
                if isfile(objects_inv)
                    inv = Inventory(objects_inv; root_url = "")
                    @test inv.project == "Documenter example"
                    if name == "html"
                        @test inv.version == "$(Documenter.DOCUMENTER_VERSION)+test"
                        @test length(inv("Anonymous function declaration")) == 1
                        if length(inv("Anonymous function declaration")) == 1
                            item = inv("Anonymous function declaration")[1]
                            @test item.domain == "std"
                            @test item.role == "label"
                            @test item.dispname == "Anonymous function declaration"
                            @test item.name == "Anonymous-function-declaration"
                            @test item.uri == "#\$"
                            @test item.priority == -1
                            @test DocInventories.uri(item) == "#Anonymous-function-declaration"
                        end
                        item = inv[":std:label:`xreftarget`"]
                        @test !isnothing(item)
                        if !isnothing(item)
                            @test item.name == "xreftarget"
                            @test item.dispname == "X-ref target with id"
                            @test DocInventories.uri(item) == "xrefs/#xreftarget"
                        end
                        item = inv[":std:label:`Markdown-files-with-spaces`"]
                        @test !isnothing(item)
                        if !isnothing(item)
                            @test item.name == "Markdown-files-with-spaces"
                            @test item.dispname == "Markdown files with spaces"
                            @test item.uri == "man/page%20with%20space/#\$"
                            @test DocInventories.uri(item) == "man/page%20with%20space/#Markdown-files-with-spaces"
                        end
                        @test length(inv(":doc:`man/style`")) == 1
                        if length(inv(":doc:`man/style`")) == 1
                            item = inv(":doc:`man/style`")[1]
                            @test item.domain == "std"
                            @test item.role == "doc"
                            @test item.dispname == "Style demos"
                            @test item.name == "man/style"
                            @test item.uri == "man/style/"
                            @test item.priority == -1
                            @test DocInventories.uri(item) == "man/style/"
                        end
                        item = inv[":std:doc:`man/page with space`"]
                        @test !isnothing(item)
                        if !isnothing(item)
                            @test item.name == "man/page with space"
                            @test item.dispname == "Markdown files with spaces"
                            @test item.uri == "man/page%20with%20space/"
                            @test DocInventories.uri(item) == "man/page%20with%20space/"
                        end
                        jl_roles = Set(item.role for item in inv if item.domain == "jl")
                        @test jl_roles == Set(
                            [
                                "constant",
                                "keyword",
                                "function",
                                "method",
                                "macro",
                                "module",
                                "type",
                            ]
                        )
                        @test length(inv(":jl:constant:`Main.AutoDocs.K`")) == 1
                        if length(inv(":jl:constant:`Main.AutoDocs.K`")) == 1
                            item = inv[":jl:constant:`Main.AutoDocs.K`"]
                            @test item.domain == "jl"
                            @test item.role == "constant"
                            @test item.name == "Main.AutoDocs.K"
                            @test item.uri == "lib/functions/#\$"
                            @test item.priority == 1
                            @test DocInventories.uri(item) == "lib/functions/#Main.AutoDocs.K"
                        end
                        @test length(inv(":jl:keyword:`for`")) == 1
                        if length(inv(":jl:keyword:`for`")) == 1
                            item = inv[":jl:keyword:`for`"]
                            @test item.domain == "jl"
                            @test item.role == "keyword"
                            @test item.name == "for"
                            @test item.uri == "lib/functions/#\$"
                            @test item.priority == 1
                            @test DocInventories.uri(item) == "lib/functions/#for"
                        end
                        @test length(inv("Documenter.hide")) == 1
                        if length(inv("Documenter.hide")) == 1
                            item = inv("Documenter.hide")[1]
                            @test item.domain == "jl"
                            @test item.role == "function"
                            @test item.name == "Documenter.hide"
                            @test item.uri == "hidden/#\$"
                            @test item.priority == 1
                            @test DocInventories.uri(item) == "hidden/#Documenter.hide"
                        end
                        @test length(inv("AutoDocs.Pages.f-Tuple{Any, Any, Any}")) == 1
                        if length(inv("AutoDocs.Pages.f-Tuple{Any, Any, Any}")) == 1
                            item = inv("AutoDocs.Pages.f-Tuple{Any, Any, Any}")[1]
                            @test item.domain == "jl"
                            @test item.role == "method"
                            @test item.name == "Main.AutoDocs.Pages.f-Tuple{Any, Any, Any}"
                            @test item.uri == "lib/functions/#Main.AutoDocs.Pages.f-Tuple%7BAny%2C%20Any%2C%20Any%7D"
                            @test item.priority == 1
                        end
                        @test length(inv(".A.@m")) == 1
                        if length(inv(".A.@m")) == 1
                            item = inv(".A.@m")[1]
                            @test item.domain == "jl"
                            @test item.role == "macro"
                            @test item.name == "Main.AutoDocs.A.@m-Tuple{}"
                            @test item.uri == "lib/functions/#Main.AutoDocs.A.%40m-Tuple%7B%7D"
                            @test item.priority == 1
                        end
                        @test length(inv(":module:`AutoDocs`")) == 1
                        if length(inv(":module:`AutoDocs`")) == 1
                            item = inv(":module:`AutoDocs`")[1]
                            @test item.domain == "jl"
                            @test item.role == "module"
                            @test item.name == "AutoDocs"
                            @test item.uri == "lib/functions/#\$"
                            @test item.priority == 1
                            @test DocInventories.uri(item) == "lib/functions/#AutoDocs"
                        end
                        @test length(inv("AutoDocs.T")) == 1
                        if length(inv("AutoDocs.T")) == 1
                            item = inv("AutoDocs.T")[1]
                            @test item.domain == "jl"
                            @test item.role == "type"
                            @test item.name == "Main.AutoDocs.T"
                            @test item.uri == "lib/functions/#\$"
                            @test item.priority == 1
                            @test DocInventories.uri(item) == "lib/functions/#Main.AutoDocs.T"
                        end
                    end
                end
            end

            @testset "at-example outputs: $fmt/$size" for ((fmt, size), data) in AT_EXAMPLE_FILES
                if size === :tiny
                    encoded_data = Base64.base64encode(data.bytes)
                    @test occursin(encoded_data, read(joinpath(build_dir, "index.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "example-output", "index.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "outputs", "index.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "outputs", "outputs", "index.html"), String))
                else # size === :big
                    # From src/index.md
                    @test isfile(joinpath(build_dir, "index-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "index-$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/example-output.md
                    @test isfile(joinpath(build_dir, "example-output", "$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "example-output", "$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/outputs/index.md
                    @test isfile(joinpath(build_dir, "outputs", "index-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "outputs", "index-$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/outputs/outputs.md
                    @test isfile(joinpath(build_dir, "outputs", "outputs", "$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "outputs", "outputs", "$(data.hash_slug).$(fmt)")) == data.bytes
                end
            end
            # SVG on src/example-output.md
            @test isfile(joinpath(build_dir, "example-output", "$(SVG_BIG.hash_slug).svg"))
            @test read(joinpath(build_dir, "example-output", "$(SVG_BIG.hash_slug).svg")) == SVG_BIG.bytes
            # SVG on src/example-output.md, from Main.SVG_MULTI
            @test isfile(joinpath(build_dir, "example-output", "$(SVG_BIG.hash_slug)-001.svg"))
            @test read(joinpath(build_dir, "example-output", "$(SVG_BIG.hash_slug).svg")) == SVG_BIG.bytes
            # .. but, crucially, Main.SVG_HTML did _not_ get written out.
            @test !isfile(joinpath(build_dir, "example-output", "$(SVG_BIG.hash_slug)-002.svg"))
        end

        # Testing linkcheck_useragent default
        @test doc.user.linkcheck_useragent == Documenter._LINKCHECK_DEFAULT_USERAGENT
    end

    @testset "HTML: local" begin
        doc = Main.examples_html_local_doc

        @test isa(doc, Documenter.Documenter.Document)

        let build_dir = joinpath(examples_root, "builds", "html-local")

            index_html = read(joinpath(build_dir, "index.html"), String)
            @test occursin("<strong>bold</strong> output from MarkdownOnly", index_html)
            @test occursin("documenter-example-output", index_html)

            # Make sure that each .md file has a corresponding generated HTML file
            @testset "md: $mdfile" for mdfile in all_md_files_in_src
                dir, filename = splitdir(mdfile)
                filename, _ = splitext(filename)
                htmlpath = joinpath(build_dir, dir, "$(filename).html")
                @test isfile(htmlpath)
            end

            # Assets
            @test joinpath(build_dir, "assets", "documenter.js") |> isfile
            documenterjs = String(read(joinpath(build_dir, "assets", "documenter.js")))
            @test occursin("languages/julia.min", documenterjs)
            @test occursin("languages/julia-repl.min", documenterjs)

            @testset "at-example outputs: $fmt/$size" for ((fmt, size), data) in AT_EXAMPLE_FILES
                if size === :tiny
                    encoded_data = Base64.base64encode(data.bytes)
                    @test occursin(encoded_data, read(joinpath(build_dir, "index.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "example-output.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "outputs", "index.html"), String))
                    @test occursin(encoded_data, read(joinpath(build_dir, "outputs", "outputs.html"), String))
                else # size === :big
                    # From src/index.md
                    @test isfile(joinpath(build_dir, "index-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "index-$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/example-output.md
                    @test isfile(joinpath(build_dir, "example-output-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "example-output-$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/outputs/index.md
                    @test isfile(joinpath(build_dir, "outputs", "index-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "outputs", "index-$(data.hash_slug).$(fmt)")) == data.bytes
                    # From src/outputs/outputs.md
                    @test isfile(joinpath(build_dir, "outputs", "outputs-$(data.hash_slug).$(fmt)"))
                    @test read(joinpath(build_dir, "outputs", "outputs-$(data.hash_slug).$(fmt)")) == data.bytes
                end
            end
            # SVG on src/example-output.md
            @test isfile(joinpath(build_dir, "example-output-$(SVG_BIG.hash_slug).svg"))
            @test read(joinpath(build_dir, "example-output-$(SVG_BIG.hash_slug).svg")) == SVG_BIG.bytes
            # SVG on src/example-output.md, from Main.SVG_MULTI
            @test isfile(joinpath(build_dir, "example-output-$(SVG_BIG.hash_slug)-001.svg"))
            @test read(joinpath(build_dir, "example-output-$(SVG_BIG.hash_slug).svg")) == SVG_BIG.bytes
            # .. but, crucially, Main.SVG_HTML did _not_ get written out.
            @test !isfile(joinpath(build_dir, "example-output-$(SVG_BIG.hash_slug)-002.svg"))
        end

        # It doesn't actually test that the user agent was used correctly, but at least it tests that
        # the option go set.
        @test doc.user.linkcheck_useragent == "Documenter/1"
    end

    @testset "HTML: pagesonly" begin
        doc = Main.examples_html_pagesonly_doc

        @test isa(doc, Documenter.Documenter.Document)

        let build_dir = joinpath(examples_root, "builds", "html-pagesonly")
            # Make sure that each .md file has a corresponding generated HTML file
            @testset "md: $mdfile" for mdfile in all_md_files_in_src
                dir, filename = splitdir(mdfile)
                filename, _ = splitext(filename)
                htmlpath = (filename == "index") ? joinpath(build_dir, dir, "index.html") :
                    joinpath(build_dir, dir, filename, "index.html")
                if mdfile ∈ ("index.md", joinpath("man", "tutorial.md"), joinpath("man", "style.md"))
                    @test isfile(htmlpath)
                else
                    @test !ispath(htmlpath)
                end
            end

            # Assets
            @test joinpath(build_dir, "assets", "documenter.js") |> isfile
            documenterjs = String(read(joinpath(build_dir, "assets", "documenter.js")))
            @test occursin("languages/julia.min", documenterjs)
            @test occursin("languages/julia-repl.min", documenterjs)
        end
    end

    @testset "HTML: repo-*" begin
        @test examples_html_repo_git_doc.user.remote === Remotes.GitHub("JuliaDocs", "Documenter.jl")
        @test examples_html_repo_nothing_doc.user.remote === nothing
        @test examples_html_repo_error_doc.user.remote === nothing
    end

    @testset "HTML: sizethreshold" begin
        @test examples_html_sizethreshold_defaults_fail_doc isa Documenter.HTMLWriter.HTMLSizeThresholdError
        @test examples_html_sizethreshold_success_doc isa Documenter.Document
        @test examples_html_sizethreshold_ignore_success_doc isa Documenter.Document
        @test examples_html_sizethreshold_override_fail_doc isa Documenter.HTMLWriter.HTMLSizeThresholdError
        @test examples_html_sizethreshold_ignore_success_doc isa Documenter.Document
        @test examples_html_sizethreshold_ignore_fail_doc isa Documenter.HTMLWriter.HTMLSizeThresholdError
    end

    @testset "PDF/LaTeX: TeX only" begin
        doc = Main.examples_latex_texonly_doc
        @test isa(doc, Documenter.Documenter.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_texonly")
            @test joinpath(build_dir, latex_filename(doc)) |> isfile
            @test joinpath(build_dir, "documenter.sty") |> isfile
        end
    end

    @testset "PDF/LaTeX: simple (TeX only)" begin
        doc = Main.examples_latex_simple_texonly_doc
        @test isa(doc, Documenter.Documenter.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_simple_texonly")
            @test joinpath(build_dir, "documenter.sty") |> isfile
            texfile = joinpath(build_dir, latex_filename(doc))
            @test isfile(texfile)
            @test compare_files(texfile, joinpath(@__DIR__, "references", "latex_simple.tex"))
        end
    end

    @testset "PDF/LaTeX: showcase (TeX only)" begin
        doc = Main.examples_latex_showcase_texonly_doc
        @test isa(doc, Documenter.Documenter.Document)
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
