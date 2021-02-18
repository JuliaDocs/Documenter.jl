module TestUtilities
using Test
import IOCapture

export @quietly

const QUIETLY_LOG = joinpath(@__DIR__, "quietly.log")

__init__() = isfile(QUIETLY_LOG) && rm(QUIETLY_LOG)

struct QuietlyException <: Exception
    exception
    backtrace
end

function Base.showerror(io::IO, e::QuietlyException)
    println(io, "@quietly hit an exception ($(typeof(e.exception))):")
    showerror(io, e.exception, e.backtrace)
end

function _quietly(f, expr, source)
    c = IOCapture.iocapture(f; throwerrors = :interrupt)
    haskey(ENV, "DOCUMENTER_TEST_QUIETLY") && open(QUIETLY_LOG; write=true, append=true) do io
        println(io, "@quietly: c.error = $(c.error) / $(sizeof(c.output)) bytes of output captured")
        println(io, "@quietly: $(source.file):$(source.line)")
        println(io, "@quietly: typeof(result) = ", typeof(c.value))
        println(io, "@quietly: STDOUT")
        println(io, output)
        println(io, "@quietly: end of STDOUT")
        if success
            println(io, "@quietly: result =")
            println(io, c.value)
        else
            println(io, "@quietly: result (error) =")
            showerror(io, c.value, c.backtrace)
        end
    end
    if !c.error
        printstyled("@quietly: success, $(sizeof(c.output)) bytes of output hidden\n"; color=:magenta)
        return c.value
    else
        @error """
        An error was thrown in @quietly, $(sizeof(c.output)) bytes of output captured
        $(typeof(c.value)) at $(source.file):$(source.line) in expression:
        $(expr)
        """
        if !isempty(c.output)
            printstyled("$("="^21) @quietly: output from the expression $("="^21)\n"; color=:magenta)
            print(c.output)
            last(c.output) != "\n" && println()
            printstyled("$("="^27) @quietly: end of output $("="^28)\n"; color=:magenta)
        end
        throw(QuietlyException(c.value, c.backtrace))
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

end
