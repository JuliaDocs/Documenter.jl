module DocCheckTests

using Test

using Markdown
using Documenter.DocChecks: linkcheck
using Documenter.Documents

@testset "DocChecks" begin
    # The linkcheck tests are currently not reliable on CI, so they are disabled.
    @testset "linkcheck" begin
        src = md"""
            [HTTP (HTTP/1.1) success](http://www.google.com)
            [HTTPS (HTTP/2) success](https://www.google.com)
            [FTP success](ftp://ftp.iana.org/tz/data/etcetera)
            [FTP (no proto) success](ftp.iana.org/tz/data/etcetera)
            [Redirect success](google.com)
            [HEAD fail GET success](https://codecov.io/gh/invenia/LibPQ.jl)
            """

        Documents.walk(Dict{Symbol, Any}(), src) do block
            doc = Documents.Document(; linkcheck=true)
            result = linkcheck(block, doc)
            @test_skip doc.internal.errors == Set{Symbol}()
            result
        end

        src = Markdown.parse("[FILE failure](file://$(@__FILE__))")
        doc = Documents.Document(; linkcheck=true)
        Documents.walk(Dict{Symbol, Any}(), src) do block
            linkcheck(block, doc)
        end
        @test_skip doc.internal.errors == Set{Symbol}([:linkcheck])
    end
end

end
