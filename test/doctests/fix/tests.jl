# Tests for doctest = :fix
#
# DOCUMENTER_TEST_DEBUG= JULIA_DEBUG=all julia test/doctests/fix/tests.jl
#
module DocTestFixTest
using Documenter, Test

function test_doctest_fix(dir)
    srcdir = mktempdir(dir)
    builddir = mktempdir(dir)
    @debug "Testing doctest = :fix" srcdir builddir
    cp(joinpath(@__DIR__, "broken.md"), joinpath(srcdir, "index.md"))
    cp(joinpath(@__DIR__, "broken.jl"), joinpath(srcdir, "src.jl"))

    # fix up
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=:fix"
    makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, doctest = :fix)

    # test that strict = true works
    include(joinpath(srcdir, "src.jl")); @eval import .Foo
    @debug "Running doctest/fix doctests with doctest=true"
    makedocs(sitename="-", modules = [Foo], source = srcdir, build = builddir, strict = true)

    # also test that we obtain the expected output
    @test read(joinpath(srcdir, "index.md"), String) == read(joinpath(@__DIR__, "fixed.md"), String)
    @test read(joinpath(srcdir, "src.jl"), String) == read(joinpath(@__DIR__, "fixed.jl"), String)
end

println("="^50)
@info("Testing `doctest = :fix`")
if haskey(ENV, "DOCUMENTER_TEST_DEBUG")
    # in this mode the directories remain
    test_doctest_fix(mktempdir(@__DIR__))
else
    mktempdir(test_doctest_fix, @__DIR__)
end
@info("Done testing `doctest = :fix`")
println("="^50)

end # module
