module HTMLWriterTests

using Test
import MarkdownAST
using Documenter
using Documenter: DocSystem
using Documenter.HTMLWriter: HTMLWriter, generate_version_file, generate_redirect_file, expand_versions, _strip_latex_math_delimiters

function verify_version_file(versionfile, entries)
    @test isfile(versionfile)
    content = read(versionfile, String)
    idx = 1
    for entry in entries
        i = findnext(entry, content, idx)
        @test i !== nothing
        idx = last(i)
    end
    return
end

function verify_redirect_file(redirectfile, version)
    @test isfile(redirectfile)
    content = read(redirectfile, String)

    return @test occursin("url=./$(version)/", content)
end

@testset "HTMLWriter" begin
    @test isdir(HTMLWriter.ASSETS)
    @test isdir(HTMLWriter.ASSETS_SASS)
    @test isdir(HTMLWriter.ASSETS_THEMES)

    for theme in HTMLWriter.THEMES
        # catppuccin-* themes are templated based on a common catppuccin.scss source file
        scss = replace(theme, r"(?<=^catppuccin)-[a-z]+$" => "")
        @test isfile(joinpath(HTMLWriter.ASSETS_SASS, "$(scss).scss"))
        @test isfile(joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css"))
    end

    # asset handling
    function assetlink(src, asset)
        links = HTMLWriter.asset_links(src, [asset])
        @test length(links) == 1
        (; node = links[1], links[1].attributes...)
    end
    @test_logs (:error, "Absolute path '/foo' passed to asset_links") HTMLWriter.asset_links(
        "/foo", HTMLWriter.HTMLAsset[]
    )
    let asset = asset("https://example.com/foo.js")
        @test asset.uri == "https://example.com/foo.js"
        @test asset.class == :js
        @test asset.islocal === false
        link = assetlink("my/sub/page", asset)
        @test link.node.name === :script
        @test link.src == "https://example.com/foo.js"
    end
    let asset = asset("https://example.com/foo.js", islocal = false)
        @test asset.islocal === false
        link = assetlink("my/sub/page", asset)
        @test link.src == "https://example.com/foo.js"
    end
    let asset = asset("http://example.com/foo.js", class = :ico)
        @test asset.uri == "http://example.com/foo.js"
        @test asset.class == :ico
        @test asset.islocal === false
    end
    let asset = asset("foo/bar.css", islocal = true)
        @test asset.uri == "foo/bar.css"
        @test asset.class == :css
        @test asset.islocal === true
        link = assetlink("my/sub/page", asset)
        @test link.node.name === :link
        @test link.href == "../../foo/bar.css"
        link = assetlink("page.md", asset)
        @test link.href == "foo/bar.css"
        link = assetlink("foo/bar.md", asset)
        @test link.href == "bar.css"
    end
    @test_throws Exception asset("ftp://example.com/foo.js")
    @test_throws Exception asset("example.com/foo.js")
    @test_throws Exception asset("foo.js")
    @test_throws Exception asset("foo.js", islocal = false)
    @test_throws Exception asset("https://example.com/foo.js?q=1")
    @test_throws Exception asset("https://example.com/foo.js", class = :error)
    # Edge cases that do not actually quite work correctly:
    let asset = asset("https://example.com/foo.js", islocal = true)
        @test asset.uri == "https://example.com/foo.js"
        @test asset.islocal === true
        link = assetlink("my/sub/page", asset)
        @test link.node.name === :script
        # This actually leads to different results on Windows and Linux (on the former, it
        # gets treated as an absolute path).
        if Sys.iswindows()
            @test endswith(link.src, "example.com/foo.js")
        else
            @test link.src == "../../https:/example.com/foo.js"
        end

    end
    @test_logs (:error, "Local asset should not have an absolute URI: /foo/bar.ico") asset("/foo/bar.ico", islocal = true)

    let asset = asset("https://plausible.io/js/plausible.js"; class = :js, attributes = Dict(Symbol("data-domain") => "example.com", :defer => ""))
        @test asset.uri == "https://plausible.io/js/plausible.js"
        @test asset.class == :js
        @test asset.islocal === false
        link = assetlink("my/sub/page", asset)
        @test link.node.name === :script
        @test link.src == "https://plausible.io/js/plausible.js"
        @test Base.getproperty(link, Symbol("data-domain")) == "example.com"
        @test link.defer == ""
    end

    # HTML format object
    @test Documenter.HTML() isa Documenter.HTML
    @test_throws ArgumentError Documenter.HTML(collapselevel = -200)
    @test_throws Exception Documenter.HTML(assets = ["foo.js", 10])
    @test_throws ArgumentError Documenter.HTML(footer = "foo\n\nbar")
    @test_throws ArgumentError Documenter.HTML(footer = "# foo")
    @test_throws ArgumentError Documenter.HTML(footer = "")
    @test Documenter.HTML(footer = "foo bar [baz](https://github.com)") isa Documenter.HTML
    @test_throws ErrorException Documenter.HTML(edit_branch = nothing, edit_link = nothing)

    # MathEngine
    let katex = KaTeX()
        @test length(katex.config) == 1
        @test haskey(katex.config, :delimiters)
    end
    let katex = KaTeX(Dict(:foo => 1))
        @test length(katex.config) == 2
        @test haskey(katex.config, :delimiters)
        @test haskey(katex.config, :foo)
    end
    let katex = KaTeX(Dict(:delimiters => 1, :foo => 2))
        @test length(katex.config) == 2
        @test haskey(katex.config, :delimiters)
        @test katex.config[:delimiters] == 1
        @test haskey(katex.config, :foo)
    end

    let mathjax = MathJax2()
        @test length(mathjax.config) == 5
        @test haskey(mathjax.config, :tex2jax)
        @test haskey(mathjax.config, :config)
        @test haskey(mathjax.config, :jax)
        @test haskey(mathjax.config, :extensions)
        @test haskey(mathjax.config, :TeX)
    end
    let mathjax = MathJax2(Dict(:foo => 1))
        @test length(mathjax.config) == 6
        @test haskey(mathjax.config, :tex2jax)
        @test haskey(mathjax.config, :config)
        @test haskey(mathjax.config, :jax)
        @test haskey(mathjax.config, :extensions)
        @test haskey(mathjax.config, :TeX)
        @test haskey(mathjax.config, :foo)
    end
    let mathjax = MathJax2(Dict(:tex2jax => 1, :foo => 2))
        @test length(mathjax.config) == 6
        @test haskey(mathjax.config, :tex2jax)
        @test haskey(mathjax.config, :config)
        @test haskey(mathjax.config, :jax)
        @test haskey(mathjax.config, :extensions)
        @test haskey(mathjax.config, :TeX)
        @test haskey(mathjax.config, :foo)
        @test mathjax.config[:tex2jax] == 1
    end

    mktempdir() do tmpdir
        versionfile = joinpath(tmpdir, "versions.js")
        redirectfile = joinpath(tmpdir, "index.html")
        devurl = "dev"
        versions = [
            "stable", "dev",
            "2.1.1", "v2.1.0", "v2.0.1", "v2.0.0",
            "1.1.1", "v1.1.0", "v1.0.1", "v1.0.0",
            "0.1.1", "v0.1.0",
        ] # note no `v` on first ones

        # make dummy directories of versioned docs
        cd(tmpdir) do
            for version in versions
                mkdir(version)
            end
        end

        # case1: default versioning
        versions = ["stable" => "v^", "v#.#", "dev" => "dev"] # default to makedocs
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["stable", "v2.1", "v2.0", "v1.1", "v1.0", "v0.1", "dev"]
        @test symlinks == [
            "stable" => "2.1.1", "v2.1" => "2.1.1", "v2.0" => "v2.0.1",
            "v1.1" => "1.1.1", "v1.0" => "v1.0.1", "v0.1" => "0.1.1",
            "v2" => "2.1.1", "v1" => "1.1.1", "v2.1.1" => "2.1.1",
            "v1.1.1" => "1.1.1", "v0.1.1" => "0.1.1",
        ]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        generate_redirect_file(redirectfile, entries)
        verify_redirect_file(redirectfile, "stable")

        # case2: major released versions
        versions = ["v#"]
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["v2.1", "v1.1"]
        @test symlinks == [
            "v2.1" => "2.1.1", "v1.1" => "1.1.1", "v2" => "2.1.1", "v1" => "1.1.1",
            "v2.0" => "v2.0.1", "v1.0" => "v1.0.1", "v0.1" => "0.1.1",
            "v2.1.1" => "2.1.1", "v1.1.1" => "1.1.1", "v0.1.1" => "0.1.1",
        ]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        generate_redirect_file(redirectfile, entries)
        verify_redirect_file(redirectfile, "v2.1")

        # case3: all released versions
        versions = ["v#.#.#"]
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == [
            "v2.1.1", "v2.1.0", "v2.0.1", "v2.0.0", "v1.1.1", "v1.1.0",
            "v1.0.1", "v1.0.0", "v0.1.1", "v0.1.0",
        ]
        @test symlinks == [
            "v2.1.1" => "2.1.1", "v1.1.1" => "1.1.1", "v0.1.1" => "0.1.1",
            "v2" => "2.1.1", "v1" => "1.1.1", "v2.1" => "2.1.1",
            "v2.0" => "v2.0.1", "v1.1" => "1.1.1", "v1.0" => "v1.0.1", "v0.1" => "0.1.1",
        ]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        generate_redirect_file(redirectfile, entries)
        verify_redirect_file(redirectfile, "v2.1.1")

        # case4: invalid versioning
        versions = ["v^", "devel" => "dev", "foobar", "foo" => "bar"]
        entries, symlinks = @test_logs(
            (:warn, "no match for `versions` entry `\"foobar\"`"),
            (:warn, "no match for `versions` entry `\"foo\" => \"bar\"`"),
            expand_versions(tmpdir, versions)
        )
        @test entries == ["v2.1", "devel"]
        @test ("v2.1" => "2.1.1") in symlinks
        @test ("devel" => "dev") in symlinks
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        generate_redirect_file(redirectfile, entries)
        verify_redirect_file(redirectfile, "v2.1")

        # case5: invalid versioning
        versions = ["stable" => "v^", "dev" => "stable"]
        @test_throws ArgumentError expand_versions(tmpdir, versions)

        # case6: default versioning (no released version)
        cd(tmpdir) do
            # remove dummy directories
            for dir in readdir(tmpdir)
                rm(dir)
            end
            mkdir("dev")
        end
        versions = ["stable" => "v^", "v#.#", "dev" => "dev"] # default to makedocs
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["dev"]
        @test symlinks == []
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        generate_redirect_file(redirectfile, entries)
        verify_redirect_file(redirectfile, "dev")

        # Case 7: no entries
        entries = String[]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)
        rm(redirectfile)
        generate_redirect_file(redirectfile, entries)
        @test !isfile(redirectfile)
    end

    @testset "HTML: size_threshold" begin
        @test_throws ArgumentError Documenter.HTML(size_threshold = 0)
        @test_throws ArgumentError Documenter.HTML(size_threshold = -100)
        @test_throws ArgumentError Documenter.HTML(size_threshold_warn = 0)
        @test_throws ArgumentError Documenter.HTML(size_threshold_warn = -100)
        @test_throws ArgumentError Documenter.HTML(size_threshold = -100, size_threshold_warn = -100)
        @test_throws ArgumentError Documenter.HTML(size_threshold = 1, size_threshold_warn = 2)
        # Less than size_threshold_warn:
        @test_throws ArgumentError Documenter.HTML(size_threshold = 1)

        html = Documenter.HTML()
        @test html.size_threshold == 200 * 2^10
        @test html.size_threshold_warn == 100 * 2^10

        html = Documenter.HTML(size_threshold = nothing)
        @test html.size_threshold == typemax(Int)
        @test html.size_threshold_warn == 100 * 2^10

        html = Documenter.HTML(size_threshold = nothing, size_threshold_warn = 1234)
        @test html.size_threshold == typemax(Int)
        @test html.size_threshold_warn == 1234

        html = Documenter.HTML(size_threshold_warn = nothing)
        @test html.size_threshold == 200 * 2^10
        @test html.size_threshold_warn == 200 * 2^10

        html = Documenter.HTML(size_threshold = 1234, size_threshold_warn = nothing)
        @test html.size_threshold == 1234
        @test html.size_threshold_warn == 1234

        html = Documenter.HTML(size_threshold = 12345, size_threshold_warn = 1234)
        @test html.size_threshold == 12345
        @test html.size_threshold_warn == 1234
    end

    @testset "HTML: format_units" begin
        @test HTMLWriter.format_units(0) == "0.0 (bytes)"
        @test HTMLWriter.format_units(1) == "1.0 (bytes)"
        @test HTMLWriter.format_units(1023) == "1023.0 (bytes)"
        @test HTMLWriter.format_units(1024) == "1.0 (KiB)"
        @test HTMLWriter.format_units(4000) == "3.91 (KiB)"
        @test HTMLWriter.format_units(2^20 + 123) == "1.0 (MiB)"
        @test HTMLWriter.format_units(typemax(Int)) == "(no limit)"
    end

    @testset "HTML: _strip_latex_math_delimiters" begin
        for content in [
                "a",
                "x_1",
                "x_{1} + x_{2}",
                "\\begin{array}x_1\\\nx_2\\end{array}",
            ]
            for (left, right) in [("\\[", "\\]"), ("\$", "\$"), ("\$\$", "\$\$")]
                for (input, output) in [
                        content => (false, content),
                        "$left$content$right" => (true, content),
                        " $left$content$right" => (true, content),
                        "$left$content$right " => (true, content),
                        "\t$left$content$right  " => (true, content),
                        " \t$left$content$right\t\t" => (true, content),
                    ]
                    @test _strip_latex_math_delimiters(input) == output
                end
            end
            # Test that miss-matched delimiters are not treated as math
            # delimiters
            for (left, right) in [
                    ("\\[", ""),
                    ("\$", ""),
                    ("\$\$", ""),
                    ("", "\\]"),
                    ("", "\$"),
                    ("", "\$\$"),
                    ("\$", "\\]"),
                    ("\$\$", "\$"),
                    ("\$", "\$\$"),
                ]
                for input in [
                        content,
                        "$left$content$right",
                        " $left$content$right",
                        "$left$content$right ",
                        "\t$left$content$right  ",
                        " \t$left$content$right\t\t",
                    ]
                    @test _strip_latex_math_delimiters(input) == (false, input)
                end
            end
        end
    end

end

end
