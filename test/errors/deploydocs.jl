@test_throws ErrorException deploydocs(
    repo = "github.com/JuliaDocs/Documenter.jl.git",
    julia = 0.5,        # must be a string
    target = "build",
    deps = nothing,
    make = nothing,
)

trsl = get(ENV, "TRAVIS_REPO_SLUG", "")
try
    ENV["TRAVIS_REPO_SLUG"] = "foo"
    @test_throws ErrorException deploydocs(repo = "bar",
                                           deps = nothing,
                                           make = nothing,
                                           )
finally
    ENV["TRAVIS_REPO_SLUG"] = trsl
end
