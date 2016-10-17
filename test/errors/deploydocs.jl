@test_throws ErrorException deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    julia = 0.5,        # must be a string
    target = "build",
    deps = nothing,
    make = nothing,
)
