# Build the real docs first.
include("../docs/make.jl")

# Build the example docs
include("examples/make.jl")

# Test missing docs
include("missingdocs/make.jl")

# Error reporting.
println("="^50)
info("The following errors are expected output.")
include(joinpath("errors", "make.jl"))
info("END of expected error output.")
println("="^50)

# Primary @testset

if VERSION >= v"0.5.0-dev+7720"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

@testset "Documenter" begin
    # Unit tests for module internals.
    include("utilities.jl")

    # NavNode tests.
    include("navnode.jl")

    # DocSystem unit tests.
    include("docsystem.jl")

    # DOM Tests.
    include("dom.jl")

    # MDFlatten tests.
    include("mdflatten.jl")

    # Mock package docs.
    include("examples/tests.jl")

    # Documenter package docs with other formats.
    include("formats/markdown.jl")
    include("formats/latex.jl")

    # Deployment
    include("errors/deploydocs.jl")
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
