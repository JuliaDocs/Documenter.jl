module OnlineGithubCheckTests
using Documenter: Documenter, MarkdownAST, AbstractTrees, render, expand, walk_navpages, githubcheck
using Documenter.HTMLWriter: render_article, HTMLContext, HTML
using Markdown
using Test

include("../repolink_helpers.jl")

# A Document with a single remote that looks like it was guessed from the registry, so
# that githubcheck queries the GitHub API for it. Using a synthetic remote rather than a
# live package keeps the failure modes reproducible -- a real package that happens to be
# untagged today gets tagged tomorrow.
const MARKDOWNAST_UUID = Base.UUID("d0879d2d-cac2-40c8-9cee-1863dc0c7391")
function synthetic_remote_doc(version::VersionNumber, tree_hash::AbstractString)
    doc = Documenter.Document(; sitename = "sitename", linkcheck = true)
    # Not a real path; githubcheck only ever uses it as a dictionary key.
    root = joinpath(@__DIR__, "synthetic-package-root")
    doc.internal.src_to_uuid[root] = MARKDOWNAST_UUID
    doc.internal.uuid_to_version_info[MARKDOWNAST_UUID] = (version, tree_hash)
    remote = Documenter.Remotes.GitHub("JuliaDocs", "MarkdownAST.jl")
    Documenter.addremote!(doc, Documenter.RemoteRepository(root, remote, "v$(version)"))
    return doc
end

@testset "Online githubcheck" begin
    @testset "Success" begin
        src = convert(
            MarkdownAST.Node,
            md"""
            ```@meta
            CurrentModule = Main.OnlineGithubCheckTests.TestHelperModule
            ```
            ```@docs
            MarkdownAST.Node
            ```
            """
        )
        doc, html = render_expand_doc(src)

        # Links to repo
        re = r"<a[^>]+ href=['\"]?https://github.com/JuliaDocs/MarkdownAST.jl"
        @test occursin(re, string(html))

        # No error on check
        @test githubcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}()
    end

    @testset "Failure: no such tag" begin
        doc = synthetic_remote_doc(v"999.999.999", "0"^40)
        @test_logs (:error,) @test githubcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck_remotes])
    end

    @testset "Failure: tree hash mismatch" begin
        # v0.1.2 exists, but not with this tree hash.
        doc = synthetic_remote_doc(v"0.1.2", "0"^40)
        @test_logs (:error,) @test githubcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck_remotes])
    end
end

end
