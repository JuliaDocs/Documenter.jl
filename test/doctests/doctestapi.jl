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
import IOCapture

# Test the Documenter.doctest function
# ------------------------------------
function run_doctest(f, args...; kwargs...)
    (result, success, backtrace, output) =
        c = IOCapture.capture(rethrow = InterruptException) do
        # Running inside a Task to make sure that the parent testsets do not interfere.
        t = Task(() -> doctest(args...; kwargs...))
        schedule(t)
        # if an exception happens, it gets propagated
        try
            fetch(t)
        catch e
            # Note: in Julia 1.3 fetch no longer throws the exception direction, but instead
            # wraps it in a TaskFailedException (https://github.com/JuliaLang/julia/pull/32814).
            rethrow(t.exception)
        end
    end

    @debug """run_doctest($args;, $kwargs) -> $(c.error ? "fail" : "success")
    ------------------------------------ output ------------------------------------
    $(c.output)
    --------------------------------------------------------------------------------
    """ c.value stacktrace(c.backtrace)

    return f(c.value, !c.error, c.backtrace, c.output)
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

"""
```jldoctest
julia> println("global filter")
global FILTER
```

```jldoctest; filter = r"local (filter|FILTER)"
julia> println("local filter")
local FILTER
```
"""
module DoctestFilters end

"""
```jldoctest
julia> map(tuple, 1/(i+j) for i=1:2, j=1:2, [1:4;])
ERROR: syntax: invalid iteration specification
```
```jldoctest
julia> 1.2.3
ERROR: syntax: invalid numeric constant "1.2."
```
```jldoctest
println(9.8.7)
# output
ERROR: syntax: invalid numeric constant "9.8."
```
```jldoctest
julia> Meta.ParseError("foo")
Base.Meta.ParseError("foo")

julia> Meta.ParseError("foo") |> throw
ERROR: Base.Meta.ParseError("foo")
Stacktrace:
[...]
```
"""
module ParseErrorSuccess_1x00 end

"""
```jldoctest
julia> map(tuple, 1/(i+j) for i=1:2, j=1:2, [1:4;])
ERROR: ParseError:
# Error @ none:1:44
map(tuple, 1/(i+j) for i=1:2, j=1:2, [1:4;])
#                                          └ ── invalid iteration spec: expected one of `=` `in` or `∈`
Stacktrace:
[...]
```
```jldoctest
julia> 1.2.3
ERROR: ParseError:
# Error @ none:1:1
1.2.3
└──┘ ── invalid numeric constant
[...]
```
```jldoctest
println(9.8.7)
# output
ERROR: ParseError:
# Error @ none:1:9
println(9.8.7)
#       └──┘ ── invalid numeric constant
[...]
```
```jldoctest
julia> Meta.ParseError("foo")
Base.Meta.ParseError("foo", nothing)

julia> Meta.ParseError("foo") |> throw
ERROR: ParseError("foo")
Stacktrace:
[...]
```
"""
module ParseErrorSuccess_1x10 end
# The JuliaSyntax swap in 1.10 changed the printing of parse errors quite considerably
ParseErrorSuccess() = (VERSION >= v"1.10.0-DEV.1520") ? ParseErrorSuccess_1x10 : ParseErrorSuccess_1x00

"""
```jldoctest
julia> map(tuple, 1/(i+j) for i=1:2, j=1:2, [1:4;])
ERROR: syntax: invalid iteration specificationX
```
"""
module ParseErrorFail end

"""
```jldoctest
println(9.8.7)
# output
ERROR: syntax: invalid numeric constant "1.2."
```
"""
module ScriptParseErrorFail end

module PR1075
    "x \$(42) y"
    function qux end
    "..."
    function foo end
    @doc @doc(foo) function bar end
    @doc @doc(bar) function baz end
end

"""
```jldoctest;
julia> 2 + 2
4
```
"""
module BadDocTestKwargs1 end

"""
```jldoctest; %%%
julia> 2 + 2
4
```
"""
module BadDocTestKwargs2 end

"""
```jldoctest; foo
julia> 2 + 2
4
```
"""
module BadDocTestKwargs3 end

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

    # DoctestFilters
    df = [r"global (filt|FILT)(er|ER)" => s"global \1", r"global (filt|FILT)"]
    run_doctest(nothing, [DoctestFilters], doctestfilters = df) do result, success, backtrace, output
        @test success
    end

    # Parse errors in doctests (https://github.com/JuliaDocs/Documenter.jl/issues/1046)
    run_doctest(nothing, [ParseErrorSuccess()]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end
    run_doctest(nothing, [ParseErrorFail]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    run_doctest(nothing, [ScriptParseErrorFail]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end

    # PR 1075
    run_doctest(nothing, [PR1075]) do result, success, backtrace, output
        @test success
        @test result isa Test.DefaultTestSet
    end

    # Issue 1556, PR 1557
    run_doctest(nothing, [BadDocTestKwargs1]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    run_doctest(nothing, [BadDocTestKwargs2]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
    run_doctest(nothing, [BadDocTestKwargs3]) do result, success, backtrace, output
        @test !success
        @test result isa TestSetException
    end
end

end # module
