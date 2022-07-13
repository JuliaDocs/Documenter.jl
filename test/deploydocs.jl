isdefined(@__MODULE__, :TestUtilities) || include("TestUtilities.jl")
using Documenter: Documenter, deploydocs
using Documenter.Utilities: git
using Test, ..TestUtilities

struct TestDeployConfig <: Documenter.DeployConfig
    repo_path :: String
    subfolder :: String
end
function Documenter.deploy_folder(c::TestDeployConfig; branch, repo, kwargs...)
    Documenter.DeployDecision(; all_ok = true, subfolder = c.subfolder, branch=branch, repo=repo)
end
Documenter.authentication_method(::TestDeployConfig) = Documenter.HTTPS
Documenter.authenticated_repo_url(c::TestDeployConfig) = c.repo_path

@testset "deploydocs" begin
    mktempdir() do dir
        cd(dir) do
            mkdir("repo")
            run(`$(git()) -C repo init -q --bare`)
            full_repo_path = joinpath(pwd(), "repo")
            # Pseudo makedocs products in build/
            mkdir("build")
            write("build/page.html", "...")
            # Create gh-pages and deploy dev/
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "dev"),
                repo = full_repo_path,
                devbranch = "master",
            )
            # Deploy 1.0.0 tag
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "1.0.0"),
                repo = full_repo_path,
                devbranch = "master",
            )
            # Deploy 1.1.0 tag
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "1.1.0"),
                repo = full_repo_path,
                devbranch = "master",
            )
            # Deploy 2.0.0 tag, but into an archive (so nothing pushed to gh-pages)
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "2.0.0"),
                repo = full_repo_path,
                devbranch = "master",
                archive = joinpath(pwd(), "ghpages.tar.gz"),
            )
            # Check what we have in gh-pages now:
            run(`$(git()) clone -q -b gh-pages $(full_repo_path) worktree`)
            @test isfile(joinpath("worktree", "index.html"))
            @test isfile(joinpath("worktree", "versions.js"))
            for d in ["dev", "v1.0.0", "v1.1.0"]
                @test isfile(joinpath("worktree", d, "page.html"))
                @test isfile(joinpath("worktree", d, "siteinfo.js"))
            end
            if Sys.iswindows() && VERSION < v"1.6.0"
                # lstat apparently doesn't return the correct information on Windows
                # for symlinks, which means islink will be false here, even though these
                # paths actuall are links. Possibly related to:
                #   https://github.com/JuliaLang/julia/pull/39491
                # To make the tests pass, we'll just disable these we'll just test them with
                # ispath instead.
                @test ispath(joinpath("worktree", "v1"))
                @test ispath(joinpath("worktree", "v1.0"))
                @test ispath(joinpath("worktree", "v1.1"))
                @test ispath(joinpath("worktree", "stable"))
            else
                @test islink(joinpath("worktree", "v1"))
                @test islink(joinpath("worktree", "v1.0"))
                @test islink(joinpath("worktree", "v1.1"))
                @test islink(joinpath("worktree", "stable"))
            end
            # And make sure that archived option didn't modify gh-pages
            @test ! ispath(joinpath("worktree", "2.0.0"))
            @test ! ispath(joinpath("worktree", "v2.0"))
            @test ! ispath(joinpath("worktree", "v2"))
            @test isfile("ghpages.tar.gz")
        end
    end
end
