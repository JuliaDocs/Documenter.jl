using Documenter
using Test

@testset "Manual doctest" begin
    @info "Doctesting Documenter manual"
    doctest(Documenter)

    # Make sure that doctest() fails if there is a manual page with a failing doctest
    # Will need to run it in a Task though, so that we could easily capture the error.
    @info "Doctesting Documenter manual w/ failing doctest"
    tmpfile = joinpath(@__DIR__, "..", "docs", "src", "lib", "internals", "tmpfile.md")
    write(
        tmpfile, """
        # Temporary source file w/ failing doctest
        ```jldoctest
        julia> 2 + 2
        42
        ```
        """
    )
    @test isfile(tmpfile)
    # Note: in Julia 1.3 fetch no longer throws the exception direction, but instead
    # wraps it in a TaskFailedException (https://github.com/JuliaLang/julia/pull/32814).
    if isdefined(Base, :TaskFailedException)
        @test_throws TaskFailedException fetch(schedule(Task(() -> doctest(Documenter))))
    else
        @test_throws TestSetException fetch(schedule(Task(() -> doctest(Documenter))))
    end
    println("^^^ Expected error output.")
    rm(tmpfile)
    @test !isfile(tmpfile)
end
