module MDFlattenTests

using Test

import Markdown
using MarkdownAST: MarkdownAST, @ast
using Documenter.MDFlatten

parse(s) = convert(MarkdownAST.Node, Markdown.parse(s))

struct UnsupportedElement <: MarkdownAST.AbstractElement end

@testset "MDFlatten" begin
    @test mdflatten(
        @ast(
            MarkdownAST.Paragraph() do;
                "..."
            end
        )
    ) == "..."
    @test mdflatten(
        @ast(
            MarkdownAST.Heading(1) do;
                "..."
            end
        )
    ) == "..."

    # a simple test for blocks in top-level (each gets two newline appended to it)
    @test mdflatten(parse("# Test\nTest")) == "Test\n\nTest\n\n"
    block_md = parse(
        """
        # MDFlatten test


        ^^^ Ignoring extra whitespace.

        ```markdown
        code
        is forwarded as **is**
        ```
        """
    )
    block_text = """
    MDFlatten test

    ^^^ Ignoring extra whitespace.

    code
    is forwarded as **is**

    """
    @test mdflatten(block_md) == block_text

    # blocks
    @test mdflatten(parse("> Test\n> Test\n\n> Test")) == "Test Test\n\nTest\n\n"
    @test mdflatten(parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"
    @test mdflatten(parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"
    @test mdflatten(parse("HRs\n\n---\n\nto whitespace")) == "HRs\n\n\n\nto whitespace\n\n"

    # test some inline blocks
    @test mdflatten(parse("`code` *em* normal **strong**")) == "code em normal strong\n\n"
    @test mdflatten(parse("[link text *parsed*](link/itself/ignored)")) == "link text parsed\n\n"
    @test mdflatten(parse("- a\n- b\n- c")) == "a\nb\nc\n\n"
    @test mdflatten(parse("A | B\n---|---\naa|bb\ncc | dd")) == "A B\naa bb\ncc dd\n\n"

    # Math
    @test mdflatten(parse("\$e=mc^2\$")) == "e=mc^2\n\n"
    # backticks and blocks for math only in 0.5, i.e. these fail on 0.4
    @test mdflatten(parse("``e=mc^2``")) == "e=mc^2\n\n"
    @test mdflatten(parse("```math\n\\(m+n)(m-n)\nx=3\\sin(x)\n```")) == "(m+n)(m-n)\nx=3sin(x)\n\n"

    # symbols in markdown
    @test mdflatten(parse("A \$B C")) == "A B C\n\n"

    # linebreaks
    @test mdflatten(parse("A\\\nB")) == "A\nB\n\n"

    # footnotes
    @test mdflatten(parse("[^name]")) == "[name]\n\n"
    @test mdflatten(parse("[^name]:**Strong** text.")) == "[name]: Strong text.\n\n"

    # admonitions
    @test mdflatten(parse("!!! note \"Admonition Title\"\n    Test")) == "note: Admonition Title\nTest\n\n"

    @test mdflatten([@ast("x"), @ast("y"), @ast("z")]) == "xyz"
    @test_throws Exception mdflatten(@ast(UnsupportedElement()))
end

end
