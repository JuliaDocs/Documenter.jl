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

module SubModule end

# Does `submodules` collect *all* the submodules?
module A
module B
module C
module D
end
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

# DocSystem unit tests.

import Documenter: DocSystem

## Bindings.

@test_throws ArgumentError DocSystem.binding(9000)
let b = Docs.Binding(current_module(), :DocSystem)
    @test DocSystem.binding(b) == b
end
let b = DocSystem.binding(Documenter.Documents.Document)
    @test b.mod === Documenter.Documents
    @test b.var === :Document
end
let b = DocSystem.binding(Documenter)
    @test b.mod === Main
    @test b.var === :Documenter
end
let b = DocSystem.binding(:Main)
    # @test b.mod === Main
    @test b.var === :Main
end
let b = DocSystem.binding(DocSystem.binding)
    @test b.mod === DocSystem
    @test b.var === :binding
end
let b = DocSystem.binding(getfield(Core.Intrinsics, :ccall))
    @test b.mod === Core.Intrinsics
    @test b.var === :ccall
end
let b = DocSystem.binding(Documenter, :Documenter)
    @test b.mod === Main
    @test b.var === :Documenter
end

## `MultiDoc` object.

@test isdefined(DocSystem, :MultiDoc)
@test fieldnames(DocSystem.MultiDoc) == [:order, :docs]

## `DocStr` object.

@test isdefined(DocSystem, :DocStr)
@test fieldnames(DocSystem.DocStr) == [:text, :object, :data]

## `getdocs`.

const alias_of_getdocs = DocSystem.getdocs

let b   = DocSystem.binding(DocSystem, :getdocs),
    d_0 = DocSystem.getdocs(b, Tuple{}),
    d_1 = DocSystem.getdocs(b),
    d_2 = DocSystem.getdocs(b, Union{Tuple{ANY}, Tuple{ANY, Type}}; compare = (==)),
    d_3 = DocSystem.getdocs(b; modules = Module[]),
    d_4 = DocSystem.getdocs(DocSystem.binding(current_module(), :alias_of_getdocs)),
    d_5 = DocSystem.getdocs(DocSystem.binding(current_module(), :alias_of_getdocs); aliases = false)

    @test length(d_0) == 0
    @test length(d_1) == 2
    @test length(d_2) == 1
    @test length(d_3) == 0
    @test length(d_4) == 2
    @test length(d_5) == 0

    @test d_1[1].data[:binding] == b
    @test d_1[2].data[:binding] == b
    @test d_1[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
    @test d_1[2].data[:typesig] == Union{Tuple{ANY}, Tuple{ANY, Type}}
    @test d_1[1].data[:module]  == DocSystem
    @test d_1[2].data[:module]  == DocSystem
    @test d_1[1].data[:source]  != quote end
    @test d_1[2].data[:source]  != quote end

    @test d_2[1].data[:binding] == b
    @test d_2[1].data[:typesig] == Union{Tuple{ANY}, Tuple{ANY, Type}}
    @test d_2[1].data[:module]  == DocSystem
    @test d_2[1].data[:source]  != quote end

    @test d_1 == d_4
    @test d_1 != d_5
end


# Integration tests for module api.

# Error reporting.

info("The following errors are expected output.")
include(joinpath("errors", "make.jl"))
info("END of expected error output.")

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

# Try generating documentation with generate()

pkg_generate = if VERSION >= v"0.5-"
    isdir(Pkg.dir("PkgDev")) || Pkg.add("PkgDev")
    import PkgDev
    PkgDev.generate
else
    Pkg.generate
end

const testpkgname = "DocumenterTestPackage"

function check_generated_files(path)
    @test isdir(path)
    @test isfile(joinpath(path, "mkdocs.yml"))
    @test isfile(joinpath(path, ".gitignore"))
    @test isfile(joinpath(path, "make.jl"))
    @test isdir(joinpath(path, "src"))
    @test isfile(joinpath(path, "src", "index.md"))
end

if ispath(Pkg.dir(testpkgname))
    error("A package is already installed at $(Pkg.dir(testpkgname))")
else
    try
        pkg_generate(testpkgname,"MIT",config=Dict("user.name"=>"Julia Test", "user.email"=>"tests@docs.julia"))
        Documenter.generate(testpkgname)
        check_generated_files(Pkg.dir(testpkgname,"docs"))
    finally
        Pkg.rm(testpkgname)
    end
end

# try generating at a custom location
let path = joinpath(Pkg.dir("Documenter"), "test", "docs")
    Documenter.generate(testpkgname, dir=path)
    check_generated_files(path)
    rm(path,recursive=true)
end

end

include(Pkg.dir("Documenter", "docs", "make.jl"))
