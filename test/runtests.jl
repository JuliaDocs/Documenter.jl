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
    a = Lapidary.filterdocs(doc, Module[])
    b = Lapidary.filterdocs(doc, Module[UnitTests])
    c = Lapidary.filterdocs(doc, Module[Base])
    d = Lapidary.filterdocs(doc, Module[Tests])

    @test a === doc
    @test contains(stringmime("text/plain", b), "Lapidary unit tests.")
    @test !contains(stringmime("text/plain", c), "Lapidary unit tests.")
    @test d === nothing
end


# Integration tests for module api.

# setup
# =====

const example_root = joinpath(dirname(@__FILE__), "examples")

const env =
    makedocs(
        debug = true,
        root  = example_root,
    )

# tests
# =====

@test isa(env, Lapidary.Env)

let build_dir  = joinpath(example_root, "build"),
    source_dir = joinpath(example_root, "src")

    @test isdir(build_dir)
    @test isdir(joinpath(build_dir, "assets"))
    @test isdir(joinpath(build_dir, "lib"))
    @test isdir(joinpath(build_dir, "man"))

    @test isfile(joinpath(build_dir, "index.md"))
    @test isfile(joinpath(build_dir, "assets", "mathjaxhelper.js"))
    @test isfile(joinpath(build_dir, "assets", "Lapidary.css"))
    @test isfile(joinpath(build_dir, "lib", "functions.md"))
    @test isfile(joinpath(build_dir, "man", "tutorial.md"))
    @test isfile(joinpath(build_dir, "man", "data.csv"))

    @test (==)(
        readstring(joinpath(source_dir, "man", "data.csv")),
        readstring(joinpath(build_dir,  "man", "data.csv")),
    )
end

@test env.root   == example_root
@test env.source == "src"
@test env.build  == "build"
@test env.assets == normpath(joinpath(dirname(@__FILE__), "..", "assets"))
@test env.clean  == true
@test env.mime   == MIME"text/plain"()

@test length(env.template_paths)     == 3
@test length(env.parsed_templates)   == 3
@test length(env.expanded_templates) == 3

@test length(env.headers)   == 8
@test length(env.headermap) == 8

@test length(env.docsmap) == 7

end
