module TestUtilities
using Test
using Documenter.Utilities: withoutput

export @quietly

struct QuietlyException <: Exception
    exception
    backtrace
end

function Base.showerror(io::IO, e::QuietlyException)
    println(io, "@quietly hit an exception ($(typeof(e.exception))):")
    showerror(io, e.exception, e.backtrace)
end

function _quietly(f, expr, source)
    result, success, backtrace, output = withoutput(f)
    if success
        printstyled("@quietly: success, $(sizeof(output)) bytes of output hidden\n"; color=:magenta)
        return result
    else
        @error """
        An error was thrown in @quietly, $(sizeof(output)) bytes of output captured
        $(typeof(result)) at $(source.file):$(source.line) in expression:
        $(expr)
        $(sizeof(output)) bytes of output captured
        """
        if !isempty(output)
            printstyled("$("="^21) @quietly: output from the expression $("="^21)\n"; color=:magenta)
            print(output)
            last(output) != "\n" && println()
            printstyled("$("="^27) @quietly: end of output $("="^28)\n"; color=:magenta)
        end
        throw(QuietlyException(result, backtrace))
    end
end
macro quietly(expr)
    orig_expr = Expr(:inert, expr)
    source = QuoteNode(__source__)
    quote
        _quietly($orig_expr, $source) do
            $(esc(expr))
        end
    end
end

"Runs the tests for TestUtilities"
function test()
    @testset "TestUtilities" begin
        # Various tests use Utilities.withoutput to capture output. So we'll first make sure
        # that it is working properly.
        @testset "withoutput" begin
            let (result, success, backtrace, output) = withoutput() do
                    println("test stdout")
                end
                @test success
                @test result === nothing
                @test output == "test stdout\n"
            end
            let (result, success, backtrace, output) = withoutput(() -> 42)
                @test success
                @test result === 42
                @test output == ""
            end
            let (result, success, backtrace, output) = withoutput(() -> error("test error"))
                @test !success
                @test result isa ErrorException
                @test output == ""
            end
        end
    end
end
end
