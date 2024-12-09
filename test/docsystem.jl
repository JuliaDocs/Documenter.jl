module DocSystemTests

using Test

import Documenter: Documenter, DocSystem

const alias_of_getdocs = DocSystem.getdocs # NOTE: won't get docstrings if in a @testset

module TestDocstrings
    "A"
    struct A end
    "A(x)"
    A(x) = A()
    B = A

    "foo(::Number)"
    foo(::Number) = nothing

    "foo(::Float64)"
    foo(::Float64) = nothing

    const bar = foo
    const baz = foo

    "baz(::Number)"
    baz(::Number)

    "baz(::Float64)"
    baz(::Float64)

    using Markdown: @doc_str
    @doc doc"qux(::Float64)"
    qux(::Float64)
end

@testset "DocSystem" begin
    ## Bindings.
    @test_throws ArgumentError DocSystem.binding(9000)
    let b = Docs.Binding(@__MODULE__, :DocSystem)
        @test DocSystem.binding(b) == b
    end
    let b = DocSystem.binding(Documenter.Document)
        @test b.mod === Documenter
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
    let b = DocSystem.binding(DocSystem, :getdocs),
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
        @test d_1[1].data[:module] == DocSystem
        @test d_1[2].data[:module] == DocSystem

        @test d_2[1].data[:binding] == b
        @test d_2[1].data[:typesig] == Union{Tuple{Any}, Tuple{Any, Type}}
        @test d_2[1].data[:module] == DocSystem

        @test d_6[1].data[:binding] == b
        @test d_6[1].data[:typesig] == Union{Tuple{Docs.Binding}, Tuple{Docs.Binding, Type}}
        @test d_6[1].data[:module] == DocSystem

        @test d_1 == d_4
        @test d_1 != d_5
        @test d_6 == d_7
    end

    ## `UnionAll`
    let b = DocSystem.binding(@__MODULE__, Meta.parse("f(x::T) where T"))
        @test b.var == :f
    end

    # TestDocstrings
    a_1 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :A))
    a_2 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :A), Union{})
    a_3 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :A), Tuple{Any})
    b_1 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :B))
    b_2 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :B), Union{})
    b_3 = DocSystem.getdocs(Docs.Binding(TestDocstrings, :B), Tuple{Any})
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

    # Tests for method and alias fallback logic
    foo_1 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo))
    foo_2 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{Int})
    foo_3 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{Float64})
    foo_4 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{AbstractFloat})
    foo_5 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{Number})
    foo_6 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{Any})

    @test length(foo_1) == 2 # should have fetched both docstrings

    @test length(foo_5) == 1 # contains docstring for generic ::Number method
    @test foo_5[1].data[:binding] == Docs.Binding(TestDocstrings, :foo)
    @test foo_5[1].data[:typesig] == Tuple{Number}

    @test isempty(foo_6) # this shouldn't match anything
    @test foo_2 == foo_5 # ::Int dispatches to ::Number
    @test foo_4 == foo_5 # ::AbstractFloat also dispatches to ::Number

    @test foo_3 != foo_5 # foo(::Float64) has its own docstring
    @test foo_3[1].data[:binding] == Docs.Binding(TestDocstrings, :foo)
    @test foo_3[1].data[:typesig] == Tuple{Float64}

    @test foo_2[1] ∈ foo_1
    @test foo_3[1] ∈ foo_1

    # setting 'compare' to subtype, will fetch both docstrings
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :foo), Tuple{Float64}, compare = (<:)) == foo_1

    # bar is an alias, so falls back to foo
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar)) == foo_1
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Int}) == foo_2
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Float64}) == foo_3
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{AbstractFloat}) == foo_4
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Number}) == foo_5
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Any}) == foo_6
    # unless we disable following aliases
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar); aliases = false) |> isempty
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Int}; aliases = false) |> isempty
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Float64}; aliases = false) |> isempty
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{AbstractFloat}; aliases = false) |> isempty
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Number}; aliases = false) |> isempty
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :bar), Tuple{Any}; aliases = false) |> isempty

    # baz, while an alias of foo, has the same 'structure', but different docstrings..
    baz_1 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz))
    baz_2 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Int})
    baz_3 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Float64})
    baz_4 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{AbstractFloat})
    baz_5 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Number})
    baz_6 = Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Any})

    @test length(baz_1) == 2 # should have fetched both docstrings

    @test length(baz_5) == 1 # contains docstring for generic ::Number method
    @test baz_5[1].data[:binding] == Docs.Binding(TestDocstrings, :baz)
    @test baz_5[1].data[:typesig] == Tuple{Number}

    @test isempty(baz_6) # this shouldn't match anything
    @test baz_2 == baz_5 # ::Int dispatches to ::Number
    @test baz_4 == baz_5 # ::AbstractFloat also dispatches to ::Number

    @test baz_3 != baz_5 # baz(::Float64) has its own docstring
    @test baz_3[1].data[:binding] == Docs.Binding(TestDocstrings, :baz)
    @test baz_3[1].data[:typesig] == Tuple{Float64}

    @test baz_2[1] ∈ baz_1
    @test baz_3[1] ∈ baz_1

    # .. even if we disable aliases
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz); aliases = false) == baz_1
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Int}; aliases = false) == baz_2
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Float64}; aliases = false) == baz_3
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{AbstractFloat}; aliases = false) == baz_4
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Number}; aliases = false) == baz_5
    @test Documenter.DocSystem.getdocs(Docs.Binding(TestDocstrings, :baz), Tuple{Any}; aliases = false) == baz_6
end

end
