# To fix all the output reference, run this file with
#
#    DOCUMENTER_FIXTESTS= julia doctests.jl
#
# If the inputs and outputs are giving you trouble, you can run the tests with
#
#    JULIA_DEBUG=DocTestsTests julia doctests.jl
#
# TODO: Combine the makedocs calls and stdout files. Also, allow running them one by one.
#
module DocTestsTests
using Test
using Documenter
using Documenter.Utilities.TextDiff: Diff, Words

include("src/FooWorking.jl")
include("src/FooBroken.jl")
include("src/NoMeta.jl")

const builds_directory = joinpath(@__DIR__, "builds")
ispath(builds_directory) && rm(builds_directory, recursive=true)
mkpath(builds_directory)

function run_makedocs(f, mdfiles, modules=Module[]; kwargs...)
    dir = mktempdir(builds_directory)
    srcdir = joinpath(dir, "src"); mkpath(srcdir)

    for mdfile in mdfiles
        cp(joinpath(@__DIR__, "src", mdfile), joinpath(srcdir, mdfile))
    end

    (result, success, backtrace, output) = Documenter.Utilities.withoutput() do
        makedocs(
            sitename = " ",
            root = dir,
            modules = modules;
            kwargs...
        )
    end

    @debug """run_makedocs($mdfiles, modules=$modules) -> $(success ? "success" : "fail")
    ------------------------------------ output ------------------------------------
    $(output)
    --------------------------------------------------------------------------------
    """ result stacktrace(backtrace) dir

    write(joinpath(dir, "output"), output)
    write(joinpath(dir, "output.onormalize"), onormalize(output))
    open(joinpath(dir, "result"), "w") do io
        show(io, "text/plain", result)
        println(io, "-"^80)
        show(io, "text/plain", stacktrace(backtrace))
    end

    f(result, success, backtrace, output)
end

function printoutput(result, success, backtrace, output)
    printstyled("="^80, color=:cyan); println()
    println(output)
    printstyled("-"^80, color=:cyan); println()
    println(repr(result))
    printstyled("-"^80, color=:cyan); println()
end

function onormalize(s)
    # Runs a bunch of regexes on captured documenter output strings to remove any machine /
    # platform / environment / time dependent parts, so that it would actually be possible
    # to compare Documenter output to previously generated reference outputs.

    # Remove filesystem paths in doctests failures
    s = replace(s, r"(doctest failure in )(.*)$"m => s"\1{PATH}")
    s = replace(s, r"(@ Documenter.DocTests )(.*)$"m => s"\1{PATH}")

    # Remove stacktraces
    s = replace(s, r"(│\s+Stacktrace:)(\n(│\s+)\[[0-9]+\].*)*" => s"\1\\n\3{STACKTRACE}")

    return s
end

function is_same_as_file(output, filename)
    # Compares output to the contents of a reference file. Runs onormalize on both strings
    # before doing a character-by-character comparison.
    fixtests = haskey(ENV, "DOCUMENTER_FIXTESTS")
    success = if isfile(filename)
        reference = read(filename, String)
        if onormalize(reference) != onormalize(output)
            diff = Diff{Words}(onormalize(reference), onormalize(output))
            @error """Output does not agree with reference file
            ref: $(filename)
            ------------------------------------ output ------------------------------------
            $(output)
            ---------------------------------- reference  ----------------------------------
            $(reference)
            ------------------------------ onormalize(output) ------------------------------
            $(onormalize(output))
            ---------------------------- onormalize(reference)  ----------------------------
            $(onormalize(reference))
            """ diff
            false
        else
            true
        end
    else
        fixtests || error("Missing reference file: $(filename)")
        false
    end
    if fixtests && !success
        @info "Updating $(filename)"
        write(filename, output)
        success = true
    end
    return success
end

rfile(filename) = joinpath(@__DIR__, "stdouts", filename)

@testset "doctesting" begin
    # So, we have 4 doctests: 2 in a docstring, 2 in an .md file. One of either pair is
    # OK, other is broken. Here we first test all possible combinations of these doctest
    # with strict = true to make sure that the doctests are indeed failing.
    #
    # Some tests are broken due to https://github.com/JuliaDocs/Documenter.jl/issues/974
    run_makedocs(["working.md"]; strict=true) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.1"))
    end

    run_makedocs(["broken.md"]; strict=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.2"))
    end

    run_makedocs(["working.md", "fooworking.md"]; modules=[FooWorking], strict=true) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.3"))
    end

    run_makedocs(["working.md", "foobroken.md"]; modules=[FooBroken], strict=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.4"))
    end

    run_makedocs(["broken.md", "fooworking.md"]; modules=[FooWorking], strict=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.5"))
    end

    run_makedocs(["broken.md", "foobroken.md"]; modules=[FooBroken], strict=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.6"))
    end

    run_makedocs(["fooworking.md"]; modules=[FooWorking], strict=true) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.7"))
    end

    run_makedocs(["foobroken.md"]; modules=[FooBroken], strict=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.8"))
    end

    # Here we try the default (strict = false) -- output should say that doctest failed, but
    # success should still be true.
    run_makedocs(["working.md"]) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.11"))
    end

    run_makedocs(["broken.md"]) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.12"))
    end

    # Tests for doctest = :only. The outout should reflect that the docs themselves do not
    # get built.
    run_makedocs(["working.md"]; modules=[FooWorking], doctest = :only) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.21"))
    end

    run_makedocs(["working.md"]; modules=[FooBroken], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.22"))
    end

    run_makedocs(["broken.md"]; modules=[FooWorking], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.23"))
    end

    run_makedocs(["broken.md"]; modules=[FooBroken], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.24"))
    end
    # strict gets ignored with doctest = :only
    run_makedocs(["broken.md"]; modules=[FooBroken], doctest = :only, strict=false) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.25"))
    end

    # DocTestSetup in modules
    run_makedocs([]; modules=[NoMeta], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile("stdout.31"))
    end
    # Now, let's use Documenter's APIs to add the necessary meta information
    DocMeta.setdocmeta!(NoMeta, :DocTestSetup, :(baz(x) = 2x))
    run_makedocs([]; modules=[NoMeta], doctest = :only) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile("stdout.32"))
    end
end

end # module
