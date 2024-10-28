module LaTeXWriterTests

using Test
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


@testset "latex escapes" begin

    md = "~ Ref.\u00A0[1], O'Reilly, \"Book #1\""
    tex = "{\\textasciitilde} Ref.~[1], O{\\textquotesingle}Reilly, {\\textquotedbl}Book \\#1{\\textquotedbl}"
    @test _latexesc(md) == tex
    @test _md_to_latex(md) == tex

    md = "[DocumenterCitations.jl](https://github.com/JuliaDocs/DocumenterCitations.jl#readme)"
    tex = "\\href{https://github.com/JuliaDocs/DocumenterCitations.jl\\#readme}{DocumenterCitations.jl}"
    @test _md_to_latex(md) == tex

end


end
