# docs module
# ===========

module Mod

"""
    func(x)

[`T`](@ref)
"""
func(x) = x

"""
    T

[`func(x)`](@ref)
"""
type T end

end

# autodocs module
# ===============

"`AutoDocs` module."
module AutoDocs

"Function `f`."
f(x) = x

"Constant `K`."
const K = 1

"Type `T`."
type T end

"Macro `@m`."
macro m() end

"Module `A`."
module A

"Function `A.f`."
f(x) = x

"Constant `A.K`."
const K = 1

"Type `B.T`."
type T end

"Macro `B.@m`."
macro m() end

end

"Module `B`."
module B

"Function `B.f`."
f(x) = x

"Constant `B.K`."
const K = 1

"Type `B.T`."
type T end

"Macro `B.@m`."
macro m() end

end

end

# tests module
# ============

module Tests

using Documenter
using Base.Test
using Compat


# Unit tests for module internals.

module UnitTests

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

@test isa(doc, Documenter.Documents.Document)

let build_dir  = joinpath(example_root, "build"),
    source_dir = joinpath(example_root, "src")

    @test isdir(build_dir)
    @test isdir(joinpath(build_dir, "assets"))
    @test isdir(joinpath(build_dir, "lib"))
    @test isdir(joinpath(build_dir, "man"))

    @test isfile(joinpath(build_dir, "index.md"))
    @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
    @test isfile(joinpath(build_dir, "assets", "Documenter.css"))
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
@test doc.user.format == Documenter.Formats.Markdown

@test doc.internal.assets == normpath(joinpath(dirname(@__FILE__), "..", "assets"))

@test length(doc.internal.pages) == 3

let headers = doc.internal.headers
    @test Documenter.Anchors.exists(headers, "Documentation")
    @test Documenter.Anchors.exists(headers, "Documentation")
    @test Documenter.Anchors.exists(headers, "Index-Page")
    @test Documenter.Anchors.exists(headers, "Functions-Contents")
    @test Documenter.Anchors.exists(headers, "Tutorial-Contents")
    @test Documenter.Anchors.exists(headers, "Index")
    @test Documenter.Anchors.exists(headers, "Tutorial")
    @test Documenter.Anchors.exists(headers, "Function-Index")
    @test Documenter.Anchors.exists(headers, "Functions")
    @test Documenter.Anchors.isunique(headers, "Functions")
    @test Documenter.Anchors.isunique(headers, "Functions", joinpath("build", "lib", "functions.md"))
    let name = "Foo", path = joinpath("build", "lib", "functions.md")
        @test Documenter.Anchors.exists(headers, name, path)
        @test !Documenter.Anchors.isunique(headers, name)
        @test !Documenter.Anchors.isunique(headers, name, path)
        @test length(headers.map[name][path]) == 4
    end
end

@test length(doc.internal.objects) == 22

# Documenter package docs:

const Documenter_root = Pkg.dir("Documenter", "docs")

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

end

include(Pkg.dir("Documenter", "docs", "make.jl"))
