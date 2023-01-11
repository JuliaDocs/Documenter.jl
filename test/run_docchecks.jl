using Pkg
mktempdir() do envdir
    Pkg.activate(envdir)
    Pkg.add(PackageSpec(path = joinpath(@__DIR__, "..")))
    Pkg.status()
    include("docchecks.jl")
end
