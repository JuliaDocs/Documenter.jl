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

    # DocChecks tests
    include("docchecks.jl")

    # NavNode tests.
    include("navnode.jl")

    # DocSystem unit tests.
    include("docsystem.jl")

    # DocTest unit tests.
    include("doctests/doctests.jl")

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
