# Tests for syntax versioning support in doctests
#
# These tests verify that modules with syntax version set via
# Base.Experimental.@set_syntax_version have their doctests parsed
# with the correct syntax version.

module SyntaxVersioningTests
using Test
using Documenter
import IOCapture

# Only run these tests on Julia 1.14+ where syntax versioning is available
@testset "Syntax Versioning" begin
    if !isdefined(Base, :VersionedParse)
        @info "Skipping syntax versioning tests: requires Julia 1.14+"
        @test_skip false
    else
        @testset "Module with @set_syntax_version" begin
            # Include the test module that has @set_syntax_version v"1.14"
            include("src/SyntaxVersioning.jl")

            builds_directory = mktempdir()
            srcdir = joinpath(builds_directory, "src")
            mkpath(srcdir)
            touch(joinpath(srcdir, "index.md"))

            c = IOCapture.capture(rethrow = InterruptException) do
                withenv("JULIA_DEBUG" => "") do
                    makedocs(
                        sitename = "SyntaxVersioningTest",
                        format = Documenter.HTML(edit_link = nothing),
                        root = builds_directory,
                        modules = [SyntaxVersioning],
                        remotes = nothing,
                        checkdocs = :none,
                        doctest = true,
                        warnonly = false,
                    )
                end
            end

            if c.error
                @error "Doctest failed" output=c.output
            end
            @test !c.error
        end

        @testset "Markdown with syntax= attribute" begin
            builds_directory = mktempdir()
            srcdir = joinpath(builds_directory, "src")
            mkpath(srcdir)

            cp(joinpath(@__DIR__, "src", "syntax_versioning.md"), joinpath(srcdir, "syntax_versioning.md"))
            touch(joinpath(srcdir, "index.md"))

            c = IOCapture.capture(rethrow = InterruptException) do
                withenv("JULIA_DEBUG" => "") do
                    makedocs(
                        sitename = "SyntaxVersioningMDTest",
                        format = Documenter.HTML(edit_link = nothing),
                        root = builds_directory,
                        pages = ["syntax_versioning.md"],
                        remotes = nothing,
                        checkdocs = :none,
                        doctest = true,
                        warnonly = false,
                    )
                end
            end

            if c.error
                @error "Doctest failed" output=c.output
            end
            @test !c.error
        end
    end
end

end # module
