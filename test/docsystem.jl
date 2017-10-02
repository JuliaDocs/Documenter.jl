module DocSystemTests

using Test
using Compat

import Documenter: Documenter, DocSystem

const alias_of_getdocs = DocSystem.getdocs # NOTE: won't get docstrings if in a @testset

PACKAGES_LOADED_MAIN = VERSION < v"0.7.0-DEV.1877"

@testset "DocSystem" begin
    ## Bindings.
    @test_throws ArgumentError DocSystem.binding(9000)
    let b = Docs.Binding(@__MODULE__, :DocSystem)
        @test DocSystem.binding(b) == b
    end
    let b = DocSystem.binding(Documenter.Documents.Document)
        @test b.mod === Documenter.Documents
        @test b.var === :Document
    end
    let b = DocSystem.binding(Documenter)
        @test b.mod === (PACKAGES_LOADED_MAIN ? Main : Documenter)
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
    let b = DocSystem.binding(Documenter, :Documenter)
        @test b.mod === (PACKAGES_LOADED_MAIN ? Main : Documenter)
        @test b.var === :Documenter
    end

    ## `MultiDoc` object.
    @test isdefined(DocSystem, :MultiDoc)
    @test fieldnames(DocSystem.MultiDoc) == [:order, :docs]

    ## `DocStr` object.
    @test isdefined(DocSystem, :DocStr)
    @test fieldnames(DocSystem.DocStr) == [:text, :object, :data]
    ## `getdocs`.
    let b   = DocSystem.binding(DocSystem, :getdocs),
        d_0 = DocSystem.getdocs(b, Tuple{}),
        d_1 = DocSystem.getdocs(b),
        d_2 = DocSystem.getdocs(b, Union{Tuple{Any}, Tuple{Any, Type}}; compare = (==)),
        d_3 = DocSystem.getdocs(b; modules = Module[Main]),
        d_4 = DocSystem.getdocs(DocSystem.binding(@__MODULE__, :alias_of_getdocs)),
        d_5 = DocSystem.getdocs(DocSystem.binding(@__MODULE__, :alias_of_getdocs); aliases = false)

        @test length(d_0) == 0
        @test length(d_1) == 2
        @test length(d_2) == 1
        @test length(d_3) == 0
        @test length(d_4) == 2
        @test length(d_5) == 0

        @test d_1[1].data[:binding] == b
        @test d_1[2].data[:binding] == b
        @test d_1[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
        @test d_1[2].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_1[1].data[:module]  == DocSystem
        @test d_1[2].data[:module]  == DocSystem

        @test d_2[1].data[:binding] == b
        @test d_2[1].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_2[1].data[:module]  == DocSystem

        @test d_1 == d_4
        @test d_1 != d_5
    end

    ## `UnionAll`
    let b = DocSystem.binding(@__MODULE__, parse("f(x::T) where T"))
        @test b.var == :f
    end
end

end
