using Test

# for convenience, when debugging, the build step can be disabled when running the tests with
#   julia test/workdir/tests.jl skipbuild
if !("skipbuild" in ARGS)
    rm(joinpath(@__DIR__, "builds"), recursive = true, force = true) # cleanup of previous test run
    include(joinpath(@__DIR__, "make.jl"))
end

@testset "makedocs workdir" begin
    # test for the default build
    @test isfile(joinpath(@__DIR__, "builds", "default", "root_index.txt"))
    @test isfile(joinpath(@__DIR__, "builds", "default", "root_file.txt"))
    @test isfile(joinpath(@__DIR__, "builds", "default", "subdir", "subdir_index.txt"))
    @test isfile(joinpath(@__DIR__, "builds", "default", "subdir", "subdir_file.txt"))

    # absolute path
    @test !isfile(joinpath(@__DIR__, "builds", "absolute", "root_index.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "absolute", "root_file.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "absolute", "subdir", "subdir_index.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "absolute", "subdir", "subdir_file.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "absolute-workdir", "root_index.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "absolute-workdir", "root_file.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "absolute-workdir", "subdir_index.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "absolute-workdir", "subdir_file.txt"))

    # relative path
    @test !isfile(joinpath(@__DIR__, "builds", "relative", "root_index.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "relative", "root_file.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "relative", "subdir", "subdir_index.txt"))
    @test !isfile(joinpath(@__DIR__, "builds", "relative", "subdir", "subdir_file.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "relative-workdir", "root_index.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "relative-workdir", "root_file.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "relative-workdir", "subdir_index.txt"))
    @test  isfile(joinpath(@__DIR__, "builds", "relative-workdir", "subdir_file.txt"))
end
