using Documenter
using Test
import Documenter.TimerOutputs

timer(timings) = makedocs(; sitename = "Test", timings, debug = true).user.timer
sections(tree) = sort(collect(keys(tree["inner_timers"])))

@testset "timings" begin
    @testset "collected sections" begin
        @test !timer(false).enabled
        @test sections(TimerOutputs.todict(timer(false))) == String[]
        @test_throws ArgumentError makedocs(; sitename = "Test", timings_detail = 1.5)

        tree = TimerOutputs.todict(timer(true))
        @test sections(tree) == ["CheckDocument", "CrossReferences", "Doctest", "ExpandTemplates", "Populate", "RenderDocument", "SetupBuildDirectory"]
        pages = tree["inner_timers"]["ExpandTemplates"]
        @test sections(pages) == ["index.md", "other.md"]
        @test sections(pages["inner_timers"]["index.md"]) == [
            "L12-14 @setup named x = 1",
            "L17-19 @repl named x + 1",
            "L3-5 @meta CurrentModule = Main",
            "L7-10 @example sleep(0.01)",
        ]
        @test sections(pages["inner_timers"]["other.md"]) == String[]
        @test pages["inner_timers"]["index.md"]["inner_timers"]["L7-10 @example sleep(0.01)"]["time_ns"] >= 10_000_000
    end

    @testset "printed table" begin
        seconds(x) = round(Int64, x * 1.0e9)
        section(time, inner = Dict{String, Any}()) = Dict{String, Any}("time_ns" => seconds(time), "inner_timers" => inner)
        tree = section(
            0, Dict{String, Any}(
                "RenderDocument" => section(30),
                "ExpandTemplates" => section(
                    100, Dict{String, Any}(
                        "index.md" => section(
                            70, Dict{String, Any}(
                                "L1-3 @example " * "x"^80 => section(50),
                                "L5-7 @repl sleep(1)" => section(10),
                                "L9-11 @setup y = 1" => section(5),
                            )
                        ),
                        "other.md" => section(20, Dict{String, Any}("L1-3 @eval 1 + 1" => section(15))),
                        "tiny.md" => section(10),
                    )
                ),
            )
        )
        table(detail; columns = 80) = sprint(io -> Documenter.print_build_timings(IOContext(io, :displaysize => (24, columns)), tree, detail))
        @test table(0.8) == """
            Build timings (slowest blocks shown until the listed rows reach 80% of the total runtime):
              ExpandTemplates                                                  100.0s  76.9%
                index.md                                                        70.0s  53.8%
                  L1-3 @example xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…   50.0s  38.5%
                  L5-7 @repl sleep(1)                                           10.0s   7.7%
                  1 other block                                                  5.0s   3.8%
                other.md                                                        20.0s  15.4%
                  L1-3 @eval 1 + 1                                              15.0s  11.5%
                1 other page                                                    10.0s   7.7%
              RenderDocument                                                    30.0s  23.1%
            """
        @test table(1.0) == """
            Build timings (slowest blocks shown until the listed rows reach 100% of the total runtime):
              ExpandTemplates                                                  100.0s  76.9%
                index.md                                                        70.0s  53.8%
                  L1-3 @example xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…   50.0s  38.5%
                  L5-7 @repl sleep(1)                                           10.0s   7.7%
                  L9-11 @setup y = 1                                             5.0s   3.8%
                other.md                                                        20.0s  15.4%
                  L1-3 @eval 1 + 1                                              15.0s  11.5%
                1 other page                                                    10.0s   7.7%
              RenderDocument                                                    30.0s  23.1%
            """
        @test table(0.2) == """
            Build timings (slowest blocks shown until the listed rows reach 20% of the total runtime):
              ExpandTemplates  100.0s  76.9%
                3 pages        100.0s  76.9%
              RenderDocument    30.0s  23.1%
            """
        @test occursin("L1-3 @example " * "x"^80 * "   50.0s", table(0.8; columns = 120))
    end
end
