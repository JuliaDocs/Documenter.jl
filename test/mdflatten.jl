module MDFlattenTests

using Test

import Markdown
using MarkdownAST: MarkdownAST, @ast
using Documenter: Documenter
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
    @test mdflatten(parse("> Test\n> Test\n\n> Test")) in ["Test Test\n\nTest\n\n", "Test\nTest\n\nTest\n\n"]
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

    strikethrough = MarkdownAST.Node(MarkdownAST.Strikethrough())
    push!(strikethrough.children, MarkdownAST.Node(MarkdownAST.Text("deleted")))
    @test mdflatten(strikethrough) == "deleted"

    htmlinline = MarkdownAST.Node(MarkdownAST.HTMLInline("<span>inline</span>"))
    @test mdflatten(htmlinline) == "inline"

    htmlblock = MarkdownAST.Node(MarkdownAST.HTMLBlock("<div>block <b>html</b></div>"))
    @test mdflatten(htmlblock) == "block html"

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

@testset "MDFlatten: Documenter blocks" begin
    codeblock(info, code) = MarkdownAST.CodeBlock(info, code)

    # @meta and @setup blocks render nothing, so they contribute nothing to the
    # search index either.
    @test mdflatten(
        MarkdownAST.Node(Documenter.MetaNode(codeblock("@meta", "DocTestSetup = :(using Foo)"), Dict{Symbol, Any}()))
    ) == ""
    @test mdflatten(MarkdownAST.Node(Documenter.SetupNode("@setup foo", "x = 1"))) == ""

    # @example blocks flatten to their source and their output, mirroring what
    # actually ends up in the rendered page.
    example = MarkdownAST.Node(Documenter.MultiOutput(codeblock("@example", "1 + 1")))
    push!(example.children, MarkdownAST.Node(codeblock("julia", "1 + 1")))
    push!(example.children, MarkdownAST.Node(Documenter.MultiOutputElement(Dict{MIME, Any}(MIME"text/plain"() => "2"))))
    @test mdflatten(example) == "1 + 1\n2"

    # Non-textual output (e.g. images) has nothing to contribute.
    image_example = MarkdownAST.Node(Documenter.MultiOutput(codeblock("@example", "plot()")))
    push!(image_example.children, MarkdownAST.Node(codeblock("julia", "plot()")))
    push!(image_example.children, MarkdownAST.Node(Documenter.MultiOutputElement(Dict{MIME, Any}(MIME"image/png"() => "..."))))
    @test mdflatten(image_example) == "plot()"

    # @repl blocks interleave inputs and outputs as children.
    repl = MarkdownAST.Node(Documenter.MultiCodeBlock(codeblock("@repl", "1 + 1"), "julia-repl", Markdown.Code[]))
    push!(repl.children, MarkdownAST.Node(MarkdownAST.Code("julia> 1 + 1")))
    push!(repl.children, MarkdownAST.Node(MarkdownAST.Code("2")))
    @test mdflatten(repl) == "julia> 1 + 1\n2"

    # @eval blocks only render their result.
    evalresult = @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            "the result"
        end
    end
    @test mdflatten(MarkdownAST.Node(Documenter.EvalNode(codeblock("@eval", "md\"the result\""), evalresult))) == "the result\n\n"
    @test mdflatten(MarkdownAST.Node(Documenter.EvalNode(codeblock("@eval", "nothing"), nothing))) == ""
end

end
