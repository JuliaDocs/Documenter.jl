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
    # Starting from 1.13, the Julia test infrastructure uses ScopedValues
    # to handle testsets. So the original task-based approach does not work
    # anymore for "detaching" the doctest testsets from the test suite.
    # But we can manipulate the internal Test module state instead.
    # X-ref: https://github.com/JuliaLang/julia/pull/53462
    e = try
        @static if VERSION >= v"1.13-"
            Base.ScopedValues.@with(
                Test.CURRENT_TESTSET => Test.FallbackTestSet(),
                Test.TESTSET_DEPTH => 0,
                doctest(Documenter)
            )
        else
            fetch(schedule(Task(() -> doctest(Documenter))))
        end
    catch e
        @static if VERSION >= v"1.13-"
            e
        else
            # If we use the task-based approach, we need to unwrap the error
            @test e isa TaskFailedException
            e.task.exception
        end
    end
    println("^^^ Expected error output.")
    @test e isa TestSetException
    rm(tmpfile)
    @test !isfile(tmpfile)
end
