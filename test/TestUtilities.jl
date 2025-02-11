isdefined(Main, :TestUtilities) || @eval Main module TestUtilities
using Test
import IOCapture

export @quietly, trun

const QUIETLY_LOG_DIR = joinpath(@__DIR__, "quietly-logs")
const QUIETLY_LOG_COUNTER = Ref{Int}(0)

quietly_logs_enabled() = haskey(ENV, "DOCUMENTER_TEST_QUIETLY")

function quietly_logfile(n)
    logid = lpad(n, 4, '0')
    return logid, joinpath(QUIETLY_LOG_DIR, "quietly.$(logid).log")
end
function quietly_next_log()
    quietly_logs_enabled() || return nothing, nothing
    isdir(QUIETLY_LOG_DIR) || mkdir(QUIETLY_LOG_DIR)
    # Find the next available log file
    logid, logfile = quietly_logfile(QUIETLY_LOG_COUNTER[])
    while isfile(logfile)
        QUIETLY_LOG_COUNTER[] += 1
        logid, logfile = quietly_logfile(QUIETLY_LOG_COUNTER[])
    end
    return logid, logfile
end

function __init__()
    # We only clean up the old log files if DOCUMENTER_TEST_QUIETLY is set
    quietly_logs_enabled() || return
    isdir(QUIETLY_LOG_DIR) && rm(QUIETLY_LOG_DIR, recursive = true)
    return
end

struct QuietlyException <: Exception
    logid::Union{String, Nothing}
    exception
    backtrace
end

function Base.showerror(io::IO, e::QuietlyException)
    prefix = isnothing(e.logid) ? "@quietly" : "@quietly[$(e.logid)]"
    println(io, "$(prefix) hit an exception ($(typeof(e.exception))):")
    showerror(io, e.exception, e.backtrace)
end

function _quietly(f, expr, source)
    c = IOCapture.capture(f; rethrow = InterruptException)
    logid, logfile = quietly_next_log()
    isnothing(logid) || open(logfile; write = true, append = true) do io
        println(io, "@quietly: c.error = $(c.error) / $(sizeof(c.output)) bytes of output captured")
        println(io, "@quietly: $(source.file):$(source.line)")
        println(io, "@quietly: typeof(result) = ", typeof(c.value))
        println(io, "@quietly: STDOUT")
        println(io, c.output)
        println(io, "@quietly: end of STDOUT")
        if c.error
            println(io, "@quietly: result (error) =")
            showerror(io, c.value, c.backtrace)
        else
            println(io, "@quietly: result =")
            println(io, c.value)
        end
    end
    prefix = isnothing(logid) ? "@quietly" : "@quietly[$logid]"
    if c.error
        @error """
        $(prefix): an error was thrown, $(sizeof(c.output)) bytes of output captured
        $(typeof(c.value)) at $(source.file):$(source.line) in expression:
        $(expr)
        """ exception = (c.value, c.backtrace)
        if !isempty(c.output)
            printstyled("$("="^21) $(prefix): output from the expression $("="^21)\n"; color = :magenta)
            print(c.output)
            last(c.output) != "\n" && println()
            printstyled("$("="^27) $(prefix): end of output $("="^28)\n"; color = :magenta)
        end
        throw(QuietlyException(logid, c.value, c.backtrace))
    elseif c.value isa Test.DefaultTestSet && !is_success(c.value)
        @error """
        $(prefix): a testset with failures, $(sizeof(c.output)) bytes of output captured
        $(typeof(c.value)) at $(source.file):$(source.line) in expression:
        $(expr)
        """ TestSet = c.value
        if !isempty(c.output)
            printstyled("$("="^21) $(prefix): output from the expression $("="^21)\n"; color = :magenta)
            print(c.output)
            last(c.output) != "\n" && println()
            printstyled("$("="^27) $(prefix): end of output $("="^28)\n"; color = :magenta)
        end
        return c.value
    else
        printstyled("$(prefix): success, $(sizeof(c.output)) bytes of output hidden\n"; color = :magenta)
        return c.value
    end
end
macro quietly(expr)
    orig_expr = Expr(:inert, expr)
    source = QuoteNode(__source__)
    return quote
        _quietly($orig_expr, $source) do
            $(esc(expr))
        end
    end
end

is_success(testset::Test.DefaultTestSet) = !(testset.anynonpass || !is_success(testset.results))
is_success(ts::AbstractArray) = all(is_success.(ts))
is_success(::Test.Fail) = false
is_success(::Test.Pass) = true
function is_success(x)
    @warn "Unimplemented TestUtilities.is_success method" typeof(x) x
    return false
end

function trun(cmd::Base.AbstractCmd)
    buffer = IOBuffer()
    cmd_redirected = pipeline(cmd; stdin = devnull, stdout = buffer, stderr = buffer)
    try
        run(cmd_redirected)
        return true
    catch e
        @error """
        Running external program $(cmd) failed, output:
        $(String(take!(buffer)))
        """ exception = (e, catch_backtrace())
        return false
    end
end

end
