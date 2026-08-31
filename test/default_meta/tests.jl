using Documenter
using Test

const pages = [
    "Home" => "index.md",
]

makedocs(
    sitename = "Test", pages = pages, doctest = true,
    meta = Dict(:DocTestSetup => :(x = 42))
)

# `doctest` builds its own document, so it needs to forward `meta` itself.
doctest(
    joinpath(@__DIR__, "src"), Module[];
    testset = "Doctests: default meta",
    meta = Dict(:DocTestSetup => :(x = 42)),
)

# the test is passing the doctest
