# This script can be used to quickly instantiate the docs/Project.toml enviroment.
using Pkg
cd(@__DIR__) do
    Pkg.activate(@__DIR__)
    # Install the documenter branch of DocumenterTools
    if isdir("dev/DocumenterTools")
        @info "DocumenterTools already cloned to docs/dev/DocumenterTools"
    else
        run(`git clone -n https://github.com/JuliaDocs/DocumenterTools.jl.git dev/DocumenterTools`)
    end
    run(`git -C dev/DocumenterTools checkout --detach 336e27eeaf56852838b192b1fc7c0cce129d2d9f`)
    Pkg.develop([PackageSpec(path = "dev/DocumenterTools"), PackageSpec(path = "..")])
    Pkg.instantiate()
end
