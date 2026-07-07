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

# Arbitrary anchors on inline content via `[content](@id name)` (issue #745).
@testset "Inline @id anchors" begin
    using CodecZlib: ZlibDecompressor, transcode

    function build_doc(files::Vector{Pair{String, String}}; kwargs...)
        tmp = mktempdir()
        src = joinpath(tmp, "src")
        mkpath(joinpath(src, "assets"))
        write(joinpath(src, "assets", "logo.png"), "\x89PNG\r\n\x1a\n")
        for (name, content) in files
            write(joinpath(src, name), content)
        end
        Documenter.makedocs(;
            root = tmp, sitename = "T", pages = [f.first for f in files],
            format = Documenter.HTML(edit_link = nothing, disable_git = true, inventory_version = "1.0"),
            remotes = nothing, kwargs...,
        )
        return tmp
    end

    function read_inventory(tmp)
        bytes = read(joinpath(tmp, "build", "objects.inv"))
        hdrend = findlast(codeunits("zlib.\n"), bytes)
        return String(transcode(ZlibDecompressor, bytes[(last(hdrend) + 1):end]))
    end

    # Happy path: inline text anchor + a thumbnail-image anchor, both referenced.
    tmp = build_doc([
        "index.md" => """
        # Header

        Inline anchor: [my target](@id my-anchor) mid-sentence.

        Thumbnail: [![thumb](assets/logo.png)](@id fig-anchor)

        Refs: [go to target](@ref my-anchor) and [see figure](@ref fig-anchor).
        """,
    ])
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("<a id=\"my-anchor\">", html)
    @test occursin("<a id=\"fig-anchor\">", html)
    @test occursin("href=\"#my-anchor\"", html)
    @test occursin("href=\"#fig-anchor\"", html)
    # The anchors are written to the inventory as std:label entries.
    inv = read_inventory(tmp)
    @test occursin("my-anchor std:label", inv)
    @test occursin("fig-anchor std:label", inv)

    # Forward/cross-page reference to an inline anchor defined on a later page.
    tmp = build_doc([
        "a.md" => "# A\n\nSee [target](@ref cross-anchor).\n",
        "b.md" => "# B\n\nHere: [the target](@id cross-anchor).\n",
    ])
    @test occursin("href=\"../b/#cross-anchor\"", read(joinpath(tmp, "build", "a", "index.html"), String))

    # `@contents` must not trip over inline anchors sharing the header AnchorMap.
    @test (build_doc(["index.md" => "# Top\n\n```@contents\n```\n\n## Sec\n\n[t](@id inline-a).\n"]); true)

    # A referenced duplicate id is an error, not a silent pick.
    @test_throws Exception build_doc([
        "index.md" => "# H\n\n[a](@id dup) and [b](@id dup).\n\nRef: [x](@ref dup).\n",
    ])
end

end
