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
    for (sym, n_expected) in zip([:none, :exports, :all], [0, 1, 2])
        kwargs = (
            root = dirname(@__FILE__),
            source = joinpath("src", string(sym)),
            build = joinpath("build", string(sym)),
            modules = MissingDocs,
            checkdocs = sym,
            sitename = "MissingDocs Checks",
            warnonly = true,
        )
        @quietly @test makedocs(; kwargs...) === nothing

        doc = Documenter.Document(; kwargs...)
        @quietly @test Documenter.DocChecks.missingdocs(doc) == n_expected
    end

    @quietly @test_throws ErrorException makedocs(
        root = dirname(@__FILE__),
        source = joinpath("src", "none"),
        build = joinpath("build", "error"),
        modules = MissingDocs,
        checkdocs = :all,
        sitename = "MissingDocs Checks",
    )
end

end
