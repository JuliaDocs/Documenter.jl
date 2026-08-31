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
    anchors = Documenter.AnchorMap()
    Documenter.anchor_add!(anchors, :dummy, "existing-id", "index.html")
    Documenter.anchor_add!(anchors, :dummy, "DocsReferencingMain.g", "index.html")

    @test Documenter.classifyxref("", (:text, "Header title"), anchors) ==
        (kind = :implicit_header, target = "Header title", slug = "Header-title")
    @test Documenter.classifyxref("", (:text, "#123"), anchors) ==
        (kind = :issue, target = "123", slug = "#123")
    @test Documenter.classifyxref("", (:code, "Main.f"), anchors) ==
        (kind = :implicit_docs, target = "Main.f", slug = "Main.f")

    @test Documenter.classifyxref("\"Header title\"", (:text, "label"), anchors) ==
        (kind = :explicit_header_title, target = "Header title", slug = "Header-title")
    @test Documenter.classifyxref("#123", (:text, "label"), anchors) ==
        (kind = :issue, target = "123", slug = "#123")
    @test Documenter.classifyxref("`Main.f`", (:text, "label"), anchors) ==
        (kind = :explicit_docs, target = "Main.f", slug = "Main.f")
    @test Documenter.classifyxref("existing-id", (:text, "label"), anchors) ==
        (kind = :explicit_header_id, target = "existing-id", slug = "existing-id")
    @test Documenter.classifyxref("missing-id", (:text, "label"), anchors) ==
        (kind = :explicit_header_id, target = "missing-id", slug = "missing-id")
    @test Documenter.classifyxref("Main.f", (:text, "label"), anchors) ==
        (kind = :explicit_docs, target = "Main.f", slug = "Main.f")
    @test Documenter.classifyxref("DocsReferencingMain.g", (:text, "label"), anchors) ==
        (kind = :explicit_header_id, target = "DocsReferencingMain.g", slug = "DocsReferencingMain.g")
end

# Helpers for the `@id` anchor testsets below, which each build small standalone docs.
using CodecZlib: ZlibDecompressor, transcode
import IOCapture

function build_doc(files::Vector{Pair{String, String}}; kwargs...)
    tmp = mktempdir()
    src = joinpath(tmp, "src")
    mkpath(joinpath(src, "assets"))
    write(joinpath(src, "assets", "logo.png"), "\x89PNG\r\n\x1a\n")
    for (name, content) in files
        write(joinpath(src, name), content)
    end
    # Captured so that the many builds below do not drown the test log; errors still
    # propagate, which the `@test_throws` cases below rely on.
    IOCapture.capture() do
        Documenter.makedocs(;
            root = tmp, sitename = "T", pages = [f.first for f in files],
            format = Documenter.HTML(edit_link = nothing, disable_git = true, inventory_version = "1.0"),
            remotes = nothing, kwargs...,
        )
    end
    return tmp
end

function read_inventory(tmp)
    bytes = read(joinpath(tmp, "build", "objects.inv"))
    hdrend = findlast(codeunits("zlib.\n"), bytes)
    return String(transcode(ZlibDecompressor, bytes[(last(hdrend) + 1):end]))
end

# Arbitrary anchors on inline content via `[content](@id name)` (issue #745).
@testset "Inline @id anchors" begin
    # Happy path: inline text anchor + a thumbnail-image anchor, both referenced.
    tmp = build_doc(
        [
            "index.md" => """
                # Header

                Inline anchor: [my target](@id my-anchor) mid-sentence.

                Thumbnail: [![thumb](assets/logo.png)](@id fig-anchor)

                Refs: [go to target](@ref my-anchor) and [see figure](@ref fig-anchor).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("<span id=\"my-anchor\">", html)
    @test occursin("<span id=\"fig-anchor\">", html)
    @test occursin("href=\"#my-anchor\"", html)
    @test occursin("href=\"#fig-anchor\"", html)
    # The anchors are written to the inventory as std:label entries.
    inv = read_inventory(tmp)
    @test occursin("my-anchor std:label", inv)
    @test occursin("fig-anchor std:label", inv)

    # The id is slugified exactly like a header `@id`, so an id with spaces/mixed case
    # yields a valid HTML id and resolves via its slug (matching header behaviour).
    tmp = build_doc(
        [
            "index.md" => "# H\n\n[content](@id My Anchor Name).\n\nRef: [x](@ref My-Anchor-Name).\n",
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("<span id=\"My-Anchor-Name\">", html)
    @test !occursin("id=\"My Anchor Name\"", html)
    @test occursin("href=\"#My-Anchor-Name\"", html)

    # Forward/cross-page reference to an inline anchor defined on a later page.
    tmp = build_doc(
        [
            "a.md" => "# A\n\nSee [target](@ref cross-anchor).\n",
            "b.md" => "# B\n\nHere: [the target](@id cross-anchor).\n",
        ]
    )
    @test occursin("href=\"../b/#cross-anchor\"", read(joinpath(tmp, "build", "a", "index.html"), String))

    # `@contents` must not trip over inline anchors sharing the header AnchorMap.
    @test (build_doc(["index.md" => "# Top\n\n```@contents\n```\n\n## Sec\n\n[t](@id inline-a).\n"]); true)

    # A referenced duplicate id is an error, not a silent pick.
    @test_throws Exception build_doc(
        [
            "index.md" => "# H\n\n[a](@id dup) and [b](@id dup).\n\nRef: [x](@ref dup).\n",
        ]
    )

    # Inline anchors are found inside nested containers (admonitions, lists, ...).
    tmp = build_doc(
        [
            "index.md" => """
                # H

                !!! note
                    An [anchored note](@id in-admon).

                * a list item with [an anchor](@id in-list)

                Refs: [x](@ref in-admon) and [y](@ref in-list).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("<span id=\"in-admon\">", html)
    @test occursin("<span id=\"in-list\">", html)

    # An inline id sharing the header namespace collides with a header slug of the same name.
    @test_throws Exception build_doc(["index.md" => "# Foo\n\ntext [x](@id Foo).\n\nRef: [r](@ref Foo).\n"])

    # An empty-content anchor `[](@id name)` uses `-` as its inventory display name.
    tmp = build_doc(["index.md" => "# H\n\n[](@id empty1)\n\nRef [r](@ref empty1).\n"])
    @test any(l -> startswith(l, "empty1 std:label -1 ") && endswith(strip(l), " -"), split(read_inventory(tmp), '\n'))
end

# Named anchors on admonitions via a `!!! note "[title](@id name)"` title.
@testset "Admonition @id anchors" begin
    # Happy path: the link is stripped from the rendered title, the anchor id becomes the
    # HTML id of the admonition element itself (and its permalink target) instead of the
    # content-hash based one, and `@ref`s resolve to it.
    tmp = build_doc(
        [
            "index.md" => """
                # Header

                !!! note "[Named note](@id note-anchor)"
                    Note content.

                Ref: [see the note](@ref note-anchor).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin(Regex("<div class=\"admonition is-info\"[^>]*\\bid=\"note-anchor\""), html)
    @test occursin("href=\"#note-anchor\"", html)
    @test occursin(">Named note<", html)
    @test !occursin("[Named note]", html)
    @test occursin(">see the note</a>", html)
    # The anchor is written to the inventory as a std:label entry, with the admonition
    # title (not its whole content) as the display name.
    inv = read_inventory(tmp)
    @test any(l -> startswith(l, "note-anchor std:label -1 ") && endswith(strip(l), " Named note"), split(inv, '\n'))

    # `!!! details` admonitions render as a <details> element; the id transfers there too.
    tmp = build_doc(
        [
            "index.md" => """
                # H

                !!! details "[Show more](@id details-anchor)"
                    Hidden content.

                Ref: [more](@ref details-anchor).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin(Regex("<details class=\"admonition is-details\"[^>]*\\bid=\"details-anchor\""), html)
    @test occursin("href=\"#details-anchor\"", html)

    # The id is slugified exactly like a header `@id`, and an admonition without an `@id`
    # anchor keeps the content-hash based id. The title is parsed as markdown, so inline
    # markup inside the `@id` link is flattened to plain text (admonition titles are plain
    # strings), and a title that is a regular link (not `@id`) is left alone.
    tmp = build_doc(
        [
            "index.md" => """
                # H

                !!! warning "[Slug me](@id My Adm Id)"
                    Content.

                !!! note "Plain title"
                    Content.

                !!! tip "[**Bold** `code` title](@id markup-adm)"
                    Content.

                !!! note "[link](https://example.com)"
                    Content.

                Refs: [x](@ref My-Adm-Id) and [y](@ref markup-adm).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("id=\"My-Adm-Id\"", html)
    @test !occursin("id=\"My Adm Id\"", html)
    @test occursin(r"id=\"Plain-title-[0-9a-f]+\"", html)
    @test occursin("id=\"markup-adm\"", html)
    @test occursin(">Bold code title<", html)
    @test occursin("[link](https://example.com)", html)

    # Forward/cross-page reference to an admonition anchor defined on a later page.
    tmp = build_doc(
        [
            "a.md" => "# A\n\nSee [the note](@ref adm-cross).\n",
            "b.md" => "# B\n\n!!! note \"[Target note](@id adm-cross)\"\n    Content.\n",
        ]
    )
    @test occursin("href=\"../b/#adm-cross\"", read(joinpath(tmp, "build", "a", "index.html"), String))

    # Nested admonitions are found too.
    tmp = build_doc(
        [
            "index.md" => """
                # H

                !!! warning "[Outer](@id outer-adm)"
                    !!! tip "[Inner](@id inner-adm)"
                        Content.

                Refs: [x](@ref outer-adm) and [y](@ref inner-adm).
                """,
        ]
    )
    html = read(joinpath(tmp, "build", "index.html"), String)
    @test occursin("id=\"outer-adm\"", html)
    @test occursin("id=\"inner-adm\"", html)

    # Admonition anchors share the id namespace with headers and inline anchors, so a
    # referenced duplicate id is an error, not a silent pick.
    @test_throws Exception build_doc(
        [
            "index.md" => "# Foo\n\n!!! note \"[x](@id Foo)\"\n    Content.\n\nRef: [r](@ref Foo).\n",
        ]
    )

    # `@contents` must not trip over admonition anchors sharing the header AnchorMap.
    @test (build_doc(["index.md" => "# Top\n\n```@contents\n```\n\n## Sec\n\n!!! note \"[T](@id adm-a)\"\n    C.\n"]); true)

    # An empty title `!!! note "[](@id name)"` keeps the title empty and uses `-` as the
    # inventory display name.
    tmp = build_doc(["index.md" => "# H\n\n!!! note \"[](@id adm-empty)\"\n    Content.\n\nRef [r](@ref adm-empty).\n"])
    @test occursin("id=\"adm-empty\"", read(joinpath(tmp, "build", "index.html"), String))
    @test any(l -> startswith(l, "adm-empty std:label -1 ") && endswith(strip(l), " -"), split(read_inventory(tmp), '\n'))
end

end
