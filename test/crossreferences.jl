module CrossReferencesTests
using Markdown
using Documenter: CrossReferences, Documents, Anchors, Utilities
using Test

# Set up a pseudo-document
function pseudodoc(; kwargs...)
    doc = Documents.Document(; kwargs...)
    doc.blueprint.pages["page.md"] = Documents.Page(
        "src/page.md", "/build/page.md", "src/",
        [], IdDict{Any,Any}(), Documents.Globals(), Utilities.Markdown2.MD(),
    )
    doc.blueprint.pages["headings/foo.md"] = Documents.Page(
        "src/headings/foo.md", "/build/headings/foo.md", "src/",
        [], IdDict{Any,Any}(), Documents.Globals(), Utilities.Markdown2.MD(),
    )
    Anchors.add!(doc.internal.headers, Markdown.Header("Foo Foo", 1), "foo", doc.blueprint.pages["headings/foo.md"].build)
    Anchors.add!(doc.internal.headers, Markdown.Header("Bar Bar", 1), "bar", doc.blueprint.pages["headings/foo.md"].build)
    Anchors.add!(doc.internal.headers, Markdown.Header("Bar", 2), "bar", doc.blueprint.pages["headings/foo.md"].build)
    doc.blueprint.pages["docstrings.md"] = Documents.Page(
        "src/docstrings.md", "/build/docstrings.md", "src/",
        [], IdDict{Any,Any}(), Documents.Globals(), Utilities.Markdown2.MD(),
    )
    # Add a "docstring" for `function foo_fn end` on docstrings.md
    let object = Utilities.Object(Docs.Binding(Main, :foo), Union{})
        doc.internal.objects[object] = Documents.DocsNode(
            nothing,
            Anchors.add!(doc.internal.headers, Markdown.Paragraph(), "foo_fn", doc.blueprint.pages["docstrings.md"].build),
            object,
            doc.blueprint.pages["docstrings.md"],
        )
    end
    return doc
end

@testset "CrossReferences" begin
    @test CrossReferences.xrefname("") === nothing
    @test CrossReferences.xrefname("@") === nothing
    @test CrossReferences.xrefname("@re") === nothing
    @test CrossReferences.xrefname("@refx") === nothing
    @test CrossReferences.xrefname("@ref#") === nothing
    @test CrossReferences.xrefname("@ref_") === nothing
    # basic at-refs
    @test CrossReferences.xrefname("@ref") == ""
    @test CrossReferences.xrefname("@ref ") == ""
    @test CrossReferences.xrefname("@ref     ") == ""
    @test CrossReferences.xrefname("@ref\t") == ""
    @test CrossReferences.xrefname("@ref\t  ") == ""
    @test CrossReferences.xrefname("@ref \t") == ""
    @test CrossReferences.xrefname(" @ref") == ""
    @test CrossReferences.xrefname(" \t@ref") == ""
    # named at-refs
    @test CrossReferences.xrefname("@ref foo") == "foo"
    @test CrossReferences.xrefname("@ref      foo") == "foo"
    @test CrossReferences.xrefname("@ref  foo  ") == "foo"
    @test CrossReferences.xrefname("@ref \t foo \t ") == "foo"
    @test CrossReferences.xrefname("@ref\tfoo") == "foo"
    @test CrossReferences.xrefname("@ref foo%bar") == "foo%bar"
    @test CrossReferences.xrefname("@ref  foo bar  \t baz   ") == "foo bar  \t baz"
    @test CrossReferences.xrefname(" \t@ref  foo") == "foo"

    # Tests for xref, which updates the .url field of Markdown.Links
    function xreftest(f, mdlink; kwargs...)
        global page, doc
        # construct a Markdown.Link by parsing the mdlink string
        link = Markdown.parse(mdlink)
        link = link.content[1].content[1]
        @assert link isa Markdown.Link
        # construct pseudo-objects to pass to xref()
        meta = (;)
        doc = pseudodoc(; kwargs...)
        page = doc.blueprint.pages["page.md"]
        CrossReferences.xref(link, meta, page, doc)
        return f(link, meta, page, doc)
    end
    xref_new_url(mdlink) = xreftest((link, _, _, _) -> link.url, mdlink)
    # non-ref links should not be updated
    @test xref_new_url("[x]()") == ""
    @test xref_new_url("[x](foo)") == "foo"
    @test xref_new_url("[x](@id)") == "@id"
    @test xref_new_url("[x](@refx)") == "@refx"
    @test xref_new_url("[x](  )") == "  "
    @test xref_new_url("[x](  @refx foo)") == "  @refx foo"
    # basic xrefs
    @test xref_new_url("[foo](@ref)") == "headings/foo.md#foo"
    @test_logs (:warn, "'bar' is not unique in src/page.md.") xreftest("[bar](@ref)") do link, meta, page, doc
        @test link.url == "@ref"
        @test :cross_references in doc.internal.errors
    end
    @test_logs (:warn, "reference for 'non-existent' could not be found in src/page.md.") xreftest("[non-existent](@ref)") do link, meta, page, doc
        @test link.url == "@ref"
        @test :cross_references in doc.internal.errors
    end
    xreftest("[#1234](@ref)") do link, meta, page, doc
        @test link.url == Utilities.Remotes.issueurl(doc.user.remote, "1234")
    end
    xreftest("[`foo_fn`](@ref)") do link, meta, page, doc
        #@test link.url == Remotes.issueurl(doc.user.remote, "1234")
        @show link
    end

    # override .remote in doc, to test issue ref failure
    @test_logs (:warn, "unable to generate issue reference for '[`#1234`](@ref)' in src/page.md.") xreftest(
            "[#1234](@ref)", repo = Utilities.Remotes.URL(""),
        ) do link, meta, page, doc
        @test link.url == "@ref"
    end
end

end
