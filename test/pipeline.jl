module PipeLineTests
using Test

@testset "Builder.lt_page" begin
    using Documenter.Builder: lt_page
    # Checks to make sure that only exactly one of a<b, a==b and a>b is true for given a & b
    iscorrectisless(a,b) = sum([lt_page(a, b), a == b, lt_page(b, a)]) == 1
    # Test equal strings:
    for a in ["index.md", "foo/index.md", "foo.md", "bar/foo.md", "foo/bar/baz/qux", "", "α", "α/β", "α/index.md"]
        @test !lt_page(a, a)
        @test iscorrectisless(a, a)
    end
    # Test less thans
    for (a, b) in [
            ("a", "b"), ("α", "β"), ("b", "α"),
            # index.md takes precedence
            ("index.md", "a"),
            ("index.md", "index.mm"),
            ("index.md", "foo.md"),
            ("index.md", "bar/foo.md"),
            # Also in subdirectories:
            ("foo/index.md", "foo/a"),
            ("foo/index.md", "foo/index.mm"),
            ("foo/index.md", "foo/foo.md"),
            ("foo/index.md", "foo/bar/foo.md"),
            # But not over stuff that is outside of the subdirectory
            ("a", "foo/index.md"),
            ("α", "α/index.md"),
            ("foo/index.md", "g"),
            ("bar/index.md", "foo/index.md"),
            ("bar/qux/index.md", "foo/index.md"),
        ]
        @test lt_page(a, b)
        @test iscorrectisless(a, b)
    end

    @test sort(["foo", "bar"], lt=lt_page) == ["bar", "foo"]
    @test sort(["foo", "foo/bar"], lt=lt_page) == ["foo", "foo/bar"]
    @test sort(["foo", "f/bar"], lt=lt_page) == ["f/bar", "foo"]
    @test sort(["foo", "index.md"], lt=lt_page) == ["index.md", "foo"]
    @test sort(["foo.md", "foo/index.md", "index.md", "foo/foo.md"], lt=lt_page) == ["index.md", "foo.md", "foo/index.md", "foo/foo.md"]
    @test sort(["foo.md", "ϕωω/index.md", "index.md", "foo/foo.md"], lt=lt_page) == ["index.md", "foo.md", "foo/foo.md", "ϕωω/index.md"]
end

# Docstring signature syntax highlighting tests.
module HighlightSig
    using Test
    import Markdown
    import Documenter.Expanders: highlightsig!

    @testset "highlightsig!" begin
        s = """
                foo(bar::Baz)
            ---
                foo(bar::Baz)
            """
        original = Markdown.parse(s)
        md = Markdown.parse(s)
        highlightsig!(md)
        @test isempty(original.content[1].language)
        @test md.content[1].language == "julia"
        @test original.content[end].language == md.content[end].language

        s = """
            ```lang
             foo(bar::Baz)
            ```
            """
        original = Markdown.parse(s)
        md = Markdown.parse(s)
        highlightsig!(md)
        @test original == md
    end
end

end
