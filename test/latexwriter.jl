module LaTeXWriterTests

using Test
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

end
