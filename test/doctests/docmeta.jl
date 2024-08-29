module DocMetaTests
using Test
using Documenter

module TestMod
    module Submodule end
end

@testset "DocMeta" begin
    @test DocMeta.getdocmeta(TestMod) == Dict()
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup) === nothing
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup, 42) === 42
    @test DocMeta.setdocmeta!(TestMod, :DocTestSetup, :foo) === nothing
    @test DocMeta.getdocmeta(TestMod) == Dict(:DocTestSetup => :foo)
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup) == :foo
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup, 42) == :foo
    # bad key
    @test_throws ArgumentError DocMeta.setdocmeta!(TestMod, :FooBar, 0)
    # bad argument type
    @test_throws ArgumentError DocMeta.setdocmeta!(TestMod, :DocTestSetup, 42)
    # setting again works
    @test DocMeta.setdocmeta!(TestMod, :DocTestSetup, :foo; warn = false) === nothing
    # recursive setting
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup) == :foo
    @test DocMeta.getdocmeta(TestMod.Submodule, :DocTestSetup) === nothing
    @test DocMeta.setdocmeta!(TestMod, :DocTestSetup, :foo; recursive = true, warn = false) === nothing
    @test DocMeta.getdocmeta(TestMod, :DocTestSetup) == :foo
    @test DocMeta.getdocmeta(TestMod.Submodule, :DocTestSetup) == :foo
end

end
