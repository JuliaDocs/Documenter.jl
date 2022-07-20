# Tests for doctest = :fix
#
# DOCUMENTER_TEST_DEBUG= JULIA_DEBUG=all julia test/doctests/fix/tests.jl
#
module DocTestFixTest
using Documenter, Test
include("../../TestUtilities.jl"); using Main.TestUtilities: @quietly

# Type to reliably show() objects across Julia versions:
@eval Main begin
    struct ShowWrap
        s :: String
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
    @quietly makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, doctest = :fix)

    # test that strict = true works
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=true"
    @quietly makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, strict = true)

    # also test that we obtain the expected output
    @test normalize_line_endings(index_md) == normalize_line_endings(joinpath(@__DIR__, "fixed.md"))
    @test normalize_line_endings(src_jl) == normalize_line_endings(joinpath(@__DIR__, "fixed.jl"))
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
