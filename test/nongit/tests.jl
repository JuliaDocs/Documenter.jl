mktempdir() do tmpdir
    @info("Building 'nongit' in $tmpdir")
    cp(joinpath(@__DIR__, "docs"), joinpath(tmpdir, "docs"))
    include(joinpath(tmpdir, "docs/make.jl"))
    # Copy the build/ directory back so that it would be possible to inspect the output.
    cp(joinpath(tmpdir, "docs/build"), joinpath(@__DIR__, "build"); force = true)
end
