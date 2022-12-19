using Documenter: Documenter, deploydocs, git
using Test
include("TestUtilities.jl"); using Main.TestUtilities

struct TestDeployConfig <: Documenter.DeployConfig
    repo_path :: String
    subfolder :: String
end
function Documenter.deploy_folder(c::TestDeployConfig; branch, repo, kwargs...)
    Documenter.DeployDecision(; all_ok = true, subfolder = c.subfolder, branch, repo)
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
            # Deploy 3.0.0 tag with a tag_prefix---which does not change deployment behavior
            @quietly deploydocs(;
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "3.0"),
                repo = full_repo_path,
                devbranch = "master",
                tag_prefix = "MySubPackage-",
            )
            # Check what we have in gh-pages now:
            run(`$(git()) clone -q -b gh-pages $(full_repo_path) worktree`)
            @test isfile(joinpath("worktree", "index.html"))
            @test isfile(joinpath("worktree", "versions.js"))
            for d in ["dev", "v1.0.0", "v1.1.0", "v3.0.0"]
                @test isfile(joinpath("worktree", d, "page.html"))
                @test isfile(joinpath("worktree", d, "siteinfo.js"))
            end
            @test islink(joinpath("worktree", "v1"))
            @test islink(joinpath("worktree", "v1.0"))
            @test islink(joinpath("worktree", "v1.1"))
            @test islink(joinpath("worktree", "stable"))
            # And make sure that archived option didn't modify gh-pages
            @test !ispath(joinpath("worktree", "2.0.0"))
            @test !ispath(joinpath("worktree", "v2.0"))
            @test !ispath(joinpath("worktree", "v2"))
            @test isfile("ghpages.tar.gz")
            @test islink(joinpath("worktree", "v3"))
            @test islink(joinpath("worktree", "v3.0"))
            @test islink(joinpath("worktree", "v3.0.0"))
           
            # key_prefix does not affect/is not present in worktree directories
            @test issetequal([".git", "1.0.0", "1.1.0", "3.0", "dev", "index.html", 
                              "stable", "v1", "v1.0", "v1.0.0", "v1.1", "v1.1.0", 
                              "v3", "v3.0", "v3.0.0", "versions.js"], readdir("worktree"))
        end
    end
end
