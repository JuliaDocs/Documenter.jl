using Test

# DOCUMENTER_TEST_EXAMPLES can be used to control which builds are performed in
# make.jl, and we need to set it to the relevant LaTeX builds.
ENV["DOCUMENTER_TEST_EXAMPLES"] = "latex latex_simple latex_texonly latex_headings"

# When the file is run separately we need to include make.jl which actually builds
# the docs and defines a few modules that are referred to in the docs. The make.jl
# has to be expected in the context of the Main module.
if (@__MODULE__) === Main && !@isdefined examples_root
    include("make.jl")
elseif (@__MODULE__) !== Main && isdefined(Main, :examples_root)
    using Documenter
    const examples_root = Main.examples_root
elseif (@__MODULE__) !== Main && !isdefined(Main, :examples_root)
    error("examples/make.jl has not been loaded into Main.")
end

# This gets appended to the filename if we're building a tag (i.e. TRAVIS_TAG is set)
tagsuffix = if occursin(Base.VERSION_REGEX, get(ENV, "TRAVIS_TAG", ""))
    v = VersionNumber(ENV["TRAVIS_TAG"])
    "-$(v.major).$(v.minor).$(v.patch)"
else
    ""
end

@testset "Examples/LaTeX" begin
    @testset "PDF/LaTeX: simple" begin
        doc = Main.examples_latex_simple_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_simple")
            @test joinpath(build_dir, "DocumenterLaTeXSimple$(tagsuffix).pdf") |> isfile
        end
    end

    @testset "PDF/LaTeX" begin
        doc = Main.examples_latex_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex")
            @test joinpath(build_dir, "DocumenterLaTeX$(tagsuffix).pdf") |> isfile
        end
    end

    @testset "PDF/LaTeX: TeX only" begin
        doc = Main.examples_latex_texonly_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_texonly")
            @test joinpath(build_dir, "DocumenterLaTeX$(tagsuffix).tex") |> isfile
            @test joinpath(build_dir, "documenter.sty") |> isfile
        end
    end

    @testset "PDF/LaTeX: headings" begin
        DS = Main.Documenter.Writers.LaTeXWriter.DOCUMENT_STRUCTURE
        "Parse a tex file and return the lines that contain headings."
        function parsefile(filename)
            headings = String[]
            for line in readlines(filename)
                for ds in DS
                    occursin(ds, line) || continue
                    push!(headings, line)
                    break
                end
            end
            return headings
        end

        """
            testsections(line1, levelnum, filenum)

        Test chapter and lower headings.
        """
        function testsections(line1, levelnum, filenum)
            # levelnum[1] == "part", which is not tested here
            latexheading = "\\$(DS[levelnum+1]){Level $levelnum in f$filenum}"
            @test line1 == latexheading
        end

        "Test a file: test each heading level. Advance the iterator."
        function testfile!(lines, itern, filenum)
            for i in 1:6
                testsections(lines[itern], i, filenum)
                itern += 1
            end
            return itern
        end

        doc = Main.examples_latex_headings_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_headings")
            @test joinpath(build_dir, "DocumenterLaTeXHeadingTests$(tagsuffix).tex") |> isfile
            headings = parsefile(joinpath(build_dir, "DocumenterLaTeXHeadingTests$(tagsuffix).tex"))
            # "Part1" => "headings/f1.md",
            @test headings[1] == "\\part{Part1}"
            n = 2
            n = testfile!(headings, n, 1)
            # "Part2" => ["headings/f2.md", "headings/f3.md"],
            @test headings[n] == "\\part{Part2}"
            n = n + 1
            n = testfile!(headings, n, 2)
            n = testfile!(headings, n, 3)
            # "Part3" => "headings/f4.md"
            @test headings[n] == "\\part{Part3}"
            n = n + 1
            testfile!(headings, n, 4)
        end
    end

end
