module OnlineLinkcheckTests
using Documenter: Documenter, MarkdownAST, AbstractTrees
using Documenter: linkcheck
using Markdown
using Test

@testset "Online linkcheck" begin

    @testset "Successes" begin
        src = convert(
            MarkdownAST.Node,
            md"""
            [HTTP (HTTP/1.1) success](http://www.google.com)
            [HTTPS (HTTP/2) success](https://www.google.com)
            [FTP success](ftp://ftp.iana.org/tz/data/etcetera)
            [FTP (no proto) success](ftp.iana.org/tz/data/etcetera)
            [Redirect success](google.com)
            [HEAD fail GET success](https://codecov.io/gh/invenia/LibPQ.jl)
            [Linkcheck old Chrome UA fail](https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library.html)
            """
        )
        doc = Documenter.Document(; linkcheck=true, linkcheck_timeout=20)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:warn,) (:warn,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}()
    end

    @testset "Failures" begin
        src = convert(MarkdownAST.Node, Markdown.parse("[FILE failure](file://$(@__FILE__))"))
        doc = Documenter.Document(; linkcheck=true)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:error,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck])

        src = Markdown.parse("[Timeout](http://httpbin.org/delay/3)")
        doc = Documenter.Document(; linkcheck=true, linkcheck_timeout=0.1)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:error,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck])
    end

    @testset "Linkcheck in Docstrings" begin
        include("docstring_links/make.jl")
    end

end

end # module
