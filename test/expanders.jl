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
