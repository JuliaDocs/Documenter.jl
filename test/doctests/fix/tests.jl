# Tests for doctest = :fix
#
# DOCUMENTER_TEST_DEBUG= JULIA_DEBUG=all julia test/doctests/fix/tests.jl
#
module DocTestFixTest
using Documenter: Documenter
using Test
include("../../TestUtilities.jl"); using Main.TestUtilities: @quietly

# Type to reliably show() objects across Julia versions:
@eval Main begin
    struct ShowWrap
        s::String
    end
    Base.show(io::IO, x::ShowWrap) = write(io, x.s)
    const DocTestFixArray_1234 = Main.ShowWrap("4×1×1 Array{Int64,3}:\n[:, :, 1] =\n 1\n 2\n 3\n 4")
    const DocTestFixArray_2468 = Main.ShowWrap("4×1×1 Array{Int64,3}:\n[:, :, 1] =\n 2\n 4\n 6\n 8")
end

mktempdir_nocleanup(dir) = mktempdir(dir, cleanup = false)

function normalize_line_endings(filename)
    s = read(filename, String)
    return replace(s, "\r\n" => "\n")
end

# 1.12 introduced stricted world age requirements, so we need to do some Base.invokelatest
# shenaningans to make sure that we are passing the updated Foo module to makedocs.
_Foo() = Base.invokelatest(getfield, @__MODULE__, :Foo)
makedocs(args...; kwargs...) = Base.invokelatest(Documenter.makedocs, args...; kwargs...)

function test_doctest_fix(dir)
    srcdir = mktempdir_nocleanup(dir)
    builddir = mktempdir_nocleanup(dir)
    @debug "Testing doctest = :fix" srcdir builddir

    # Pkg.add changes permission of files to read-only,
    # so instead of copying them we read + write.
    src_jl = joinpath(srcdir, "src.jl")
    index_md = joinpath(srcdir, "index.md")
    write(index_md, normalize_line_endings(joinpath(@__DIR__, "broken.md")))
    write(src_jl, normalize_line_endings(joinpath(@__DIR__, "broken.jl")))

    # fix up
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=:fix"
    @show _Foo()
    @quietly makedocs(sitename = "-", modules = [_Foo()], source = srcdir, build = builddir, doctest = :fix)

    # check that the doctests are passing now
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=true"
    @quietly makedocs(sitename = "-", modules = [_Foo()], source = srcdir, build = builddir)

    # Load the expected results and adapt to various Julia versions:
    md_result = normalize_line_endings(joinpath(@__DIR__, "fixed.md"))
    if VERSION < v"1.11"
        # 1.11 Starts printing "in `Main`", so we remove that from the expected output.
        md_result = replace(md_result, r"UndefVarError: `([^`]*)` not defined in `Main`" => s"UndefVarError: `\1` not defined")
    end
    if VERSION < v"1.11"
        # 1.11 started printing the 'Suggestion: check for spelling errors or missing imports.' messages
        # for UndefVarError, so we remove them from the expected output.
        md_result = replace(md_result, r"UndefVarError: `([^`]*)` not defined\nSuggestion: .+" => s"UndefVarError: `\1` not defined")
    end
    if VERSION < v"1.7"
        # The UndefVarError prints the backticks around the variable name in 1.7+, so we need to remove them.
        md_result = replace(md_result, r"UndefVarError: `([^`]*)` not defined" => s"UndefVarError: \1 not defined")
    end

    # test that we obtain the expected output
    @test normalize_line_endings(index_md) == md_result
    return @test normalize_line_endings(src_jl) == normalize_line_endings(joinpath(@__DIR__, "fixed.jl"))
end

@testset "doctest fixing" begin
    if haskey(ENV, "DOCUMENTER_TEST_DEBUG")
        # in this mode the directories remain
        test_doctest_fix(mktempdir_nocleanup(@__DIR__))
    else
        mktempdir(test_doctest_fix, @__DIR__)
    end
end

end # module
