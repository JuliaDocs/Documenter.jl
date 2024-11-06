module OnlineGithubCheckTests
using Documenter: Documenter, MarkdownAST, AbstractTrees, render, expand, walk_navpages, githubcheck
using Documenter.HTMLWriter: render_article, HTMLContext, HTML
using Markdown
using Test

include("../repolink_helpers.jl")

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

    @testset "Failure" begin
        src = convert(
            MarkdownAST.Node,
            md"""
            ```@meta
            CurrentModule = Main.OnlineGithubCheckTests.TestHelperModule
            ```
            This doc will not pass the checks because this version isn't tagged
            ```@docs
            RegistryInstances
            ```
            """
        )
        doc, html = render_expand_doc(src)

        # Links to repo
        re = r"<a[^>]+ href=['\"]?https://github.com/GunnarFarneback/RegistryInstances.jl"
        @test occursin(re, string(html))

        # Gets an error on check
        @test_logs (:error,) @test githubcheck(doc) === nothing
        @test doc.internal.errors == Set{Symbol}([:linkcheck_remotes])
    end
end

end
