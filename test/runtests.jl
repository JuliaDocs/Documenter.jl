using Test

# Build the example docs
include("examples/make.jl")

# Test missing docs
include("missingdocs/make.jl")

# Primary @testset

# Error reporting.
println("="^50)
@info("The following errors are expected output.")
include(joinpath("errors", "make.jl"))
@info("END of expected error output.")
println("="^50)

@testset "Documenter" begin
    # Unit tests for module internals.
    include("utilities.jl")
    include("markdown2.jl")

    # DocChecks tests
    include("docchecks.jl")

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

    # HTMLWriter
    include("htmlwriter.jl")

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
end

# Additional tests

## `Markdown.MD` to `DOM.Node` conversion tests.
module MarkdownToNode
    import Documenter.DocSystem
    import Documenter.Writers.HTMLWriter: mdconvert

    # Exhaustive Conversion from Markdown to Nodes.
    for mod in Base.Docs.modules
        for (binding, multidoc) in DocSystem.getmeta(mod)
            for (typesig, docstr) in multidoc.docs
                md = DocSystem.parsedoc(docstr)
                string(mdconvert(md))
            end
        end
    end
end

# Docstring signature syntax highlighting tests.
module HighlightSig
    using Test
    import Markdown
    import Documenter.Expanders: highlightsig!

    @testset "highlightsig!" begin
        s = """
                foo(bar::Baz)
            ---
                foo(bar::Baz)
            """
        original = Markdown.parse(s)
        md = Markdown.parse(s)
        highlightsig!(md)
        @test isempty(original.content[1].language)
        @test md.content[1].language == "julia"
        @test original.content[end].language == md.content[end].language

        s = """
            ```lang
             foo(bar::Baz)
            ```
            """
        original = Markdown.parse(s)
        md = Markdown.parse(s)
        highlightsig!(md)
        @test original == md
    end
end

include("manual.jl")
