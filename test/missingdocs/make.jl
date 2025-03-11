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

module MissingDocsSubmodule
    module UndocumentedSubmodule
        export f

        "exported"
        f(x) = x
    end
end

@testset "missing docs" begin
    for (sym, n_expected) in zip([:none, :exports, :public, :all], [0, 1, 1, 2])
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
        @quietly @test Documenter.missingdocs(doc) == n_expected
    end

    @quietly @test_throws ErrorException makedocs(
        root = dirname(@__FILE__),
        source = joinpath("src", "none"),
        build = joinpath("build", "error"),
        modules = MissingDocs,
        checkdocs = :all,
        sitename = "MissingDocs Checks",
    )

    for (ignore, n_expected) in zip([false, true], [1, 0])
        kwargs = (
            root = dirname(@__FILE__),
            source = joinpath("src", "none"),
            build = joinpath("build", "submodule"),
            modules = MissingDocsSubmodule,
            checkdocs = :all,
            sitename = "MissingDocsSubmodule Checks",
            warnonly = true,
            checkdocs_ignored_modules = ignore ? Module[MissingDocsSubmodule.UndocumentedSubmodule] : Module[],
        )
        @quietly @test makedocs(; kwargs...) === nothing

        doc = Documenter.Document(; kwargs...)
        @quietly @test Documenter.missingdocs(doc) == n_expected
    end
end

end
