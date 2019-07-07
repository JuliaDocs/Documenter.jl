using Documenter
using Test

@testset "Manual doctest" begin
    @info "Doctesting Documenter manual"
    doctest(Documenter)

    # Make sure that doctest() fails if there is a manual page with a failing doctest
    # Will need to run it in a Task though, so that we could easily capture the error.
    @info "Doctesting Documenter manual w/ failing doctest"
    tmpfile = joinpath(@__DIR__, "..", "docs", "src", "lib", "internals", "tmpfile.md")
    write(tmpfile, """
    # Temporary source file w/ failing doctest
    ```jldoctest
    julia> 2 + 2
    42
    ```
    """)
    @test isfile(tmpfile)
    @test_throws TestSetException fetch(schedule(Task(() -> doctest(Documenter))))
    println("^^^ Expected error output.")
    rm(tmpfile)
    @test !isfile(tmpfile)
end
