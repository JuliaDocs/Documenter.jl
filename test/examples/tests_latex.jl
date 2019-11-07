using Test

# DOCUMENTER_TEST_EXAMPLES can be used to control which builds are performed in
# make.jl, and we need to set it to the relevant LaTeX builds.
ENV["DOCUMENTER_TEST_EXAMPLES"] = "latex latex_simple"

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

@testset "Examples/LaTeX" begin
    @testset "PDF/LaTeX: simple" begin
        doc = Main.examples_latex_simple_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex_simple")
            @test joinpath(build_dir, "DocumenterLaTeXSimple.pdf") |> isfile
        end
    end

    @testset "PDF/LaTeX" begin
        doc = Main.examples_latex_doc
        @test isa(doc, Documenter.Documents.Document)
        let build_dir = joinpath(examples_root, "builds", "latex")
            @test joinpath(build_dir, "DocumenterLaTeX.pdf") |> isfile
        end
    end
end
