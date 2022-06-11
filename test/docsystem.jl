module DocSystemTests

using Test

import Documenter: Documenter, DocSystem

const alias_of_getdocs = DocSystem.getdocs # NOTE: won't get docstrings if in a @testset

module DocstringAliasTest
"A"
struct A end
"A(x)"
A(x) = A()
B = A
end

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
        d_0 = DocSystem.getdocs(b, Tuple{}),
        d_1 = DocSystem.getdocs(b),
        d_2 = DocSystem.getdocs(b, Union{Tuple{Any}, Tuple{Any, Type}}; compare = (==)),
        d_3 = DocSystem.getdocs(b; modules = Module[Main]),
        d_4 = DocSystem.getdocs(DocSystem.binding(@__MODULE__, :alias_of_getdocs)),
        d_5 = DocSystem.getdocs(DocSystem.binding(@__MODULE__, :alias_of_getdocs); aliases = false),
        d_6 = DocSystem.getdocs(b, Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}; compare = (==)),
        d_7 = DocSystem.getdocs(DocSystem.binding(@__MODULE__, :alias_of_getdocs), Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}})

        @test length(d_0) == 0
        @test length(d_1) == 2
        @test length(d_2) == 1
        @test length(d_3) == 0
        @test length(d_4) == 2
        @test length(d_5) == 0
        @test length(d_6) == 1
        @test length(d_7) == 1

        @test d_1[1].data[:binding] == b
        @test d_1[2].data[:binding] == b
        @test d_1[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
        @test d_1[2].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_1[1].data[:module]  == DocSystem
        @test d_1[2].data[:module]  == DocSystem

        @test d_2[1].data[:binding] == b
        @test d_2[1].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_2[1].data[:module]  == DocSystem

        @test d_6[1].data[:binding] == b
        @test d_6[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
        @test d_6[1].data[:module]  == DocSystem

        @test d_1 == d_4
        @test d_1 != d_5
        @test d_6 == d_7
    end

    ## `UnionAll`
    let b = DocSystem.binding(@__MODULE__, Meta.parse("f(x::T) where T"))
        @test b.var == :f
    end

    # DocstringAliasTest
    a_1 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :A))
    a_2 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :A), Union{})
    a_3 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :A), Tuple{Any})
    b_1 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :B))
    b_2 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :B), Union{})
    b_3 = DocSystem.getdocs(Docs.Binding(DocstringAliasTest, :B), Tuple{Any})
    @test length(a_2) == 1
    @test a_2[1].data[:typesig] == Union{}
    # No signature fetches the docstring of the type (Union{}) in this case
    @test a_1 == a_2
    @test length(a_3) == 1
    @test a_3[1].data[:typesig] == Tuple{Any}
    # Make sure that for an alias we get consistent docstrings
    @test b_1 == a_1
    @test b_2 == a_2
    @test b_3 == a_3
end

end
