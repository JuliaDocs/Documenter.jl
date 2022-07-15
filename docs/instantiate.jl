# This script can be used to quickly instantiate the docs/Project.toml enviroment.
using Pkg
documenter_directory = joinpath(@__DIR__, "..")
project_directory = isempty(ARGS) ? @__DIR__() : joinpath(pwd(), ARGS[1])
cd(project_directory) do
    Pkg.activate(project_directory)
    # Install a DocumenterTools version that declares compatibility with Documenter 0.28,
    # but from an unreleased tag.
    # https://github.com/JuliaDocs/DocumenterTools.jl/releases/tag/documenter-v0.1.14%2B0.28.0-DEV
    Pkg.add(rev = "documenter-v0.1.14+0.28.0-DEV", url = "https://github.com/JuliaDocs/DocumenterTools.jl.git")
    Pkg.develop(path = documenter_directory)
    Pkg.instantiate()
end
