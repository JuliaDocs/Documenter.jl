using Pkg

# Set up temp env in silence
let tmp = joinpath(mktempdir(), "Project.toml")
    touch(tmp)
    pushfirst!(LOAD_PATH, tmp)
    Pkg.activate(tmp; io=devnull)
end
Pkg.add("Changelog"; io=devnull)

using Changelog

Changelog.generate(
    Changelog.CommonMark(),
    joinpath(@__DIR__, "../CHANGELOG.md");
    repo = "JuliaDocs/Documenter.jl",
)
