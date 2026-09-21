using Documenter
using Test

module DefaultMetaTestModule
    "A function that is not exported, and hence only findable via `CurrentModule`."
    function unexported_function end
end

const pages = [
    "Home" => "index.md",
    "No meta" => "nometa.md",
]

makedocs(
    sitename = "Test", pages = pages, doctest = true,
    modules = [DefaultMetaTestModule],
    meta = Dict(
        :DocTestSetup => :(x = 42),
        :CurrentModule => DefaultMetaTestModule,
        :CollapsedDocStrings => true,
    )
)

# `doctest` builds its own document, so it needs to forward `meta` itself.
doctest(
    joinpath(@__DIR__, "src"), Module[];
    testset = "Doctests: default meta",
    meta = Dict(:DocTestSetup => :(x = 42)),
)

# index.md passing its doctest covers `DocTestSetup`, and nometa.md resolving
# its `@ref` covers `CurrentModule`; both would have errored above. What is left
# to check is that `CollapsedDocStrings` reaches the HTML writer.
@testset "default meta reaches the writer" begin
    build = joinpath(@__DIR__, "build")
    file = joinpath(build, "nometa", "index.html")
    isfile(file) || (file = joinpath(build, "nometa.html"))
    @test occursin("data-docstringscollapsed", read(file, String))
end
