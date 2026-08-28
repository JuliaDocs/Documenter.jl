module ProgressTests
using Test
using Documenter
using ProgressMeter
using IOCapture

@testset "Progress" begin
    @testset "wrapping" begin
        iter = Documenter.progress_iter([1, 2, 3])
        @test !isa(iter, Vector)  # else the assertions below pass vacuously
        @test collect(iter) == [1, 2, 3]
        @test length(iter) == 3
        @test size(iter) == (3,)
        @test eltype(iter) == Int
        # HTMLWriter maps over it, which needs the shape interface.
        @test map(x -> 2x, Documenter.progress_iter([1, 2, 3])) == [2, 4, 6]
        @test collect(Documenter.progress_iter(["a" => 1, "b" => 2])) == ["a" => 1, "b" => 2]
        @test isempty(collect(Documenter.progress_iter(Int[])))
    end

    @testset "a bar is actually drawn" begin
        c = IOCapture.capture(passthrough = false) do
            for _ in Documenter.progress_iter(collect(1:20))
                sleep(0.02)  # exceed the default dt
            end
        end
        @test occursin("%", c.output)
    end

    @testset "non-vector input is passed through" begin
        gen = (i for i in 1:3)
        @test Documenter.progress_iter(gen) === gen
    end

    @testset "a build with ProgressMeter loaded succeeds" begin
        c = IOCapture.capture(passthrough = false) do
            makedocs(
                sitename = "-",
                root = @__DIR__,
                source = joinpath("progress", "src"),
                build = joinpath("progress", "build"),
                warnonly = false,
            )
        end
        @test c.value === nothing
    end
end

end # module
