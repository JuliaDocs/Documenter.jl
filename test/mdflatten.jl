module MDFlattenTests

using Test

using Base.Markdown
using Documenter.Utilities.MDFlatten

@testset "MDFlatten" begin
    @test mdflatten(Markdown.Paragraph("...")) == "..."
    @test mdflatten(Markdown.Header{1}("...")) == "..."

    # a simple test for blocks in top-level (each gets two newline appended to it)
    @test mdflatten(Markdown.parse("# Test\nTest")) == "Test\n\nTest\n\n"
    block_md = Markdown.parse("""
    # MDFlatten test


    ^^^ Ignoring extra whitespace.

    ```markdown
    code
    is forwarded as **is**
    ```
    """)
    block_text = """
    MDFlatten test

    ^^^ Ignoring extra whitespace.

    code
    is forwarded as **is**

    """
    @test mdflatten(block_md) == block_text

    # blocks
    @test mdflatten(Markdown.parse("> Test\n> Test\n\n> Test")) == "Test Test\n\nTest\n\n"
    @test mdflatten(Markdown.parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"
    @test mdflatten(Markdown.parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"
    @test mdflatten(Markdown.parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"

    # test some inline blocks
    @test mdflatten(Markdown.parse("`code` *em* normal **strong**")) == "code em normal strong\n\n"
    @test mdflatten(Markdown.parse("[link text *parsed*](link/itself/ignored)")) == "link text parsed\n\n"
    @test mdflatten(Markdown.parse("- a\n- b\n- c")) == "a\nb\nc\n\n"
    @test mdflatten(Markdown.parse("A | B\n---|---\naa|bb\ncc | dd")) == "A B\naa bb\ncc dd\n\n"

    # Math
    @test mdflatten(Markdown.parse("\$e=mc^2\$")) == "e=mc^2\n\n"
    if VERSION > v"0.5-"
        # backticks and blocks for math only in 0.5, i.e. these fail on 0.4
        @test mdflatten(Markdown.parse("``e=mc^2``")) == "e=mc^2\n\n"
        @test mdflatten(Markdown.parse("```math\n\\(m+n)(m-n)\nx=3\\sin(x)\n```")) == "(m+n)(m-n)\nx=3sin(x)\n\n"
    end

    # symbols in markdown
    @test mdflatten(Markdown.parse("A \$B C")) == "A B C\n\n"

    # linebreaks
    @test mdflatten(Markdown.parse("A\\\nB")) == "A\nB\n\n"

    # footnotes
    @test mdflatten(Markdown.parse("[^name]")) == "[name]\n\n"
    @test mdflatten(Markdown.parse("[^name]:**Strong** text.")) == "[name]: Strong text.\n\n"

    # admonitions
    @test mdflatten(Markdown.parse("!!! note \"Admonition Title\"\n    Test")) == "note: Admonition Title\nTest\n\n"
end

end
