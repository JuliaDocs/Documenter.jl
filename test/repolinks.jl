# These tests test the remote repository link handling. We don't do full
# makedocs() builds here, but rather construct a Document object with
# the appropriate `repo` and `remotes` arguments (like for makedocs) and
# then explicitly test the edit_url and source_url functions.
module RepoLinkTests
using Test
using Random: randstring
using Documenter: Documenter, Remotes, git, edit_url, source_url, MarkdownAST, walk_navpages, expand
using Documenter.HTMLWriter: render_article, HTMLContext, HTML
using Markdown
include("TestUtilities.jl"); using Main.TestUtilities

function init_git_repo(
        f, path;
        remote, # (name, url) tuple, or nothing
        user_email = "tester@example.com",
        user_name = "Test Committer",
    )
    path = abspath(path)
    ispath(path) && error("path already exists\n at $(path)")
    mkpath(path)
    cd(path) do
        @test trun(`$(git()) init`)
        @test trun(`$(git()) config user.email "tester@example.com"`)
        @test trun(`$(git()) config user.name "Test Committer"`)
        @test trun(`$(git()) config commit.gpgsign false`)
        if !isnothing(remote)
            name, url = remote
            @test trun(`$(git()) remote add $(name) $(url)`)
        end
        # Run additional code
        f()
        # Commit everything
        @test trun(`$(git()) add -A`)
        @test trun(`$(git()) commit -m"Initial commit."`)
    end
    return Documenter.repo_commit(path)
end

function create_defaultfiles()
    mkpath("docs")
    write("foo", randstring(10))
    mkpath("bar/baz")
    return write("bar/baz/qux", randstring(10))
end

# Set up a complex hierarchy of temporary repositories
tmproot = mktempdir()
mainrepo = joinpath(tmproot, "mainrepo")
mainrepo_commit = init_git_repo(
    create_defaultfiles, mainrepo;
    remote = ("origin", "git@github.com:TestOrg/TestRepo.jl.git")
)
subrepo = joinpath(mainrepo, "subrepo")
subrepo_commit = init_git_repo(
    create_defaultfiles, subrepo;
    remote = ("origin", "git@github.com:TestOrg/AnotherRepo.jl.git")
)
# Second repository in a subdirectory, but without a remote set up, so this would
# require it to be set explicitly in remotes.
subrepo_noremote = joinpath(mainrepo, "bar", "subrepo_noremote")
subrepo_noremote_commit = init_git_repo(create_defaultfiles, subrepo_noremote; remote = nothing)
# A repository outside of the main repository (with remote)
extrepo = joinpath(tmproot, "extrepo")
extrepo_commit = init_git_repo(
    create_defaultfiles, extrepo;
    remote = ("origin", "git@github.com:TestOrg/ExtRepo.jl.git")
)
# A repository outside of the main repository (without remote)
extrepo_noremote = joinpath(tmproot, "extrepo_noremote")
extrepo_noremote_commit = init_git_repo(create_defaultfiles, extrepo_noremote; remote = nothing)
# Just a directory outside of the main repository
extdirectory = joinpath(tmproot, "extdirectory")
mkpath(extdirectory)
cd(create_defaultfiles, extdirectory)

@debug let
    tree = Sys.which("tree")
    if isnothing(tree)
        "`tree` command not found"
    else
        s = read(`$(tree) $(tmproot)`, String)
        "tree @ $tmproot\n$s"
    end
end

@testset "Defaults (no arguments)" begin
    @debug Test.get_testset()
    # First, let's test the default behaviours, without arguments,
    # in which case we should pick up all the Git repositories that
    # have valid origins, and throw on others.
    doc = Documenter.Document(root = joinpath(mainrepo, "docs"))
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo"
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = "main") == "https://github.com/TestOrg/TestRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(mainrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(mainrepo, "foo"), 5:8) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo#L5-L8"
    # Directories are fine too, but non-existent local paths are not
    @test edit_url(doc, joinpath(mainrepo, "bar"); rev = nothing) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/bar"
    @test_throws ErrorException edit_url(doc, joinpath(mainrepo, "nonext"); rev = nothing)
    # We also automatically pick up the Git remote of a subdirectory
    @test edit_url(doc, joinpath(subrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/AnotherRepo.jl/blob/$(subrepo_commit)/foo"
    @test edit_url(doc, joinpath(subrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/AnotherRepo.jl/blob/$(subrepo_commit)/bar/baz/qux"
    # We also automatically pick up the Git remote of path outside the repo
    @test edit_url(doc, joinpath(extrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/foo"
    @test edit_url(doc, joinpath(extrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/bar/baz/qux"
    # But if you don't have the Git origin set, then we error
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(subrepo_noremote, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(subrepo_noremote, "bar", "baz", "qux"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "bar", "baz", "qux"); rev = nothing)
    # And the same applies to external directories
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extdirectory, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extdirectory, "bar", "baz", "qux"); rev = nothing)
end

@testset "Repo only" begin
    @debug Test.get_testset()
    # If we override the `repo` argument (only), we should override everything in the main repository
    doc = Documenter.Document(root = joinpath(mainrepo, "docs"), repo = Remotes.GitHub("AlternateOrg", "TestRepo.jl"))
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = nothing) == "https://github.com/AlternateOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo"
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = "main") == "https://github.com/AlternateOrg/TestRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(mainrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/TestRepo.jl/blob/$(mainrepo_commit)/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(mainrepo, "foo"), 5:8) == "https://github.com/AlternateOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo#L5-L8"
    # We also automatically pick up the Git remote of a subdirectory
    @test edit_url(doc, joinpath(subrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/AnotherRepo.jl/blob/$(subrepo_commit)/foo"
    @test edit_url(doc, joinpath(subrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/AnotherRepo.jl/blob/$(subrepo_commit)/bar/baz/qux"
    # We also automatically pick up the Git remote of path outside the repo
    @test edit_url(doc, joinpath(extrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/foo"
    @test edit_url(doc, joinpath(extrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/bar/baz/qux"
    # But if you don't have the Git origin set, then we error
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(subrepo_noremote, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(subrepo_noremote, "bar", "baz", "qux"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "bar", "baz", "qux"); rev = nothing)
    # And the same applies to external directories
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extdirectory, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extdirectory, "bar", "baz", "qux"); rev = nothing)
end

@testset "repo for extrepo_noremote" begin
    @debug Test.get_testset()
    # We normally can't build for extrepo_noremote because we can't detect the remote repository, but if we set repo=,
    # then we will use that.
    doc = Documenter.Document(root = joinpath(extrepo_noremote, "docs"), repo = Remotes.GitHub("ExtRepoOrg", "TestRepo.jl"))
    @test edit_url(doc, joinpath(extrepo_noremote, "foo"); rev = nothing) == "https://github.com/ExtRepoOrg/TestRepo.jl/blob/$(extrepo_noremote_commit)/foo"
    @test edit_url(doc, joinpath(extrepo_noremote, "foo"); rev = "main") == "https://github.com/ExtRepoOrg/TestRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(extrepo_noremote, "bar", "baz", "qux"); rev = nothing) == "https://github.com/ExtRepoOrg/TestRepo.jl/blob/$(extrepo_noremote_commit)/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(extrepo_noremote, "foo"), 5:8) == "https://github.com/ExtRepoOrg/TestRepo.jl/blob/$(extrepo_noremote_commit)/foo#L5-L8"
end

@testset "Remotes overrides" begin
    @debug Test.get_testset()
    # We'll set up a couple of overrides with remotes here
    doc = Documenter.Document(
        root = joinpath(mainrepo, "docs"),
        remotes = Dict(
            # Just non-repository directories
            extdirectory => (Remotes.GitHub("AlternateOrg", "ExtRepo.jl"), "12345"),
            # Pointing an unconfigured Git repo to another repo
            subrepo_noremote => Remotes.GitHub("AlternateOrg", "NoRemoteSubdir.jl"),
            # Pointing an a Git repo with a valid origin to a different repo
            subrepo => Remotes.GitHub("AlternateOrg", "AnotherRepo.jl"),
        )
    )
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo"
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = "main") == "https://github.com/TestOrg/TestRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(mainrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(mainrepo, "foo"), 5:8) == "https://github.com/TestOrg/TestRepo.jl/blob/$(mainrepo_commit)/foo#L5-L8"
    # subrepo: now points to a different repo (well, org)
    @test edit_url(doc, joinpath(subrepo, "foo"); rev = nothing) == "https://github.com/AlternateOrg/AnotherRepo.jl/blob/$(subrepo_commit)/foo"
    @test edit_url(doc, joinpath(subrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/AnotherRepo.jl/blob/$(subrepo_commit)/bar/baz/qux"
    # extrepo: we did not touch this
    @test edit_url(doc, joinpath(extrepo, "foo"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/foo"
    @test edit_url(doc, joinpath(extrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/TestOrg/ExtRepo.jl/blob/$(extrepo_commit)/bar/baz/qux"
    # subrepo_noremote: this should point to AlternateOrg/NoRemoteSubdir.jl
    @test edit_url(doc, joinpath(subrepo_noremote, "foo"); rev = nothing) == "https://github.com/AlternateOrg/NoRemoteSubdir.jl/blob/$(subrepo_noremote_commit)/foo"
    @test edit_url(doc, joinpath(subrepo_noremote, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/NoRemoteSubdir.jl/blob/$(subrepo_noremote_commit)/bar/baz/qux"
    # extrepo_noremote: we did not touch this
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "foo"); rev = nothing)
    @test_throws Documenter.MissingRemoteError edit_url(doc, joinpath(extrepo_noremote, "bar", "baz", "qux"); rev = nothing)
    # extdirectory: should point to AlternateOrg/ExtRepo.jl
    @test edit_url(doc, joinpath(extdirectory, "foo"); rev = nothing) == "https://github.com/AlternateOrg/ExtRepo.jl/blob/12345/foo"
    @test edit_url(doc, joinpath(extdirectory, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/ExtRepo.jl/blob/12345/bar/baz/qux"
end

# Trying to set up a remote to a directory that does not have Git repository will throw, because we need to know
# the commit hash.
@quietly @test_throws Exception Documenter.Document(
    root = joinpath(mainrepo, "docs"),
    remotes = Dict(
        extdirectory => Remotes.GitHub("AlternateOrg", "ExtRepo.jl"),
    )
)

@testset "Set repo with remotes" begin
    @debug Test.get_testset()
    # We'll try to override set repo (~ doc.user.remote) with remotes.
    doc = Documenter.Document(
        root = joinpath(mainrepo, "docs"),
        remotes = Dict(
            mainrepo => Remotes.GitHub("AlternateOrg", "AlternateRepo.jl"),
        )
    )
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = nothing) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/$(mainrepo_commit)/foo"
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = "main") == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(mainrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/$(mainrepo_commit)/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(mainrepo, "foo"), 5:8) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/$(mainrepo_commit)/foo#L5-L8"
    @test doc.user.remote == Remotes.GitHub("AlternateOrg", "AlternateRepo.jl")
    # Let's also override the commit
    doc = Documenter.Document(
        root = joinpath(mainrepo, "docs"),
        remotes = Dict(
            mainrepo => (Remotes.GitHub("AlternateOrg", "AlternateRepo.jl"), "12345"),
        )
    )
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = nothing) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/12345/foo"
    @test edit_url(doc, joinpath(mainrepo, "foo"); rev = "main") == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/main/foo"
    @test edit_url(doc, joinpath(mainrepo, "bar", "baz", "qux"); rev = nothing) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/12345/bar/baz/qux"
    @test source_url(doc, RepoLinkTests, joinpath(mainrepo, "foo"), 5:8) == "https://github.com/AlternateOrg/AlternateRepo.jl/blob/12345/foo#L5-L8"
    @test doc.user.remote == Remotes.GitHub("AlternateOrg", "AlternateRepo.jl")
end

# Setting both the `repo` and also overriding the same path in `remotes` should error
@test_throws Exception Documenter.Document(
    root = joinpath(mainrepo, "docs"),
    repo = Remotes.GitHub("AlternateOrg", "ExtRepo.jl"),
    remotes = Dict(
        mainrepo => (Remotes.GitHub("AlternateOrg", "AlternateRepo.jl"), "12345"),
    )
)

rm(tmproot, recursive = true, force = true)

include("repolink_helpers.jl")

@testset "Pkg.add() guesses github tag" begin
    src = convert(
        MarkdownAST.Node,
        md"""
        ```@meta
        CurrentModule = Main.RepoLinkTests.TestHelperModule
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

    src = convert(
        MarkdownAST.Node,
        md"""
        ```@meta
        CurrentModule = Main.RepoLinkTests.TestHelperModule
        ```
        This will result in a 404 because this version isn't tagged
        ```@docs
        RegistryInstances
        ```
        """
    )
    doc, html = render_expand_doc(src)

    # Links to repo
    re = r"<a[^>]+ href=['\"]?https://github.com/GunnarFarneback/RegistryInstances.jl"
    @test occursin(re, string(html))
end

end
