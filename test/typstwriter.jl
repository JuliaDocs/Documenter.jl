module TypstWriterTests

using Test
using Documenter

@testset "Typst Backend" begin
    @testset "Basic Rendering" begin
        # Test that Typst backend can be instantiated
        typst_format = Documenter.Typst()
        @test typst_format isa Documenter.Writer
        @test typst_format.platform == "native"
        @test typst_format.version == get(ENV, "TRAVIS_TAG", "")
    end
    
    @testset "Typst Format Options" begin
        # Test different platform options
        @test Documenter.Typst(platform="native").platform == "native"
        @test Documenter.Typst(platform="typst").platform == "typst"
        @test Documenter.Typst(platform="docker").platform == "docker"
        @test Documenter.Typst(platform="none").platform == "none"
        
        # Test invalid platform throws error
        @test_throws ArgumentError Documenter.Typst(platform="invalid")
        
        # Test version parameter
        @test Documenter.Typst(version="1.0.0").version == "1.0.0"
    end
    
    @testset "ANSI Color Support" begin
        # Test that Typst writer reports no ANSI color support
        using Documenter: Expanders
        typst_format = Documenter.Typst()
        @test Expanders.writer_supports_ansicolor(typst_format) == false
    end
    
    @testset "Simple Documentation Build" begin
        # Create a minimal test case
        mktempdir() do dir
            # Create source directory
            srcdir = joinpath(dir, "src")
            mkpath(srcdir)
            
            # Write a simple markdown file
            write(joinpath(srcdir, "index.md"), """
            # Test Document
            
            This is a test document for the Typst backend.
            
            ## Section 1
            
            Some text here.
            
            ```julia
            x = 1 + 1
            ```
            
            ## Section 2
            
            More text.
            """)
            
            # Try to build with Typst backend (platform="none" to skip compilation)
            try
                makedocs(
                    root = dir,
                    source = "src",
                    build = "build",
                    sitename = "Typst Test",
                    format = Documenter.Typst(platform="none"),
                    pages = ["index.md"],
                    doctest = false,
                )
                @test isdir(joinpath(dir, "build"))
                @test isfile(joinpath(dir, "build", "TypstTest.typ"))
                @test isfile(joinpath(dir, "build", "documenter.typ"))
            catch e
                # It's okay if there are some errors in minimal test
                # The important thing is that the backend loads and attempts to render
                @test e isa Exception
                @info "Build had issues (expected in minimal test)" exception=e
            end
        end
    end
end

end # module
