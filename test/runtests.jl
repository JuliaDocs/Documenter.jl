# Build the real docs first.
include(joinpath(dirname(@__FILE__), "..", "docs", "make.jl"))

# Build the example docs
include(joinpath(dirname(@__FILE__), "examples", "make.jl"))

# Test missing docs
include(joinpath(dirname(@__FILE__), "missingdocs", "make.jl"))

# tests module
# ============

module Tests

using Documenter
using Base.Test
using Compat


# Unit tests for module internals.

include("utilities.jl")

## NavNode tests

include("navnode.jl")

# DocSystem unit tests.

include("docsystem.jl")

## DOM Tests.

include("dom.jl")

# `Markdown.MD` to `DOM.Node` conversion tests.
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

# Integration tests for module api.

# Error reporting.

println("="^50)
info("The following errors are expected output.")
include(joinpath("errors", "make.jl"))
info("END of expected error output.")
println("="^50)

# Mock package docs:

include(joinpath(dirname(@__FILE__), "examples", "tests.jl"))

# Documenter package docs with other formats

include("formats/markdown.jl")
include("formats/latex.jl")

end

# more tests from files
include("mdflatten.jl")
