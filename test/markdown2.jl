module Markdown2Tests
using Test
import Markdown
import Documenter.Utilities: Markdown2

@testset "Markdown2" begin
    let md = Markdown.parse(""),
        md2 = convert(Markdown2.MD, md)
        @test isa(md2, Markdown2.MD)
        @test length(md2) === 0
    end

    let md = Markdown.parse("""
        # Text Paragraphs

        Foo *bar **baz** qux*!

        Foo Bar \\
        Baz
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 3

        let h = md2.nodes[1]
            @test isa(h, Markdown2.Heading)
            @test length(h.nodes) === 1
            @test isa(h.nodes[1], Markdown2.Text)
            @test h.nodes[1].text == "Text Paragraphs"
        end

        let p = md2.nodes[2]
            @test isa(p, Markdown2.Paragraph)
            @test length(p.nodes) === 3

            @test isa(p.nodes[1], Markdown2.Text)
            @test p.nodes[1].text == "Foo "
            @test isa(p.nodes[2], Markdown2.Emphasis)
            @test isa(p.nodes[3], Markdown2.Text)
            @test p.nodes[3].text == "!"

            @test length(p.nodes[2].nodes) === 3
            @test isa(p.nodes[2].nodes[1], Markdown2.Text)
            @test p.nodes[2].nodes[1].text == "bar "
            @test isa(p.nodes[2].nodes[2], Markdown2.Strong)
            @test length(p.nodes[2].nodes[2].nodes) === 1
            @test isa(p.nodes[2].nodes[2].nodes[1], Markdown2.Text)
            @test p.nodes[2].nodes[2].nodes[1].text == "baz"
            @test isa(p.nodes[2].nodes[3], Markdown2.Text)
            @test p.nodes[2].nodes[3].text == " qux"
        end

        @test isa(md2.nodes[3], Markdown2.Paragraph)
    end

    let md = Markdown.parse("""
        # Images

        ![Alt Text](https://example.com/image.png)
        ![](https://example.com/image-noalt.png)
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 2

        @test isa(md2.nodes[1], Markdown2.Heading)
        @test md2.nodes[1].level === 1

        @test isa(md2.nodes[2], Markdown2.Paragraph)
        images = md2.nodes[2].nodes
        @test length(md2.nodes[2].nodes) === 3 # there are Text() nodes between Image() nodes

        @test isa(images[1], Markdown2.Image)
        @test images[1].destination == "https://example.com/image.png"
        @test images[1].description == "Alt Text"

        @test isa(images[3], Markdown2.Image)
        @test images[3].destination == "https://example.com/image-noalt.png"
        @test images[3].description == ""
    end

    let md = Markdown.parse("""
        Blocks
        ------

        ```language
        Hello
        > World!
        ```

        ---

        > Block
        > ``z+1``
        > Quote!
        >
        > ```math
        > x^2 + y^2 = z^2
        > ```

        --- ---
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 5

        @test isa(md2.nodes[1], Markdown2.Heading)
        @test md2.nodes[1].level === 2

        @test isa(md2.nodes[2], Markdown2.CodeBlock)
        @test md2.nodes[2].language == "language"

        @test isa(md2.nodes[3], Markdown2.ThematicBreak)
        @test isa(md2.nodes[4], Markdown2.BlockQuote)
        @test isa(md2.nodes[5], Markdown2.ThematicBreak)
    end

    let md = Markdown.parse("""
        ### Lists

        - a `code span`
        - b
        - c
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 2

        @test isa(md2.nodes[1], Markdown2.Heading)
        @test md2.nodes[1].level === 3

        let list = md2.nodes[2]
            @test isa(list, Markdown2.List)
            @test list.tight === true
            @test list.orderedstart === nothing
            @test length(list.items) === 3

            @test length(list.items[1]) === 1
            @test isa(list.items[1][1], Markdown2.Paragraph)
            @test length(list.items[1][1].nodes) === 2
            @test isa(list.items[1][1].nodes[1], Markdown2.Text)
            @test isa(list.items[1][1].nodes[2], Markdown2.CodeSpan)
            @test list.items[1][1].nodes[2].code == "code span"
        end
    end

    let md = Markdown.parse("""
        !!! warn "FOOBAR"
            Hello World

            ``math
            x+1
            ``
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 1

        @test isa(md2.nodes[1], Markdown2.Admonition)
    end

    let md = Markdown.parse("""
        | Column One | Column Two | Column Three |
        |:---------- | ---------- |:------------:|
        | Row `1`    | Column `2` | > asd        |
        | *Row* 2    | **Row** 2  | Column ``3`` |
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) === 1

        @test isa(md2.nodes[1], Markdown2.Table)
    end

    # Issue 1073
    let md = Markdown.parse(raw"""
        $$
        f
        $$
        """),
        md2 = convert(Markdown2.MD, md)
        @test isa(md2, Markdown2.MD)
    end
    let md = Markdown.parse(raw"""
        X $(42) Y
        """),
        md2 = convert(Markdown2.MD, md)

        @test isa(md2, Markdown2.MD)
        @test length(md2) == 1
        @test isa(md2.nodes[1], Markdown2.Paragraph)
        let p = md2.nodes[1]
            @test length(p.nodes) == 3
            @test p.nodes[2] == Markdown2.Text("42")
        end
    end
end

end # module
