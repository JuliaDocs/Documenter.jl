module DocTestsTest
using Documenter, Compat.Test
using Compat: @info

println("="^50)
@info("Testing `doctest = :fix`")
mktempdir(@__DIR__) do dir
    srcdir = mktempdir(dir)
    builddir = mktempdir(dir)
    cp(joinpath(@__DIR__, "broken.md"), joinpath(srcdir, "index.md"))
    cp(joinpath(@__DIR__, "broken.jl"), joinpath(srcdir, "src.jl"))
    include(joinpath(srcdir, "src.jl"))
    @eval using .Foo
    # fix up
    makedocs(modules = [Foo], source = srcdir, build = builddir, doctest = :fix)
    # test that strict = true works
    makedocs(modules = [Foo], source = srcdir, build = builddir, strict = true)
    # also test that we obtain the expected output
    @test open(f -> read(f, String), joinpath(srcdir, "index.md")) ==
          open(f -> read(f, String), joinpath(@__DIR__, "fixed.md"))
    @test open(f -> read(f, String), joinpath(srcdir, "src.jl")) ==
          open(f -> read(f, String), joinpath(@__DIR__, "fixed.jl"))
end
@info("Done testing `doctest = :fix`")
println("="^50)

end # module
