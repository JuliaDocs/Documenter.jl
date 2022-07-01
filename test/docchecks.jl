module DocCheckTests

using Test

using Markdown
using Documenter.DocChecks: linkcheck, allbindings
using Documenter.Documents

# The following modules set up a few docstrings for allbindings tests
module Dep1
    "dep1_private"
    dep1_private() = nothing
    "dep1_private_2"
    dep1_private_2() = nothing
    "dep1_exported"
    dep1_exported() = nothing
    export dep1_exported
    "dep1_reexported"
    dep1_reexported() = nothing
    # test for shadowing exports
    "bar"
    bar() = nothing
end
module Dep2
    # This module extends a function from Dep1, but creates a new local binding
    # for it, to reproduce the case reported in
    # https://github.com/JuliaDocs/Documenter.jl/issues/1695
    using ..Dep1: Dep1
    const dep1_private = Dep1.dep1_private
    "Dep2: dep1_private"
    dep1_private(::Int) = nothing
end
module TestModule
    # Standard case of attaching a docstring to a local binding
    "local_binding"
    local_binding() = nothing
    "local_binding"
    local_binding_exported() = nothing
    export local_binding_exported

    # These extend functions from another module (package). The bindings should
    # all be Dep1.XXX, rather than TestModule.XXX
    using ..Dep1
    "TestModule : dep1_private"
    Dep1.dep1_private(::Any) = nothing
    "TestModule : dep1_exported"
    Dep1.dep1_exported(::Any) = nothing
    import ..Dep1: dep1_private_2
    "TestModule : dep1_private_2"
    dep1_private_2(::Any) = nothing
    # Re-export of a binding from another module
    import ..Dep1: dep1_reexported
    "TestModule : dep1_reexported"
    dep1_reexported(::Any) = nothing
    export dep1_reexported
    # This also extends Dep1.dep1_private, but the docstring should get attached
    # to the Dep2.dep1_private binding because of the assignment.
    using ..Dep2: Dep2
    "TestModuleDep2: Dep2.dep1_private"
    Dep2.dep1_private(::Any, ::Any) = nothing

    #
    const bar = nothing
    export bar
    "Dep1.bar"
    Dep1.bar(::Any) = nothing
end

@testset "DocChecks" begin
    @testset "linkcheck" begin
        if haskey(ENV, "DOCUMENTER_TEST_LINKCHECK")
            src = md"""
                [HTTP (HTTP/1.1) success](http://www.google.com)
                [HTTPS (HTTP/2) success](https://www.google.com)
                [FTP success](ftp://ftp.iana.org/tz/data/etcetera)
                [FTP (no proto) success](ftp.iana.org/tz/data/etcetera)
                [Redirect success](google.com)
                [HEAD fail GET success](https://codecov.io/gh/invenia/LibPQ.jl)
                """

            Documents.walk(Dict{Symbol, Any}(), src) do block
                doc = Documents.Document(; linkcheck=true, linkcheck_timeout=20)
                result = linkcheck(block, doc)
                @test doc.internal.errors == Set{Symbol}()
                result
            end

            src = Markdown.parse("[FILE failure](file://$(@__FILE__))")
            doc = Documents.Document(; linkcheck=true)
            Documents.walk(Dict{Symbol, Any}(), src) do block
                linkcheck(block, doc)
            end
            @test doc.internal.errors == Set{Symbol}([:linkcheck])

            src = Markdown.parse("[Timeout](http://httpbin.org/delay/3)")
            doc = Documents.Document(; linkcheck=true, linkcheck_timeout=0.1)
            Documents.walk(Dict{Symbol, Any}(), src) do block
                linkcheck(block, doc)
            end
            @test doc.internal.errors == Set{Symbol}([:linkcheck])
        else
            @info "DOCUMENTER_TEST_LINKCHECK not set, skipping online linkcheck tests."
            @test_broken false
        end
    end

    @testset "allbindings" begin
        # dep1_private has not been imported into TestModule, so the binding does not
        # resolve to the Deps1 binding.
        @test Docs.Binding(TestModule, :dep1_private) != Docs.Binding(Dep1, :dep1_private)
        @test Docs.Binding(TestModule, :dep1_private) != Docs.Binding(Dep2, :dep1_private)
        # These three bindings are imported into the TestModule scope, so the Binding objects
        # automatically resolve to the Dep1.X bindings.
        @test Docs.Binding(TestModule, :dep1_private_2) == Docs.Binding(Dep1, :dep1_private_2)
        @test Docs.Binding(TestModule, :dep1_exported) == Docs.Binding(Dep1, :dep1_exported)
        @test Docs.Binding(TestModule, :dep1_reexported) == Docs.Binding(Dep1, :dep1_reexported)
        # There is a TestModule.bar, but it's not the same as Dep1.bar, but the latter has
        # a docstring in TestModule.
        @test Docs.Binding(TestModule, :bar) != Docs.Binding(Dep1, :bar)

        let bindings = allbindings(:all, TestModule)
            @test length(bindings) == 7
            @test Docs.Binding(TestModule, :local_binding) in keys(bindings)
            @test Docs.Binding(TestModule, :local_binding_exported) in keys(bindings)

            # Replicates #1857
            @test_broken Docs.Binding(Dep1, :dep1_private) in keys(bindings)
            @test Docs.Binding(TestModule, :dep1_private) in keys(bindings)

            @test Docs.Binding(Dep1, :dep1_private_2) in keys(bindings)
            @test Docs.Binding(Dep1, :dep1_exported) in keys(bindings)
            @test Docs.Binding(Dep1, :dep1_reexported) in keys(bindings)

            # Broken export counting
            @test_broken Docs.Binding(Dep1, :bar) in keys(bindings)
            @test Docs.Binding(TestModule, :bar) in keys(bindings)

            # This docstring currently completely disappears from allbindings since it shares
            # the binding with Dep1.dep1_private
            @test_broken Docs.Binding(Dep2, :dep1_private) in keys(bindings)

            display(bindings)
        end
        let bindings = allbindings(:exports, TestModule)
            @test_broken length(bindings) == 2; @test length(bindings) == 3
            @test Docs.Binding(TestModule, :local_binding_exported) in keys(bindings)
            @test Docs.Binding(Dep1, :dep1_reexported) in keys(bindings)

            # Broken export counting
            @test_broken Docs.Binding(Dep1, :bar) in keys(bindings)
            @test Docs.Binding(TestModule, :bar) in keys(bindings)

            display(bindings)
        end
    end
end

end
