module OnlineLinkcheckTests
using Documenter: Documenter, MarkdownAST, AbstractTrees
using Documenter: linkcheck
using Markdown
using HTTP
using Test

PORT = rand(10_000:40_000)
function lincheck_server_handler(req::HTTP.Request)
    useragent = HTTP.header(req, "user-agent")
    if startswith(useragent, "Mozilla/5.0")
        return HTTP.Response(404)
    elseif startswith(useragent, "curl")
        return HTTP.Response(200)
    end
    return HTTP.Response(500)
end
server = HTTP.serve!(lincheck_server_handler, PORT)

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
            """
        )
        doc = Documenter.Document(; linkcheck = true, linkcheck_timeout = 20)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:warn,) (:warn,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}()
    end

    @testset "Empty User-Agent" begin
        # This used to point to
        #
        #   https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library.html)
        #
        # but now we use a mock HTTP server, to guarantee that the server's behavior doesn't change.
        src = convert(
            MarkdownAST.Node,
            Markdown.parse(
                """
                [Linkcheck Empty UA](http://localhost:$(PORT)/content/www/us/en/developer/tools/oneapi/mpi-library.html)
                """
            )
        )

        # The default user-agent fails (server blocks it, returns a 500)
        doc = Documenter.Document(; linkcheck = true, linkcheck_timeout = 20)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:error,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck])

        # You can work around by setting linkcheck_useragent=nothing and defaulting to the Curl's user agent
        doc = Documenter.Document(; linkcheck = true, linkcheck_timeout = 20, linkcheck_useragent = nothing)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}()
    end

    @testset "Failures" begin
        src = convert(MarkdownAST.Node, Markdown.parse("[FILE failure](file://$(@__FILE__))"))
        doc = Documenter.Document(; linkcheck = true)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:error,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck])

        src = Markdown.parse("[Timeout](http://httpbin.org/delay/3)")
        doc = Documenter.Document(; linkcheck = true, linkcheck_timeout = 0.1)
        doc.blueprint.pages["testpage"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
        @test_logs (:error,) @test linkcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck])
    end

    @testset "Linkcheck in Docstrings" begin
        include("docstring_links/make.jl")
    end

end

# Close the mock HTTP server
close(server)

end # module
