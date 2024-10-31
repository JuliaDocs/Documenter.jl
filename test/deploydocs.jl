using Documenter: Documenter, deploydocs, git
using DocInventories: DocInventories, Inventory
using Test
include("TestUtilities.jl"); using Main.TestUtilities

struct TestDeployConfig <: Documenter.DeployConfig
    repo_path::String
    subfolder::String
end
function Documenter.deploy_folder(c::TestDeployConfig; branch, repo, kwargs...)
    return Documenter.DeployDecision(; all_ok = true, subfolder = c.subfolder, branch, repo)
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
            inventory = Inventory(project = "test", version = "")
            objects_inv = joinpath("build", "objects.inv")
            DocInventories.save(objects_inv, inventory)
            # Create gh-pages and deploy dev/
            @quietly deploydocs(
                root = pwd(),
                cname = "www.example.com",
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
            # (note that the inventory still declares 1.0.0 as the version, so
            # this implicitly tests that `deploydocs` overwrites it with the
            # correct version)
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "1.1.0"),
                repo = full_repo_path,
                devbranch = "master",
            )
            # Deploy 2.0.0 tag, but into an archive (so nothing pushed to gh-pages)
            DocInventories.save(objects_inv, Inventory(project = "test", version = "2.0.0"))
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "2.0.0"),
                repo = full_repo_path,
                devbranch = "master",
                archive = joinpath(pwd(), "ghpages.tar.gz"),
            )
            # Deploy 3.0.0 tag with a tag_prefix---which does not change deployment behavior
            DocInventories.save(objects_inv, Inventory(project = "test", version = "3.0.0"))
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
            @test isfile(joinpath("worktree", "CNAME"))
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
            inv_v11 = Inventory(joinpath("worktree", "v1.1", "objects.inv"))
            @test inv_v11.version == "1.1.0"
            inv_v30 = Inventory(joinpath("worktree", "v3.0", "objects.inv"))
            @test inv_v30.version == "3.0.0"
            inv_stable = Inventory(joinpath("worktree", "stable", "objects.inv"))
            @test inv_stable.version == "3.0.0"
            inv_dev = Inventory(joinpath("worktree", "dev", "objects.inv"))
            @test inv_dev.version == ""

            # key_prefix does not affect/is not present in worktree directories
            @test issetequal(
                [
                    ".git", "1.0.0", "1.1.0", "3.0", "CNAME", "dev", "index.html",
                    "stable", "v1", "v1.0", "v1.0.0", "v1.1", "v1.1.0",
                    "v3", "v3.0", "v3.0.0", "versions.js",
                ], readdir("worktree")
            )
        end
    end
end

@testset "deploydocs for monorepo" begin
    mktempdir() do dir
        cd(dir) do
            mkdir("repo")
            run(`$(git()) -C repo init -q --bare`)
            full_repo_path = joinpath(pwd(), "repo")
            # Pseudo makedocs products: top level repo...
            top_level_doc_dir = mkpath(joinpath("docs", "build"))
            write(joinpath(top_level_doc_dir, "page.html"), "...")

            # ...and subpackage.
            subpackage_doc_dir = joinpath("PackageA.jl", "docs", "build")
            mkpath(joinpath("PackageA.jl", "docs", "build"))
            write(joinpath(subpackage_doc_dir, "page.html"), "...")

            # Use different versions for each set of docs to make it easier to see
            # where the version has been deplyed.
            # Deploy 1.0.0 tag - top level repo
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "1.0.0"),
                repo = full_repo_path,
                devbranch = "master",
            )
            # Deploy 2.0.0 tag - subpackage
            # Note: setting the `tag_prefix here is not actually necessary or used
            # BECAUSE we're using a TestDeployConfig, but we're setting it here
            # anyway so that this example can be used to model true implementation.
            @quietly deploydocs(
                root = pwd(),
                deploy_config = TestDeployConfig(full_repo_path, "2.0.0"),
                repo = full_repo_path,
                devbranch = "master",
                dirname = "PackageA.jl",
                tag_prefix = "PackageA-",
            )

            # Check what we have in worktree:
            run(`$(git()) clone -q -b gh-pages $(full_repo_path) worktree`)

            @test isdir("worktree/1.0.0") # top level
            @test !isdir("worktree/2.0.0") # top level
            @test isdir("worktree/PackageA.jl/2.0.0") # subpackage
            @test !isdir("worktree/PackageA.jl/1.0.0") # subpackage

            # Check what we have in gh-pages:
            @test isfile(joinpath("worktree", "index.html"))
            @test isfile(joinpath("worktree", "versions.js"))
            @test isfile(joinpath("worktree", "PackageA.jl", "index.html"))
            @test isfile(joinpath("worktree", "PackageA.jl", "versions.js"))

            # ...and check that (because only one release per package) the versions
            # are identical except for the (intentional) version number
            top_versions = readlines(joinpath("worktree", "versions.js"))
            subpackage_versions = readlines(joinpath("worktree", "PackageA.jl", "versions.js"))
            for (i, (t_line, s_line)) in enumerate(zip(top_versions, subpackage_versions))
                if i in [3, 5]
                    @test contains(s_line, "2.0")
                    @test isequal(t_line, replace(s_line, "2.0" => "1.0"))
                else
                    @test isequal(t_line, s_line)
                end
            end
        end
    end
end
