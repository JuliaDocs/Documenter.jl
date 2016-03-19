# docs module
# ===========

module Mod

"""
    func(x)

[`T`]({ref})
"""
func(x) = x

"""
    T

[`func(x)`]({ref})
"""
type T end

end

# tests module
# ============

module Tests

using Lapidary
using Base.Test
using Compat


# Unit tests for module internals.

module UnitTests

type T end

"Lapidary unit tests."
Base.length(::T) = 1

end

let doc = @doc(length)
    a = Lapidary.Utilities.filterdocs(doc, Set{Module}())
    b = Lapidary.Utilities.filterdocs(doc, Set{Module}([UnitTests]))
    c = Lapidary.Utilities.filterdocs(doc, Set{Module}([Base]))
    d = Lapidary.Utilities.filterdocs(doc, Set{Module}([Tests]))

    @test !isnull(a)
    @test get(a) === doc
    @test !isnull(b)
    @test contains(stringmime("text/plain", get(b)), "Lapidary unit tests.")
    @test !isnull(c)
    @test !contains(stringmime("text/plain", get(c)), "Lapidary unit tests.")
    @test isnull(d)
end


# Integration tests for module api.

# Mock package docs:

# setup
# =====

const example_root = joinpath(dirname(@__FILE__), "examples")

doc = makedocs(
    debug = true,
    root  = example_root,
)

# tests
# =====

@test isa(doc, Lapidary.Documents.Document)

let build_dir  = joinpath(example_root, "build"),
    source_dir = joinpath(example_root, "src")

    @test isdir(build_dir)
    @test isdir(joinpath(build_dir, "assets"))
    @test isdir(joinpath(build_dir, "lib"))
    @test isdir(joinpath(build_dir, "man"))

    @test isfile(joinpath(build_dir, "index.md"))
    @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
    @test isfile(joinpath(build_dir, "assets", "Lapidary.css"))
    @test isfile(joinpath(build_dir, "assets", "custom.css"))
    @test isfile(joinpath(build_dir, "lib", "functions.md"))
    @test isfile(joinpath(build_dir, "man", "tutorial.md"))
    @test isfile(joinpath(build_dir, "man", "data.csv"))

    @test (==)(
        readstring(joinpath(source_dir, "man", "data.csv")),
        readstring(joinpath(build_dir,  "man", "data.csv")),
    )
end

@test doc.user.root   == example_root
@test doc.user.source == "src"
@test doc.user.build  == "build"
@test doc.user.clean  == true
@test doc.user.format == Lapidary.Formats.Markdown

@test doc.internal.assets == normpath(joinpath(dirname(@__FILE__), "..", "assets"))

@test length(doc.internal.pages) == 3

let headers = doc.internal.headers
    @test Lapidary.Anchors.exists(headers, "Documentation")
    @test Lapidary.Anchors.exists(headers, "Documentation")
    @test Lapidary.Anchors.exists(headers, "Index-Page")
    @test Lapidary.Anchors.exists(headers, "Functions-Contents")
    @test Lapidary.Anchors.exists(headers, "Tutorial-Contents")
    @test Lapidary.Anchors.exists(headers, "Index")
    @test Lapidary.Anchors.exists(headers, "Tutorial")
    @test Lapidary.Anchors.exists(headers, "Function-Index")
    @test Lapidary.Anchors.exists(headers, "Functions")
    @test Lapidary.Anchors.isunique(headers, "Functions")
    @test Lapidary.Anchors.isunique(headers, "Functions", joinpath("build", "lib", "functions.md"))
    let name = "Foo", path = joinpath("build", "lib", "functions.md")
        @test Lapidary.Anchors.exists(headers, name, path)
        @test !Lapidary.Anchors.isunique(headers, name)
        @test !Lapidary.Anchors.isunique(headers, name, path)
        @test length(headers.map[name][path]) == 4
    end
end

@test length(doc.internal.objects) == 7

# Lapidary package docs:

const lapidary_root = Pkg.dir("Lapidary", "docs")

doc = makedocs(
    debug   = true,
    root    = lapidary_root,
    modules = Lapidary,
    clean   = false,
)

@test isa(doc, Lapidary.Documents.Document)

let build_dir  = joinpath(lapidary_root, "build"),
    source_dir = joinpath(lapidary_root, "src")

    @test isdir(build_dir)
    @test isdir(joinpath(build_dir, "assets"))
    @test isdir(joinpath(build_dir, "lib"))
    @test isdir(joinpath(build_dir, "man"))

    @test isfile(joinpath(build_dir, "index.md"))
    @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
    @test isfile(joinpath(build_dir, "assets", "Lapidary.css"))
end

@test doc.user.root   == lapidary_root
@test doc.user.source == "src"
@test doc.user.build  == "build"
@test doc.user.clean  == false

rm(joinpath(lapidary_root, "build"); recursive = true)

end

include(Pkg.dir("Lapidary", "docs", "make.jl"))
