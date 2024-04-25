# This script can be used to quickly instantiate the docs/Project.toml environment.
using Pkg
documenter_directory = joinpath(@__DIR__, "..")
project_directory = isempty(ARGS) ? @__DIR__() : joinpath(pwd(), ARGS[1])
cd(project_directory) do
    Pkg.activate(project_directory)
    # Install a DocumenterTools version that declares compatibility with Documenter 0.28,
    # but from an unreleased tag.
    # https://github.com/JuliaDocs/DocumenterTools.jl/releases/tag/documenter-v0.1.14%2B0.28.0-DEV
    #= This is currently not needed -- installing latest DocumenterTools is fine.
    if isdir("dev/DocumenterTools")
        @info "DocumenterTools already cloned to dev/DocumenterTools"
        run(`git -C dev/DocumenterTools fetch origin`)
    else
        run(`git clone -n https://github.com/JuliaDocs/DocumenterTools.jl.git dev/DocumenterTools`)
    end
    run(`git -C dev/DocumenterTools checkout documenter-v0.1.17+1.0.0`)
    =#
    Pkg.develop([
        PackageSpec(path = documenter_directory),
        #=PackageSpec(path = "dev/DocumenterTools"),=#
    ])
    Pkg.instantiate()
end
