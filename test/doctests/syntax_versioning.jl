# Tests for syntax versioning support in doctests
#
# These tests verify that modules with syntax version set via
# Base.Experimental.@set_syntax_version have their doctests parsed
# with the correct syntax version.

module SyntaxVersioningTests
using Test
using Documenter
import IOCapture

function run_doctest(; modules = Module[], mdfiles = String[])
    builds_directory = mktempdir()
    srcdir = joinpath(builds_directory, "src")
    mkpath(srcdir)
    touch(joinpath(srcdir, "index.md"))
    for mdfile in mdfiles
        cp(joinpath(@__DIR__, "src", mdfile), joinpath(srcdir, mdfile))
    end
    c = IOCapture.capture(rethrow = InterruptException) do
        withenv("JULIA_DEBUG" => "") do
            makedocs(
                sitename = " ",
                format = Documenter.HTML(edit_link = nothing),
                root = builds_directory,
                modules = modules,
                pages = isempty(mdfiles) ? Documenter.Page[] : mdfiles,
                remotes = nothing,
                checkdocs = :none,
                doctest = true,
                warnonly = false,
            )
        end
    end
    if c.error
        @error "Doctest failed" output = c.output
    end
    return @test !c.error
end

# Only run these tests on Julia 1.14+ where syntax versioning is available
@testset "Syntax Versioning" begin
    if !isdefined(Base, :VersionedParse)
        @info "Skipping syntax versioning tests: requires Julia 1.14+"
        @test_skip false
    else
        include("src/SyntaxVersioning.jl")
        include("src/SyntaxVersioning13.jl")

        @testset "Module with @set_syntax_version v\"1.14\"" begin
            run_doctest(modules = [SyntaxVersioning])
        end

        @testset "Module with @set_syntax_version v\"1.13\" (negative)" begin
            run_doctest(modules = [SyntaxVersioning13])
        end

        @testset "Markdown with syntax= attribute" begin
            run_doctest(mdfiles = ["syntax_versioning.md"])
        end
    end
end

end # module
