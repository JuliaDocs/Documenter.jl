module TypstWriterTests

using Test
using Documenter
using Documenter.TypstWriter:
    TypstWriter,
    escape_for_typst_string,
    typstesc,
    typstescstr,
    writer_supports_ansicolor

# ============================================================================
# Test Helpers
# ============================================================================

"""
    render_to_typst(markdown::String; sitename="Test", pages=["index.md"]) -> String

Render markdown to Typst and return the body content (without preamble).
This is the core testing primitive for verifying Typst output.

# Example
```julia
output = render_to_typst("Hello **world**!")
@test contains(output, "#strong([world])")
```
"""
function render_to_typst(markdown::String; sitename = "Test", pages = ["index.md"])
    return mktempdir() do dir
        srcdir = joinpath(dir, "src")
        mkpath(srcdir)
        write(joinpath(srcdir, "index.md"), markdown)

        makedocs(
            root = dir,
            source = "src",
            build = "build",
            sitename = sitename,
            format = Documenter.Typst(platform = "none"),
            pages = pages,
            doctest = false,
            remotes = nothing,
        )

        # Read generated .typ file
        typfile = joinpath(dir, "build", "$(replace(sitename, " " => "")).typ")
        content = read(typfile, String)

        # Extract body (skip preamble)
        return extract_typst_body(content)
    end
end

"""
    extract_typst_body(content::String) -> String

Extract the body content from a Typst file, removing the preamble.
"""
function extract_typst_body(content::String)
    lines = split(content, '\n')

    # Find where preamble ends (look for closing paren of documenter(...))
    preamble_end = findfirst(i -> strip(lines[i]) == ")", eachindex(lines))
    body_start = preamble_end === nothing ? 1 : preamble_end + 1

    # Skip empty lines after preamble
    while body_start <= length(lines) && isempty(strip(lines[body_start]))
        body_start += 1
    end

    return join(lines[body_start:end], '\n')
end

# ============================================================================
# Unit Tests - Pure Functions (no makedocs dependencies)
# ============================================================================

@testset "Typst Backend" begin
    @testset "Utility Functions" begin
        @testset "escape_for_typst_string" begin
            @test escape_for_typst_string("test") == "test"
            @test escape_for_typst_string("test\"quote\"") == "test\\\"quote\\\""
            @test escape_for_typst_string("C:\\path\\file.txt") == "C:\\\\path\\\\file.txt"
            @test escape_for_typst_string("\\\\") == "\\\\\\\\"
            @test escape_for_typst_string("\"\"") == "\\\"\\\""
            # Edge cases
            @test escape_for_typst_string("") == ""
            @test escape_for_typst_string("no special chars") == "no special chars"
        end

        @testset "typstesc and typstescstr" begin
            # typstesc - for content
            @test typstesc("@#*_\$/`<>") == "\\@\\#\\*\\_\\\$\\/\\`\\<\\>"
            @test typstesc("normal text") == "normal text"
            @test typstesc("") == ""

            # typstescstr - for string literals (only escapes " and \)
            @test typstescstr("\"\\") == "\\\"\\\\"
            # These should NOT be escaped in string context
            @test typstescstr("@#*_\$/`<>") == "@#*_\$/`<>"
            @test typstescstr("normal text") == "normal text"
            @test typstescstr("") == ""
        end
    end

    @testset "Format Options" begin
        @test Documenter.Typst(platform = "native").platform == "native"
        @test Documenter.Typst(platform = "typst").platform == "typst"
        @test Documenter.Typst(platform = "docker").platform == "docker"
        @test Documenter.Typst(platform = "none").platform == "none"

        @test_throws ArgumentError Documenter.Typst(platform = "invalid")

        @test Documenter.Typst(version = "1.0.0").version == "1.0.0"
        @test Documenter.Typst().version == get(ENV, "TRAVIS_TAG", "")

        # Test ANSI color support
        @test writer_supports_ansicolor(Documenter.Typst()) == false
    end

    @testset "Compiler Selection" begin
        @test TypstWriter.get_compiler(Documenter.Typst(platform = "native")) isa
            TypstWriter.NativeCompiler
        @test TypstWriter.get_compiler(Documenter.Typst(platform = "typst")) isa
            TypstWriter.TypstJllCompiler
        @test TypstWriter.get_compiler(Documenter.Typst(platform = "docker")) isa
            TypstWriter.DockerCompiler
        @test TypstWriter.get_compiler(Documenter.Typst(platform = "none")) isa
            TypstWriter.NoOpCompiler
    end

    # ============================================================================
    # Precise AST Rendering Tests (using render_to_typst helper)
    # ============================================================================

    @testset "Precise AST Rendering" begin
        @testset "Inline Formatting" begin
            output = render_to_typst("**bold text**")
            @test contains(output, "#strong([bold text])")

            output = render_to_typst("*italic text*")
            @test contains(output, "#emph([italic text])")

            output = render_to_typst("`inline code`")
            @test contains(output, "#raw(\"inline code\"")
            @test contains(output, "block: false")

            # Combined formatting
            output = render_to_typst("**bold** and *italic* and `code`")
            @test contains(output, "#strong([bold])")
            @test contains(output, "#emph([italic])")
            @test contains(output, "#raw(\"code\"")
        end

        @testset "Headings" begin
            output = render_to_typst("# Level 1\n\n## Level 2\n\n### Level 3")
            @test contains(output, "extended_heading")
            @test contains(output, "Level 1")
            @test contains(output, "Level 2")
            @test contains(output, "Level 3")
        end

        @testset "Paragraphs" begin
            output = render_to_typst("First paragraph.\n\nSecond paragraph.")
            lines = filter(!isempty, split(output, '\n'))
            @test length(lines) >= 2
        end

        @testset "Code Blocks" begin
            # Julia code
            output = render_to_typst("```julia\nx = 1 + 1\n```")
            @test contains(output, "#raw(")
            @test contains(output, "block: true")
            @test contains(output, "lang: \"julia\"")
            @test contains(output, "x = 1 + 1")

            # No language specified
            output = render_to_typst("```\nplain text\n```")
            @test contains(output, "lang: \"text\"")

            # julia-repl should map to julia
            output = render_to_typst("```julia-repl\njulia> 1+1\n```")
            @test contains(output, "lang: \"julia\"")
        end

        @testset "Math - LaTeX" begin
            # Display math
            output = render_to_typst("```math\n\\sum_{i=1}^n i\n```")
            @test contains(output, "#mitex(")
            @test contains(output, "\\\\sum_{i=1}^n i")

            # Inline math
            output = render_to_typst("Inline ``\\alpha + \\beta`` math")
            @test contains(output, "#mi(")
            @test contains(output, "\\\\alpha + \\\\beta")  # Double-escaped in Typst string
        end

        @testset "Math - Native Typst" begin
            output = render_to_typst("```math typst\nsum_(i=1)^n i\n```")
            @test contains(output, "\$\nsum_(i=1)^n i\n\$")
            @test !contains(output, "#mitex")
        end

        @testset "Lists" begin
            # Unordered list
            output = render_to_typst("- Item 1\n- Item 2\n- Item 3")
            @test contains(output, "- Item 1")
            @test contains(output, "- Item 2")
            @test contains(output, "- Item 3")

            # Ordered list
            output = render_to_typst("1. First\n2. Second\n3. Third")
            @test contains(output, "+ First")
            @test contains(output, "+ Second")
            @test contains(output, "+ Third")

            # Nested lists
            output = render_to_typst("- Level 1\n  - Level 2\n    - Level 3")
            @test count(c -> c == '-', output) >= 3
        end

        @testset "Block Quote" begin
            output = render_to_typst("> This is a quote\n> Multiple lines")
            @test contains(output, "#quote(block: true)[")
            @test contains(output, "This is a quote")
        end

        @testset "Thematic Break" begin
            output = render_to_typst("Text above\n\n---\n\nText below")
            @test contains(output, "#line(length: 100%)")
        end

        @testset "Admonitions" begin
            for category in ["note", "warning", "danger", "info", "tip", "compat"]
                output = render_to_typst("!!! $category \"Title\"\n    Content")
                @test contains(output, "#admonition(type: \"$category\"")
                @test contains(output, "title: \"Title\"")
                @test contains(output, "Content")
            end

            # Unknown category should default to "default"
            output = render_to_typst("!!! custom \"Title\"\n    Content")
            @test contains(output, "#admonition(type: \"default\"")
        end

        @testset "Tables" begin
            output = render_to_typst(
                """
                | A | B | C |
                |---|---|---|
                | 1 | 2 | 3 |
                | 4 | 5 | 6 |
                """
            )
            @test contains(output, "#table(")
            @test contains(output, "align(center)")
            @test contains(output, "columns:")
            # Check content is present
            for num in ["1", "2", "3", "4", "5", "6"]
                @test contains(output, num)
            end
        end

        @testset "Footnotes" begin
            output = render_to_typst(
                """
                Text with footnote[^1].

                [^1]: Footnote content here
                """
            )
            @test contains(output, "#footnote[")
            @test contains(output, "Footnote content here")
        end

        @testset "Links - External" begin
            output = render_to_typst("[Link text](https://example.com)")
            @test contains(output, "#link(\"https://example.com\")")
            @test contains(output, "Link text")
        end

        @testset "Special Characters" begin
            # Test escaping in text
            output = render_to_typst("Special: @#*_\$/`<>")
            @test contains(output, "\\@")
            @test contains(output, "\\#")
            @test contains(output, "\\*")
            @test contains(output, "\\_")
        end
    end

    # ============================================================================
    # Integration Tests - Full Document Builds
    # ============================================================================

    @testset "Integration: Basic Build" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)

            write(
                joinpath(srcdir, "index.md"),
                """
                # Test Document

                Text **bold** and *italic* and `code`.

                ```julia
                x = 1 + 1
                ```
                """,
            )

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "BasicTest",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            typfile = joinpath(dir, "build", "BasicTest.typ")
            @test isfile(typfile)
            content = read(typfile, String)

            # Verify header
            @test occursin("#import(\"documenter.typ\")", content)
            @test occursin("title: [BasicTest]", content)

            # Verify content is present
            @test occursin("Test Document", content)
            @test occursin("#strong([", content)
            @test occursin("#emph([", content)
            @test occursin("#raw(", content)

            # Verify documenter.typ was copied
            @test isfile(joinpath(dir, "build", "documenter.typ"))
        end
    end

    @testset "Integration: Math Rendering" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)

            write(
                joinpath(srcdir, "index.md"),
                """
                # Math Test

                Display LaTeX: 

                ```math
                \\sum_{i=1}^n i
                ```

                Inline: ``\\alpha``

                Native Typst: 

                ```math typst
                sum_(i=1)^n i
                ```
                """,
            )

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "MathTest",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            typfile = joinpath(dir, "build", "MathTest.typ")
            @test isfile(typfile)
            content = read(typfile, String)

            # Verify LaTeX math uses mitex
            @test occursin("#mitex(\"", content)
            @test occursin("\\\\sum_{i=1}^n i", content)

            # Verify inline math uses mi
            @test occursin("#mi(\"", content)
            @test occursin("\\\\alpha", content)

            # Verify Typst math uses $ ... $
            @test occursin("\$\nsum_(i=1)^n i\n\$", content)
        end
    end

    @testset "Integration: Rich Content" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)

            write(
                joinpath(srcdir, "index.md"),
                """
                # Test Document

                ## Lists

                - Item 1
                - Item 2

                1. First
                2. Second

                ## Quote

                > This is a quote

                ---

                !!! note "Note Title"
                    Note content here

                ## Table

                | A | B |
                |---|---|
                | 1 | 2 |
                """,
            )

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "RichTest",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            typfile = joinpath(dir, "build", "RichTest.typ")
            @test isfile(typfile)
            content = read(typfile, String)

            # Verify various elements are present
            @test occursin("-", content)  # List items
            @test occursin("+", content)  # Ordered list items
            @test occursin("#quote(block: true)[", content)  # BlockQuote
            @test occursin("#line(length: 100%)", content)   # ThematicBreak
            @test occursin("#admonition(type: \"note\"", content)  # Admonition
            @test occursin("#table(", content)    # Table
        end
    end

    @testset "Integration: Version Handling" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)
            write(joinpath(srcdir, "index.md"), "# Test\n")

            # Test with semantic version
            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "Version Test",
                format = Documenter.Typst(platform = "none", version = "1.2.3"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            # File should be named with version
            @test isfile(joinpath(dir, "build", "VersionTest-1.2.3.typ"))
        end
    end

    @testset "Integration: Custom Template" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)
            assetsdir = joinpath(srcdir, "assets")
            mkpath(assetsdir)

            write(joinpath(srcdir, "index.md"), "# Test\n")
            write(joinpath(assetsdir, "custom.typ"), "// Custom Typst config\n")

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "CustomTest",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            # custom.typ should be copied to build dir
            @test isfile(joinpath(dir, "build", "custom.typ"))
            custom_content = read(joinpath(dir, "build", "custom.typ"), String)
            @test occursin("Custom Typst config", custom_content)
        end
    end

    @testset "Integration: Images" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)
            assetsdir = joinpath(srcdir, "assets")
            mkpath(assetsdir)

            # Create dummy image
            write(joinpath(assetsdir, "image.png"), "fake png")

            write(joinpath(srcdir, "index.md"), "![Caption](assets/image.png)")

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "ImgTest",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md"],
                doctest = false,
                remotes = nothing,
            )

            content = read(joinpath(dir, "build", "ImgTest.typ"), String)
            @test occursin("#figure(", content)
            @test occursin("image(", content)
            @test occursin("Caption", content)
        end
    end

    @testset "Integration: Multi-page" begin
        mktempdir() do dir
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)
            write(joinpath(srcdir, "index.md"), "# Home\n")
            write(joinpath(srcdir, "page2.md"), "# Page 2\n")

            makedocs(
                root = dir,
                source = "src",
                build = "build",
                sitename = "Multi",
                format = Documenter.Typst(platform = "none"),
                pages = ["index.md", "page2.md"],
                doctest = false,
                remotes = nothing,
            )

            content = read(joinpath(dir, "build", "Multi.typ"), String)
            @test occursin("Home", content)
            @test occursin("Page 2", content)
        end
    end

    @testset "Integration: Code Languages" begin
        output = render_to_typst(
            """
            ```python
            def hello():
                pass
            ```

            ```@repl
            x = 1
            ```

            ```text/plain
            plain
            ```
            """
        )
        @test occursin("lang: \"python\"", output)
        @test occursin("lang: \"julia\"", output)  # @repl → julia
        @test occursin("lang: \"text\"", output)   # text/plain → text
    end

    @testset "Integration: Nested Structures" begin
        output = render_to_typst(
            """
            > Quote with **bold**

            - List with `code`

            !!! note "Note"
                With *italic*
            """
        )
        @test occursin("#quote", output)
        @test occursin("#strong", output)
        @test occursin("#raw", output)
        @test occursin("#emph", output)
        @test occursin("#admonition", output)
    end
end

end # module
