# Tests for doctest = :fix
#
# DOCUMENTER_TEST_DEBUG= JULIA_DEBUG=all julia test/doctests/fix/tests.jl
#
isdefined(@__MODULE__, :TestUtilities) || (include("../../TestUtilities.jl"); using .TestUtilities)
module DocTestFixTest
using Documenter, Test
using ..TestUtilities: @quietly

# Type to reliably show() objects across Julia versions:
@eval Main begin
    struct ShowWrap
        s :: String
    end
    Base.show(io::IO, x::ShowWrap) = write(io, x.s)
    const DocTestFixArray_1234 = Main.ShowWrap("4×1×1 Array{Int64,3}:\n[:, :, 1] =\n 1\n 2\n 3\n 4")
    const DocTestFixArray_2468 = Main.ShowWrap("4×1×1 Array{Int64,3}:\n[:, :, 1] =\n 2\n 4\n 6\n 8")
end

# The version check is necessary due to a behaviour change in https://github.com/JuliaLang/julia/pull/32851
mktempdir_nocleanup(dir) = VERSION >= v"1.3.0-alpha.112" ? mktempdir(dir, cleanup = false) : mktempdir(dir)

function test_doctest_fix(dir)
    srcdir = mktempdir_nocleanup(dir)
    builddir = mktempdir_nocleanup(dir)
    @debug "Testing doctest = :fix" srcdir builddir

    # Pkg.add changes permission of files to read-only,
    # so instead of copying them we read + write.
    write(joinpath(srcdir, "index.md"), read(joinpath(@__DIR__, "broken.md")))
    write(joinpath(srcdir, "src.jl"), read(joinpath(@__DIR__, "broken.jl")))

    # fix up
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=:fix"
    @quietly makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, doctest = :fix)

    # test that strict = true works
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=true"
    @quietly makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, strict = true)

    # also test that we obtain the expected output
    @test read(joinpath(srcdir, "index.md"), String) == read(joinpath(@__DIR__, "fixed.md"), String)
    @test read(joinpath(srcdir, "src.jl"), String) == read(joinpath(@__DIR__, "fixed.jl"), String)
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
