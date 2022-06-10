module DocSystemTests

using Test

import Documenter: Documenter, DocSystem
import Base.Docs: Binding, @var

const alias_of_getdocs = DocSystem.getdocs # NOTE: won't get docstrings if in a @testset

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
        @test b.mod === (Documenter)
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
        @test b.mod === (Documenter)
        @test b.var === :Documenter
    end

    ## `MultiDoc` object.
    @test isdefined(DocSystem, :MultiDoc)
    @test (fieldnames(DocSystem.MultiDoc)...,) == (:order, :docs)

    ## `DocStr` object.
    @test isdefined(DocSystem, :DocStr)
    @test (fieldnames(DocSystem.DocStr)...,) == (:text, :object, :data)
    ## `getdocs`.
    let b   = DocSystem.binding(DocSystem, :getdocs),
        getdocs_signature = Union{Tuple{Binding}, Tuple{Binding, Type}},
        d_0 = DocSystem.getdocs(b, Tuple{}),
        d_1 = DocSystem.getdocs(b),
        d_2 = DocSystem.getdocs(b, getdocs_signature; compare = (==)),
        d_3 = DocSystem.getdocs(b; modules = Module[Main]),
        d_4 = DocSystem.getdocs(@var(alias_of_getdocs)),
        d_5 = DocSystem.getdocs(@var(alias_of_getdocs); aliases = false),
        d_6 = DocSystem.getdocs(@var(alias_of_getdocs), getdocs_signature)

        @test length(d_0) == 0
        @test length(d_1) == 2
        @test length(d_2) == 1
        @test length(d_3) == 0
        @test length(d_4) == 2
        @test length(d_5) == 0
        @test length(d_6) == 1

        @test d_1[1].data[:binding] == b
        @test d_1[2].data[:binding] == b
        @test d_1[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
        @test d_1[2].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_1[1].data[:module]  == DocSystem
        @test d_1[2].data[:module]  == DocSystem

        @test d_2[1].data[:binding] == b
        @test d_2[1].data[:typesig] == getdocs_signature
        @test d_2[1].data[:module]  == DocSystem

        @test d_1 == d_4
        @test d_1 != d_5
        @test d_2 == d_6
    end

    ## `UnionAll`
    let b = DocSystem.binding(@__MODULE__, Meta.parse("f(x::T) where T"))
        @test b.var == :f
    end
end

end
