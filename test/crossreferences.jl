module CrossReferencesTests
import Documenter
using Test

@testset "CrossReferences" begin
    @test Documenter.xrefname("") === nothing
    @test Documenter.xrefname("@") === nothing
    @test Documenter.xrefname("@re") === nothing
    @test Documenter.xrefname("@refx") === nothing
    @test Documenter.xrefname("@ref#") === nothing
    @test Documenter.xrefname("@ref_") === nothing
    # basic at-refs
    @test Documenter.xrefname("@ref") == ""
    @test Documenter.xrefname("@ref ") == ""
    @test Documenter.xrefname("@ref     ") == ""
    @test Documenter.xrefname("@ref\t") == ""
    @test Documenter.xrefname("@ref\t  ") == ""
    @test Documenter.xrefname("@ref \t") == ""
    @test Documenter.xrefname(" @ref") == ""
    @test Documenter.xrefname(" \t@ref") == ""
    # named at-refs
    @test Documenter.xrefname("@ref foo") == "foo"
    @test Documenter.xrefname("@ref      foo") == "foo"
    @test Documenter.xrefname("@ref  foo  ") == "foo"
    @test Documenter.xrefname("@ref \t foo \t ") == "foo"
    @test Documenter.xrefname("@ref\tfoo") == "foo"
    @test Documenter.xrefname("@ref foo%bar") == "foo%bar"
    @test Documenter.xrefname("@ref  foo bar  \t baz   ") == "foo bar  \t baz"
    @test Documenter.xrefname(" \t@ref  foo") == "foo"
end

@testset "CrossReference classification" begin
    headers = Documenter.AnchorMap()
    Documenter.anchor_add!(headers, :dummy, "existing-id", "index.html")
    Documenter.anchor_add!(headers, :dummy, "DocsReferencingMain.g", "index.html")

    @test Documenter.classifyxref("", (:text, "Header title"), headers) ==
        (kind = :implicit_header, target = "Header title", slug = "Header-title")
    @test Documenter.classifyxref("", (:text, "#123"), headers) ==
        (kind = :issue, target = "123", slug = "#123")
    @test Documenter.classifyxref("", (:code, "Main.f"), headers) ==
        (kind = :implicit_docs, target = "Main.f", slug = "Main.f")

    @test Documenter.classifyxref("\"Header title\"", (:text, "label"), headers) ==
        (kind = :explicit_header_title, target = "Header title", slug = "Header-title")
    @test Documenter.classifyxref("#123", (:text, "label"), headers) ==
        (kind = :issue, target = "123", slug = "#123")
    @test Documenter.classifyxref("`Main.f`", (:text, "label"), headers) ==
        (kind = :explicit_docs, target = "Main.f", slug = "Main.f")
    @test Documenter.classifyxref("existing-id", (:text, "label"), headers) ==
        (kind = :explicit_header_id, target = "existing-id", slug = "existing-id")
    @test Documenter.classifyxref("missing-id", (:text, "label"), headers) ==
        (kind = :explicit_header_id, target = "missing-id", slug = "missing-id")
    @test Documenter.classifyxref("Main.f", (:text, "label"), headers) ==
        (kind = :explicit_docs, target = "Main.f", slug = "Main.f")
    @test Documenter.classifyxref("DocsReferencingMain.g", (:text, "label"), headers) ==
        (kind = :explicit_header_id, target = "DocsReferencingMain.g", slug = "DocsReferencingMain.g")
end

end
