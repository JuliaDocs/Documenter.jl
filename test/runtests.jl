using Test
import Documenter
include("TestUtilities.jl"); using Main.TestUtilities

function testset_include(filename; quietly = false)
    return @testset "$filename" begin
        if quietly
            @quietly include(filename)
        else
            include(filename)
        end
    end
end

@testset "Documenter" begin
    # Build the example docs
    @info "Building example/make.jl"
    include("examples/make.jl")

    # Build the symlinked example docs
    @info "Building symlinks/make.jl"
    include("symlinks/tests.jl")

    # Test missing docs
    @info "Building missingdocs/make.jl"
    include("missingdocs/make.jl")

    # Test @ref fallback to Main for fully qualified names
    @info "Building docsxref/make.jl"
    include("docsxref/make.jl")

    # Error reporting.
    @info "Building errors/make.jl"
    @quietly include("errors/make.jl")

    # Plugin API
    @info "Building plugins/make.jl"
    @quietly include("plugins/make.jl")

    # Unit tests for module internals.
    include("except.jl")
    include("utilities.jl")

    # Remote repository link handling
    include("remotes.jl")
    testset_include("repolinks.jl")

    # DocChecks tests
    include("docchecks.jl")

    # NavNode tests.
    include("navnode.jl")

    # DocSystem unit tests.
    include("docsystem.jl")

    # CrossReferences
    include("crossreferences.jl")

    # DocTest unit tests.
    @info "Running tests in doctests/"
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

    # LaTeXWriter
    include("latexwriter.jl")

    # Deployment configurations
    include("deployconfig.jl")
    include("deploydocs.jl")

    # Mock package docs.
    include("examples/tests.jl")

    # A simple build outside of a Git repository
    @info "Building nongit/tests.jl"
    @quietly include("nongit/tests.jl")

    # A simple build evaluating code outside build directory
    @info "Building workdir/tests.jl"
    @quietly include("workdir/tests.jl")

    # A simple build verifying that sandbox modules are cleared at the end of each page
    @info "Building clear_module/tests.jl"
    @quietly include("clear_module/tests.jl")

    # Passing a writer positionally (https://github.com/JuliaDocs/Documenter.jl/issues/1046)
    @test_throws MethodError makedocs(sitename = "", HTML())

    # Running doctest() on our own manual
    @info "doctest() Documenter's manual"
    @quietly include("manual.jl")
end
