module MissingDocsTests
using Test
using Documenter
include("../TestUtilities.jl"); using Main.TestUtilities

module MissingDocs
    export f

    "exported"
    f(x) = x

    "unexported"
    g(x) = x
end

@testset "missing docs" begin
    for sym in [:none, :exports, :all]
        @quietly @test makedocs(
            root = dirname(@__FILE__),
            source = joinpath("src", string(sym)),
            build = joinpath("build", string(sym)),
            modules = MissingDocs,
            checkdocs = sym,
            sitename = "MissingDocs Checks",
        ) === nothing
    end

    @quietly @test_throws ErrorException makedocs(
        root = dirname(@__FILE__),
        source = joinpath("src", "none"),
        build = joinpath("build", "error"),
        modules = MissingDocs,
        checkdocs = :all,
        strict = true,
        sitename = "MissingDocs Checks",
    )
end

end
