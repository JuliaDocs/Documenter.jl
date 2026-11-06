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

# `h` is public here, but the extra methods are documented in a submodule that does not
# make it public, so only the first two docstrings are checked.
module MissingDocsMethods
    export h

    "h(::Int)"
    h(x::Int) = x

    "h(::String)"
    h(x::String) = x

    module Extra
        import ..h

        "h(::Float64)"
        h(x::Float64) = x

        "h(::Char)"
        h(x::Char) = x

        "h(::Bool)"
        h(x::Bool) = x
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

    # An ignored module is skipped even when it is also passed to `modules`.
    kwargs = (
        root = dirname(@__FILE__),
        source = joinpath("src", "none"),
        build = joinpath("build", "ignored-root"),
        modules = [MissingDocsSubmodule.UndocumentedSubmodule],
        checkdocs = :all,
        sitename = "MissingDocsSubmodule Checks",
        warnonly = true,
        checkdocs_ignored_modules = [MissingDocsSubmodule.UndocumentedSubmodule],
    )
    @quietly @test makedocs(; kwargs...) === nothing
    @quietly @test Documenter.missingdocs(Documenter.Document(; kwargs...)) == 0

    # The docstrings of other methods spliced into the manual must not count towards the
    # checked ones, whatever order the included objects are visited in.
    doc = @quietly makedocs(
        root = dirname(@__FILE__),
        source = joinpath("src", "methods"),
        build = joinpath("build", "methods"),
        modules = MissingDocsMethods,
        checkdocs = :exports,
        sitename = "MissingDocsMethods Checks",
        warnonly = true,
        debug = true,
    )
    @test length(doc.internal.objects) == 4
    @test @quietly(Documenter.missingdocs(doc)) == 1
end

end
