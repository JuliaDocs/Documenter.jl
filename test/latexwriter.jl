module LaTeXWriterTests

using Test
import IOCapture
import Documenter
import Documenter.LaTeXWriter

@testset "file ordering" begin
    # Single page returns a single page
    @test LaTeXWriter.files(["a.md"]) == [("", "a.md", 1)]

    # Multiple pages at the top-level
    @test LaTeXWriter.files(["a.md", "b.md"]) ==
        [("", "a.md", 1), ("", "b.md", 1)]

    # Single header
    @test LaTeXWriter.files(["A" => "a.md"]) == [("A", "a.md", 1)]

    # Single page and a header
    @test LaTeXWriter.files(["a.md", "B" => "b.md"]) ==
        [("", "a.md", 1), ("B", "b.md", 1)]

    # Single page and a vector
    @test LaTeXWriter.files(["a.md", "B" => ["b.md", "c.md"]]) ==
        [("", "a.md", 1), ("B", "", 1), ("", "b.md", 2), ("", "c.md", 2)]

    # Multiple layers of nesting
    @test LaTeXWriter.files(["a.md", "B" => ["b.md", "C" => ["c.md"]]]) == [
        ("", "a.md", 1),
        ("B", "", 1),
        ("", "b.md", 2),
        ("C", "", 2),
        ("", "c.md", 3),
    ]
end


function _dummy_lctx()
    doc = Documenter.Document()
    buffer = IOBuffer()
    return LaTeXWriter.Context(buffer, doc)
end

function _latexesc(str)
    lctx = _dummy_lctx()
    LaTeXWriter.latexesc(lctx, str)
    return String(take!(lctx.io))
end

function _md_to_latex(mdstr)
    lctx = _dummy_lctx()
    ast = Documenter.mdparse(mdstr; mode = :single)[1]
    LaTeXWriter.latex(lctx, ast.children)  # should use latexesc internally
    return String(take!(lctx.io))
end

function _mdblocks_to_latex(mdstr)
    lctx = _dummy_lctx()
    ast = Documenter.mdparse(mdstr; mode = :blocks)
    for node in ast
        LaTeXWriter.latex(lctx, node)
    end
    return String(take!(lctx.io))
end

function _node_to_latex(node)
    lctx = _dummy_lctx()
    LaTeXWriter.latex(lctx, node)
    return String(take!(lctx.io))
end


@testset "latex escapes" begin

    md = "~ Ref.\u00A0[1], O'Reilly, \"Book #1\""
    tex = "{\\textasciitilde} Ref.~[1], O{\\textquotesingle}Reilly, {\\textquotedbl}Book \\#1{\\textquotedbl}"
    @test _latexesc(md) == tex
    @test _md_to_latex(md) == tex

    md = "[DocumenterCitations.jl](https://github.com/JuliaDocs/DocumenterCitations.jl#readme)"
    tex = "\\href{https://github.com/JuliaDocs/DocumenterCitations.jl\\#readme}{DocumenterCitations.jl}"
    @test _md_to_latex(md) == tex

    md = "[Description with ~](https://link.with/~tilde)"
    tex = "\\href{https://link.with/~tilde}{Description with {\\textasciitilde}}"
    @test _md_to_latex(md) == tex

end

@testset "latex optional MarkdownAST nodes" begin
    strikethrough = Documenter.MarkdownAST.Node(Documenter.MarkdownAST.Strikethrough())
    push!(strikethrough.children, Documenter.MarkdownAST.Node(Documenter.MarkdownAST.Text("gone")))
    @test _node_to_latex(strikethrough) == "gone"

    htmlinline = Documenter.MarkdownAST.Node(Documenter.MarkdownAST.HTMLInline("<span>x</span>"))
    @test_logs (:warn, r"Raw HTML inline is not supported in LaTeX output") _node_to_latex(htmlinline) == "x"

    htmlblock = Documenter.MarkdownAST.Node(Documenter.MarkdownAST.HTMLBlock("<div>y</div>"))
    @test_logs (:warn, r"Raw HTML block is not supported in LaTeX output") _node_to_latex(htmlblock) == "y\n"
end

@testset "inline @id anchors" begin
    anchor = Documenter.Anchor(nothing)
    anchor.id = "my-anchor"
    node = Documenter.MarkdownAST.Node(Documenter.AnchoredInline(anchor))
    push!(node.children, Documenter.MarkdownAST.Node(Documenter.MarkdownAST.Text("content")))
    id = LaTeXWriter._hash(Documenter.anchor_label(anchor))

    @test _node_to_latex(node) == "\\hypertarget{$(id)}{content}"

    # A header title is a moving argument that also lands in the table of contents and the
    # PDF bookmarks, where \hypertarget does not belong. Only the content is emitted, and
    # the target is deferred to a `\label` after the title.
    lctx = _dummy_lctx()
    lctx.in_header = true
    LaTeXWriter.latex(lctx, node)
    @test String(take!(lctx.io)) == "content"
    @test lctx.pending_labels == [id]

    # The heading flushes those deferred labels, so the anchor still has a target that
    # `\hyperlinkref` can resolve.
    heading = Documenter.MarkdownAST.@ast Documenter.MarkdownAST.Heading(1) do
        Documenter.MarkdownAST.Text("Title ")
    end
    inline = Documenter.MarkdownAST.Node(Documenter.AnchoredInline(anchor))
    push!(inline.children, Documenter.MarkdownAST.Node(Documenter.MarkdownAST.Text("content")))
    push!(heading.children, inline)
    @test _node_to_latex(heading) == "\\part{Title content}\n\n\\label{$(id)}{}\n\n"
end

# `nrows` includes the header row, matching how the writer counts.
function _md_table(nrows)
    io = IOBuffer()
    println(io, "| Column | Value |")
    println(io, "|:------ |:----- |")
    for i in 1:(nrows - 1)
        println(io, "| ", i, " | x |")
    end
    return String(take!(io))
end

@testset "large tables span pages" begin
    # Small tables stay in a centred `table` float, which cannot break across pages.
    small = _mdblocks_to_latex(_md_table(LaTeXWriter.LONGTABLE_ROW_THRESHOLD - 1))
    @test occursin("\\begin{table}", small)
    @test occursin("\\begin{tabulary}", small)
    @test !occursin("xltabular", small)

    # Large tables must use a page-breaking environment instead, otherwise LaTeX
    # either drops the oversized float or aborts with "Dimension too large".
    large = _mdblocks_to_latex(_md_table(LaTeXWriter.LONGTABLE_ROW_THRESHOLD))
    @test !occursin("\\begin{table}", large)
    @test !occursin("tabulary", large)
    @test occursin("\\begin{xltabular}{\\linewidth}", large)
    @test occursin("\\end{xltabular}", large)

    # The header row is repeated on every page.
    @test occursin("\\endhead", large)
    @test occursin("\\endfirsthead", large)
    @test count("Column & Value", large) == 2
end

@testset "large table PDF regression reproducer" begin
    pdflatex = Sys.which("pdflatex")
    pdflatex === nothing && (@test_skip false; return)

    table_tex = _mdblocks_to_latex(_md_table(200))

    mktempdir() do tmp
        texfile = joinpath(tmp, "big.tex")
        write(
            texfile,
            """
            \\documentclass{article}
            \\usepackage{booktabs}
            \\usepackage{xltabular}
            \\begin{document}
            $table_tex
            \\end{document}
            """,
        )
        cmd = `$(pdflatex) -interaction=nonstopmode -halt-on-error big.tex`
        proc = cd(tmp) do
            p = run(pipeline(cmd; stdout = devnull, stderr = devnull); wait = false)
            wait(p)
            p
        end
        log = read(joinpath(tmp, "big.log"), String)

        @test success(proc)
        @test !occursin("Dimension too large", log)

        # The table must actually be typeset, spanning several pages, rather than
        # dropped as an oversized float.
        pages = match(r"Output written on .*\((\d+) pages", log)
        @test pages !== nothing && parse(Int, pages[1]) > 1
    end
end

@testset "latex table link fragment PDF regression reproducer" begin
    pdflatex = Sys.which("pdflatex")
    pdflatex === nothing && (@test_skip false; return)

    md = raw"""
    | Type | Description |
    |:---- |:----------- |
    | `A`  | [B](https://example.com/path) |
    | `C`  | [D](https://example.com/path#frag) |
    """
    table_tex = _mdblocks_to_latex(md)
    @test occursin("\\href{https://example.com/path\\#frag}{D}", table_tex)

    mktempdir() do tmp
        texfile = joinpath(tmp, "repro.tex")
        write(
            texfile,
            """
            \\documentclass{article}
            \\usepackage{booktabs}
            \\usepackage{tabulary}
            \\usepackage{hyperref}
            \\begin{document}
            $table_tex
            \\end{document}
            """,
        )
        cmd = `$(pdflatex) -interaction=nonstopmode -halt-on-error repro.tex`
        proc = cd(tmp) do
            p = run(pipeline(cmd; stdout = devnull, stderr = devnull); wait = false)
            wait(p)
            p
        end
        log = read(joinpath(tmp, "repro.log"), String)

        @test success(proc)
        @test !occursin("Illegal parameter number in definition of \\Hy@tempa", log)
    end
end

@testset "LaTeX show_log option" begin
    @test !LaTeXWriter.LaTeX().show_log
    @test LaTeXWriter.LaTeX(show_log = true).show_log
    withenv("DOCUMENTER_LATEX_SHOW_LOGS" => "1") do
        @test LaTeXWriter.LaTeX().show_log
        @test LaTeXWriter.LaTeX(show_log = false).show_log
    end
end

@testset "dump latex log" begin
    mktempdir() do tmp
        output = cd(tmp) do
            open("manual.log", "w") do io
                write(io, "latex failure details\n")
            end
            open("LaTeXWriter.stdout", "w") do io
                write(io, "stdout details\n")
            end
            c = IOCapture.capture() do
                LaTeXWriter.dump_latex_log("manual")
            end
            c.output
        end
        @test occursin("BEGIN manual.log", output)
        @test occursin("latex failure details", output)
        @test occursin("BEGIN LaTeXWriter.stdout", output)
        @test occursin("stdout details", output)
    end

    mktempdir() do tmp
        output = cd(tmp) do
            c = IOCapture.capture() do
                LaTeXWriter.dump_latex_log("manual")
            end
            c.output
        end
        @test occursin("show_log=true but no log files were found", output)
    end
end


end
