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

module UnitTests
    module SubModule end

    # Does `submodules` collect *all* the submodules?
    module A
        module B
            module C
                module D end
            end
        end
    end

    type T end

    "Documenter unit tests."
    Base.length(::T) = 1
end

let doc = @doc(length)
    a = Documenter.Utilities.filterdocs(doc, Set{Module}())
    b = Documenter.Utilities.filterdocs(doc, Set{Module}([UnitTests]))
    c = Documenter.Utilities.filterdocs(doc, Set{Module}([Base]))
    d = Documenter.Utilities.filterdocs(doc, Set{Module}([Tests]))

    @test !isnull(a)
    @test get(a) === doc
    @test !isnull(b)
    @test contains(stringmime("text/plain", get(b)), "Documenter unit tests.")
    @test !isnull(c)
    @test !contains(stringmime("text/plain", get(c)), "Documenter unit tests.")
    @test isnull(d)
end

# Documenter.Utilities.issubmodule
@test Documenter.Utilities.issubmodule(Main, Main) === true
@test Documenter.Utilities.issubmodule(UnitTests, UnitTests) === true
@test Documenter.Utilities.issubmodule(UnitTests.SubModule, Main) === true
@test Documenter.Utilities.issubmodule(UnitTests.SubModule, UnitTests) === true
@test Documenter.Utilities.issubmodule(UnitTests.SubModule, Base) === false
@test Documenter.Utilities.issubmodule(UnitTests, UnitTests.SubModule) === false

@test UnitTests.A in Documenter.Utilities.submodules(UnitTests.A)
@test UnitTests.A.B in Documenter.Utilities.submodules(UnitTests.A)
@test UnitTests.A.B.C in Documenter.Utilities.submodules(UnitTests.A)
@test UnitTests.A.B.C.D in Documenter.Utilities.submodules(UnitTests.A)

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

# Documenter package docs:

const Documenter_root = normpath(joinpath(dirname(@__FILE__), "..", "docs"))

info("Building Documenter package docs.")
doc = makedocs(
    debug   = true,
    root    = Documenter_root,
    modules = Documenter,
    clean   = false,
)

@test isa(doc, Documenter.Documents.Document)

let build_dir  = joinpath(Documenter_root, "build"),
    source_dir = joinpath(Documenter_root, "src")

    @test isdir(build_dir)
    @test isdir(joinpath(build_dir, "assets"))
    @test isdir(joinpath(build_dir, "lib"))
    @test isdir(joinpath(build_dir, "man"))

    @test isfile(joinpath(build_dir, "index.md"))
    @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
    @test isfile(joinpath(build_dir, "assets", "Documenter.css"))
end

@test doc.user.root   == Documenter_root
@test doc.user.source == "src"
@test doc.user.build  == "build"
@test doc.user.clean  == false

rm(joinpath(Documenter_root, "build"); recursive = true)

mktempdir() do root
    let path = joinpath(root, "docs")
        Documenter.generate("DocumenterTestPackage", dir = path)
        @test isdir(path)
        @test isfile(joinpath(path, "mkdocs.yml"))
        @test isfile(joinpath(path, ".gitignore"))
        @test isfile(joinpath(path, "make.jl"))
        @test isdir(joinpath(path, "src"))
        @test isfile(joinpath(path, "src", "index.md"))
    end
end

@test_throws ErrorException Documenter.generate("Documenter")
@test_throws ErrorException Documenter.generate(randstring())

# Test PDF generation.

makedocs(
    root = Documenter_root,
    modules = [Documenter],
    clean = false,
    format = Documenter.Formats.LaTeX,
    sitename = "Documenter.jl",
    authors = "Michael Hatherly, Morten Piibeleht, and contributors.",
    pages = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "Manual" => Any[
            "Guide" => "man/guide.md",
            "man/examples.md",
            "man/syntax.md",
            "man/doctests.md",
            "man/hosting.md",
            "man/latex.md",
            "man/internals.md",
            "man/contributing.md",
        ],
        "Library" => Any[
            "Public" => "lib/public.md",
            "Internals" => Any[
                "Internals" => "lib/internals.md",
                "lib/internals/anchors.md",
                "lib/internals/builder.md",
                "lib/internals/cross-references.md",
                "lib/internals/docchecks.md",
                "lib/internals/docsystem.md",
                "lib/internals/documents.md",
                "lib/internals/dom.md",
                "lib/internals/expanders.md",
                "lib/internals/formats.md",
                "lib/internals/generator.md",
                "lib/internals/mdflatten.md",
                "lib/internals/selectors.md",
                "lib/internals/utilities.md",
                "lib/internals/walkers.md",
                "lib/internals/writers.md",
            ]
        ]
    ]
)

end

# more tests from files
include("mdflatten.jl")
