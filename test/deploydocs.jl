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
            # Check what we have in gh-pages now:
            run(`$(git()) clone -q -b gh-pages $(full_repo_path) worktree`)
            @test isfile(joinpath("worktree", "index.html"))
            @test isfile(joinpath("worktree", "versions.js"))
            for d in ["dev", "v1.0.0", "v1.1.0"]
                @test isfile(joinpath("worktree", d, "page.html"))
                @test isfile(joinpath("worktree", d, "siteinfo.js"))
            end
            @test islink(joinpath("worktree", "v1"))
            @test islink(joinpath("worktree", "v1.0"))
            @test islink(joinpath("worktree", "v1.1"))
            @test islink(joinpath("worktree", "stable"))
            # And make sure that archived option didn't modify gh-pages
            @test ! ispath(joinpath("worktree", "2.0.0"))
            @test ! ispath(joinpath("worktree", "v2.0"))
            @test ! ispath(joinpath("worktree", "v2"))
            @test isfile("ghpages.tar.gz")

            #####
            # Repeat same set of tests, this time with a non-empty tag_prefix
            #####

            tag_prefix = "MySubPackage-"
            # Create gh-pages and deploy dev/
            @quietly deploydocs(;
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, tag_prefix *"dev"),
                repo = full_repo_path,
                devbranch = "master",
                tag_prefix,
            )
            # Deploy 1.0.0 tag
            @quietly deploydocs(;
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, tag_prefix * "1.0.0"),
                repo = full_repo_path,
                devbranch = "master",
                tag_prefix,
            )
            # Deploy 1.1.0 tag
            @quietly deploydocs(;
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, tag_prefix * "1.1.0"),
                repo = full_repo_path,
                devbranch = "master",
                tag_prefix,
            )
            # Deploy 2.0.0 tag, but into an archive (so nothing pushed to gh-pages)
            @quietly deploydocs(;
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, tag_prefix * "2.0.0"),
                repo = full_repo_path,
                devbranch = "master",
                archive = joinpath(pwd(), tag_prefix * "ghpages.tar.gz"),
                tag_prefix,
            )
            # Check what we have in gh-pages now:
            cd("worktree") do
                run(`$(git()) pull`)
            end

            for d in tag_prefix .* ["dev", "v1.0.0", "v1.1.0"]
                @test isfile(joinpath("worktree", d, "page.html"))
                @test isfile(joinpath("worktree", d, "siteinfo.js"))
            end
            @test islink(joinpath("worktree", tag_prefix * "v1"))
            @test islink(joinpath("worktree", tag_prefix * "v1.0"))
            @test islink(joinpath("worktree", tag_prefix * "v1.1"))
            @test islink(joinpath("worktree", tag_prefix * "stable"))
            # And make sure that archived option didn't modify gh-pages
            @test ! ispath(joinpath("worktree", tag_prefix * "2.0.0"))
            @test ! ispath(joinpath("worktree", tag_prefix * "v2.0"))
            @test ! ispath(joinpath("worktree", tag_prefix * "v2"))
            @test isfile(tag_prefix * "ghpages.tar.gz")

            # TODO: test contents to ensure both tag_prefix and non are available
            # (Spoiler: they currently aren't, b/c that hasn't been implemented....)
            # @test isfile(joinpath("worktree", "index.html"))
            # @test isfile(joinpath("worktree", "versions.js"))
        end
    end
end
