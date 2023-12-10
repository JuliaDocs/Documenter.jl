module BaseAssumptionTests
using Test

@test "Julia Base assumptions" begin
    # To handle source URLs to standard library files, we need to fix up the paths to
    # standard library objects (which generally point to /cache/..., for the pre-built
    # binaries).
    @test isdefined(Base, :fixup_stdlib_path)
    @test hasmethod(Base.fixup_stdlib_path, (String,))
end

end
