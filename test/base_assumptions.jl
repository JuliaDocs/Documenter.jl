"""
These tests test assumptions about the Julia Base module. In particular, this will
test the presence of the various internal, non-public functions that are used by
Documenter.jl.
"""
module BaseAssumptionTests
using Test

@testset "Julia Base assumptions" begin
    # To handle source URLs to standard library files, we need to fix up the paths to
    # standard library objects (which generally point to /cache/..., for the pre-built
    # binaries).
    @test isdefined(Base, :fixup_stdlib_path)
    @test hasmethod(Base.fixup_stdlib_path, (String,))
end

end
