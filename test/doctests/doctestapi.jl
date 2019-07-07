# Tests for the public doctest() function
#
# If the tests are giving you trouble, you can run the tests with
#
#    JULIA_DEBUG=DocTestAPITests julia doctests.jl
#
# TODO: Combine the makedocs calls and stdout files. Also, allow running them one by one.
#
module DocTestAPITests
using Test
using Documenter

# Test the Documenter.doctest function
# ------------------------------------
function run_doctest(f, args...; kwargs...)
    (result, success, backtrace, output) = Documenter.Utilities.withoutput() do
        # Running inside a Task to make sure that the parent testsets do not interfere.
        t = Task(() -> doctest(args...; kwargs...))
        schedule(t)
        fetch(t) # if an exception happens, it gets propagated
    end

    @debug """run_doctest($args;, $kwargs) -> $(success ? "success" : "fail")
    ------------------------------------ output ------------------------------------
    $(output)
    --------------------------------------------------------------------------------
    """ result stacktrace(backtrace)

    f(result, success, backtrace, output)
end

"""
```jldoctest
julia> 2 + 2
4
```
"""
module DocTest1 end

"""
```jldoctest
julia> 2 + 2
5
```
"""
module DocTest2 end

"""
```jldoctest
julia> x
42
```
"""
module DocTest3 end

module DocTest4
    """
    ```jldoctest
    julia> x
    42
    ```
    """
    function foo end
    module Submodule
        """
        ```jldoctest
        julia> x + 1
        43
        ```
        """
        function foo end
    end
end

module DocTest5
    """
    ```jldoctest
    julia> x
    42
    ```
    """
    function foo end
    """
    ```jldoctest
    julia> x
    4200
    ```
    """
    module Submodule
        """
        ```jldoctest
        julia> x + 1
        4201
        ```
        """
        function foo end
    end
end

@testset "Documenter.doctest" begin
    # DocTest1
    run_doctest(nothing, [DocTest1]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end

    # DocTest2
    run_doctest(nothing, [DocTest2]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end

    # DocTest3
    run_doctest(nothing, [DocTest3]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    DocMeta.setdocmeta!(DocTest3, :DocTestSetup, :(x = 42))
    run_doctest(nothing, [DocTest3]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end

    # DocTest4
    run_doctest(nothing, [DocTest4]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    DocMeta.setdocmeta!(DocTest4, :DocTestSetup, :(x = 42))
    run_doctest(nothing, [DocTest4]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    DocMeta.setdocmeta!(DocTest4, :DocTestSetup, :(x = 42); recursive = true, warn = false)
    run_doctest(nothing, [DocTest4]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end

    # DocTest5
    run_doctest(nothing, [DocTest5]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    DocMeta.setdocmeta!(DocTest5, :DocTestSetup, :(x = 42))
    DocMeta.setdocmeta!(DocTest5.Submodule, :DocTestSetup, :(x = 4200))
    run_doctest(nothing, [DocTest5]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end
end

end # module
