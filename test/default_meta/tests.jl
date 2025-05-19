using Documenter
using Test

const pages = [
    "Home" => "index.md",
]

makedocs(
    sitename = "Test", pages = pages, doctest = true,
    meta = Dict(:DocTestSetup => :(x = 42))
)

# the test is passing the doctest
