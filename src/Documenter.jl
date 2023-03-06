"""
Main module for `Documenter.jl` -- a documentation generation package for Julia.

Two functions are exported from this module for public use:

- [`makedocs`](@ref). Generates documentation from docstrings and templated markdown files.
- [`deploydocs`](@ref). Deploys generated documentation from *Travis-CI* to *GitHub Pages*.

# Exports

$(EXPORTS)

"""
module Documenter

import AbstractTrees
import Markdown
import MarkdownAST
import Unicode
# Additional imported names
using Test: @testset, @test
using DocStringExtensions
using Base64: base64decode

# Version number of Documenter itself
const DOCUMENTER_VERSION = let
    project = joinpath(dirname(dirname(pathof(Documenter))), "Project.toml")
    Base.include_dependency(project) # Retrigger precompilation when Project.toml changes
    toml = read(project, String)
    m = match(r"(*ANYCRLF)^version\s*=\s\"(.*)\"$"m, toml)
    VersionNumber(m[1])
end

# Potentially sensitive variables to be removed from environment when not needed
const NO_KEY_ENV = Dict(
    "DOCUMENTER_KEY" => nothing,
    "DOCUMENTER_KEY_PREVIEWS" => nothing,
)

# Names of possible internal errors
const ERROR_NAMES = [:autodocs_block, :cross_references, :docs_block, :doctest,
                     :eval_block, :example_block, :footnote, :linkcheck, :meta_block,
                     :missing_docs, :parse_error, :setup_block]

"""
    abstract type Plugin end

Any plugin that needs to either solicit user input or store information in a
[`Document`](@ref) should create a subtype of `Plugin`. The
subtype, `T <: Documenter.Plugin`, must have an empty constructor `T()` that
initialized `T` with the appropriate default values.

To retrieve the values stored in `T`, the plugin can call [`Documenter.getplugin`](@ref).
If `T` was passed to [`makedocs`](@ref), the passed type will be returned. Otherwise,
a new `T` object will be created.
"""
abstract type Plugin end

abstract type Writer end

include("utilities/DOM.jl")
include("utilities/JSDependencies.jl")
include("utilities/MDFlatten.jl")
include("utilities/Remotes.jl")
include("utilities/Selectors.jl")
include("utilities/TextDiff.jl")
include("utilities/utilities.jl")
include("DocMeta.jl")
include("DocSystem.jl")
include("Anchors.jl")
include("documents.jl")
include("Expanders.jl")
include("DocTests.jl")
include("Builder.jl")
include("CrossReferences.jl")
include("DocChecks.jl")
include("writers.jl")
include("html/HTMLWriter.jl")
include("latex/LaTeXWriter.jl")

# This is to keep DocumenterTools working:
module Writers
import ..HTMLWriter
end

import .HTMLWriter: HTML, asset
import .HTMLWriter.RD: KaTeX, MathJax, MathJax2, MathJax3
import .LaTeXWriter: LaTeX

# User Interface.
# ---------------
export makedocs, deploydocs, hide, doctest, DocMeta, asset, Remotes,
    KaTeX, MathJax, MathJax2, MathJax3

include("makedocs.jl")
include("deployconfig.jl")
include("deploydocs.jl")
include("doctest.jl")

using SnoopPrecompile
@precompile_all_calls begin
    include("docs_precompile/make.jl")
end

end # module
