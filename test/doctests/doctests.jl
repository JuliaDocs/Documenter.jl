# To fix all the output reference files, run this file with
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
using Documenter.TextDiff: Diff, Words
import IOCapture

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
    # Create a dummy index.md file so that we wouldn't generate the "can't generated landing
    # page" warning.
    touch(joinpath(srcdir, "index.md"))

    c = IOCapture.capture(rethrow = InterruptException) do
        # In case JULIA_DEBUG is set to something, we'll override that, so that we wouldn't
        # get some unexpected debug output from makedocs.
        withenv("JULIA_DEBUG" => "") do
            makedocs(
                sitename = " ",
                format = Documenter.HTML(edit_link = "master"),
                root = dir,
                modules = modules;
                kwargs...
            )
        end
    end

    @debug """run_makedocs($mdfiles, modules=$modules) -> $(c.error ? "fail" : "success")
    ------------------------------------ output ------------------------------------
    $(c.output)
    --------------------------------------------------------------------------------
    """ c.value stacktrace(c.backtrace) dir

    write(joinpath(dir, "output"), c.output)
    write(joinpath(dir, "output.onormalize"), onormalize(c.output))
    open(joinpath(dir, "result"), "w") do io
        show(io, "text/plain", c.value)
        println(io, "-"^80)
        show(io, "text/plain", stacktrace(c.backtrace))
    end

    f(c.value, !c.error, c.backtrace, c.output)
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

    # We need to make sure that, if we're running the tests on Windows, that we'll have consistent
    # line breaks. So we'll normalize CRLF to LF.
    if Sys.iswindows()
        s = replace(s, "\r\n" => "\n")
    end

    # Remove filesystem paths in doctests failures
    s = replace(s, r"(doctest failure in )(.*)$"m => s"\1{PATH}")
    s = replace(s, r"(@ Documenter )(.*)$"m => s"\1{PATH}")
    s = replace(s, r"(top-level scope at )(.*)$"m => s"\1{PATH}")
    # Remove line numbers from Julia source line references (like in stacktraces)
    # Note: currently only supports top-level files (e.g. ./error.jl, but not ./strings/basic.jl)
    s = replace(s, r"Base \.[\\/]([A-Za-z0-9\.]+):[0-9]+\s*$"m => s"Base ./\1:LL")

    # Remove stacktraces
    s = replace(s, r"(│\s+Stacktrace:)(\n(│\s+)\[[0-9]+\].*)(\n(│\s+)@.*)?+" => s"\1\\n\3{STACKTRACE}")

    # In Julia 1.9, the printing of UndefVarError has slightly changed (added backticks around binding name)
    s = replace(s, r"UndefVarError: `([A-Za-z0-9.]+)` not defined"m => s"UndefVarError: \1 not defined")

    # Remove floating point numbers
    s = replace(s, r"([0-9]*\.[0-9]{8})[0-9]+" => s"\1***")

    return s
end

function is_same_as_file(output, filename)
    # Compares output to the contents of a reference file. Runs onormalize on both strings
    # before doing a character-by-character comparison.
    fixtests = haskey(ENV, "DOCUMENTER_FIXTESTS")
    success = if isfile(filename)
        reference = read(filename, String)
        if onormalize(reference) != onormalize(output)
            @error """Output does not agree with reference file
            ref: $(filename)
            """
            ps(s::AbstractString) = printstyled(stdout, s, '\n'; color=:magenta, bold=true)
            "------------------------------------ output ------------------------------------" |> ps
            output |> println
            "---------------------------------- reference -----------------------------------" |> ps
            reference |> println
            "------------------------------ onormalize(output) ------------------------------" |> ps
            onormalize(output) |> println
            "---------------------------- onormalize(reference) -----------------------------" |> ps
            onormalize(reference) |> println
            "------------------------------------- diff -------------------------------------" |> ps
            diff = Diff{Words}(onormalize(reference), onormalize(output))
            diff |> println
            "------------------------------------- end --------------------------------------" |> ps
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

const MINVERSION = v"0.0.0-"

function rfile(index::Integer)
    reference_directory = joinpath(@__DIR__, "stdouts")
    reference_file, versionmatch = "", MINVERSION
    for filename in readdir(reference_directory)
        m = match(r"^(?<index>[0-9]+)(?:\.v(?<major>[[0-9]+)_(?<minor>[0-9]+))?\.stdout$", filename)
        # If the regex doesn't match, then we're not interested in this file
        isnothing(m) && continue
        # Similarly, we're only interested in collecting up the reference files that match `index`
        m[:index] == string(index) || continue
        # Parse the version, or stick to a fallback value if the filename does not contain a version number.
        version = if isnothing(m[:major])
            # This is the fallback version, matching everything
            MINVERSION
        else
            major, minor = parse(Int, m[:major]), parse(Int, m[:minor])
            # Format as 'v$(major).$(minor).0-'. This should match every version within a minor version,
            # including all the -DEV etc. prereleases.
            VersionNumber(major, minor, 0, ("",))
        end
        if (version <= VERSION) && (version >= versionmatch)
            reference_file, versionmatch = joinpath(reference_directory, filename), version
        end
    end
    # If `reference_file` is still an empty string, then the loop above failed because the appropriate
    # reference file is missing.
    isempty(reference_file) && error("Unable to find reference files for $(index).stdout, VERSION=$VERSION")
    return reference_file
end

@testset "doctesting" begin
    # So, we have 4 doctests: 2 in a docstring, 2 in an .md file. One of either pair is
    # OK, other is broken. Here we first test all possible combinations of these doctest
    # to make sure that the doctests are indeed failing.
    #
    # Some tests are broken due to https://github.com/JuliaDocs/Documenter.jl/issues/974
    run_makedocs(["working.md"]) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(1))
    end

    run_makedocs(["broken.md"]) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(2))
    end

    run_makedocs(["working.md", "fooworking.md"]; modules=[FooWorking]) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(3))
    end

    run_makedocs(["working.md", "foobroken.md"]; modules=[FooBroken]) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(4))
    end

    run_makedocs(["broken.md", "fooworking.md"]; modules=[FooWorking]) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(5))
    end

    for warnonly in (false, :autodocs_block, Documenter.except(:doctest))
        run_makedocs(["broken.md", "foobroken.md"]; modules=[FooBroken], warnonly) do result, success, backtrace, output
            @test !success
            @test is_same_as_file(output, rfile(6))
        end
    end

    run_makedocs(["fooworking.md"]; modules=[FooWorking]) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(7))
    end

    run_makedocs(["foobroken.md"]; modules=[FooBroken]) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(8))
    end

    # Here we try the default (strict = false) -- output should say that doctest failed, but
    # success should still be true.
    run_makedocs(["working.md"]; warnonly=true) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(11))
    end

    # Three options that do not strictly check doctests, including testing the default
    for warnonly_kw in ((; warnonly=true), (; warnonly=Documenter.except(:meta_block)))
        run_makedocs(["broken.md"]; warnonly_kw...) do result, success, backtrace, output
            @test success
            @test is_same_as_file(output, rfile(12))
        end
    end

    # Tests for doctest = :only. The output should reflect that the docs themselves do not
    # get built.
    run_makedocs(["working.md"]; modules=[FooWorking], doctest = :only) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(21))
    end

    run_makedocs(["working.md"]; modules=[FooBroken], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(22))
    end

    run_makedocs(["broken.md"]; modules=[FooWorking], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(23))
    end

    run_makedocs(["broken.md"]; modules=[FooBroken], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(24))
    end
    # warnonly gets ignored with doctest = :only
    run_makedocs(["broken.md"]; modules=[FooBroken], doctest = :only, warnonly=true) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(25))
    end

    # DocTestSetup in modules
    run_makedocs([]; modules=[NoMeta], doctest = :only) do result, success, backtrace, output
        @test !success
        @test is_same_as_file(output, rfile(31))
    end
    # Now, let's use Documenter's APIs to add the necessary meta information
    DocMeta.setdocmeta!(NoMeta, :DocTestSetup, :(baz(x) = 2x))
    run_makedocs([]; modules=[NoMeta], doctest = :only) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(32))
    end

    # Tests for special REPL softscope
    softscope_src = (VERSION >= v"1.11.0-") ? "softscope.v1_11.md" : "softscope.md"
    run_makedocs([softscope_src]; warnonly=true) do result, success, backtrace, output
        @test success
        @test is_same_as_file(output, rfile(41))
    end
end

end # module
