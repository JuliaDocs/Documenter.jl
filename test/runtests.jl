using Test
import Documenter
include("TestUtilities.jl"); using .TestUtilities

@testset "Documenter" begin
    # Test TestUtilities
    TestUtilities.test()

    # Build the example docs
    @info "Building example/make.jl"
    include("examples/make.jl")

    # Test missing docs
    @info "Building missingdocs/make.jl"
    @quietly include("missingdocs/make.jl")

    # Error reporting.
    println("="^50)
    @info("The following errors are expected output.")
    include("errors/make.jl")
    @info("END of expected error output.")
    println("="^50)

    # Unit tests for module internals.
    include("utilities.jl")
    include("markdown2.jl")
    include("remotes.jl")

    # DocChecks tests
    if haskey(ENV, "DOCUMENTER_TEST_LINKCHECK")
        include("docchecks.jl")
    else
        @info "DOCUMENTER_TEST_LINKCHECK not set, skipping online linkcheck tests."
    end

    # NavNode tests.
    include("navnode.jl")

    # DocSystem unit tests.
    include("docsystem.jl")

    # DocTest unit tests.
    include("doctests/docmeta.jl")
    include("doctests/doctestapi.jl")
    include("doctests/doctests.jl")
    include("doctests/fix/tests.jl")

    # DOM Tests.
    include("dom.jl")

    # MDFlatten tests.
    include("mdflatten.jl")

    # Main build pipeline (Builder and Expanders modules)
    include("pipeline.jl")

    # HTMLWriter
    include("htmlwriter.jl")

    # Deployment configurations
    include("deployconfig.jl")

    # Mock package docs.
    include("examples/tests.jl")

    # Documenter package docs with other formats.
    include("formats/markdown.jl")

    # A simple build outside of a Git repository
    include("nongit/tests.jl")

    # A simple build evaluating code outside build directory
    include("workdir/tests.jl")

    # Passing a writer positionally (https://github.com/JuliaDocs/Documenter.jl/issues/1046)
    @test_throws ArgumentError makedocs(sitename="", HTML())

    # Running doctest() on our own manual
    include("manual.jl")
end
