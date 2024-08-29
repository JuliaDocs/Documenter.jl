using Logging

@testset "Travis CI deploy configuration" begin
    with_logger(NullLogger()) do
        # Regular tag build
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "v1.2.3",
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Regular tag build with tag prefix
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "MySubPackage-v1.2.3",
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", tag_prefix = "MySubPackage-",
                devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Broken tag build
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "not-a-version",
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test !d.all_ok
        end
        # Regular/broken devbranch build
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => nothing,
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "hello-world"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "not-master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Regular pull request build
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "42",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "something",
            "TRAVIS_TAG" => nothing,
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "previews/PR42"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Missing/broken environment variables
        withenv(
            "TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "v1.2.3",
            "TRAVIS_EVENT_TYPE" => nothing,
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.Travis()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
        end
    end
end

@testset "GitHub Actions deploy configuration" begin
    with_logger(NullLogger()) do
        # Regular tag build with GITHUB_TOKEN
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.authentication_method(cfg) === Documenter.HTTPS
            @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
        end
        # Regular tag build with SSH deploy key (SSH key prioritized)
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.authentication_method(cfg) === Documenter.SSH
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Regular tag build with GITHUB_TOKEN and with tag prefix
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/MySubPackage-v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true,
                tag_prefix = "MySubPackage-"
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.authentication_method(cfg) === Documenter.HTTPS
            @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
        end
        # Broken tag build
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/not-a-version",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test !d.all_ok
        end
        # Regular devbranch build with GITHUB_TOKEN
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/heads/master",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "hello-world"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "not-master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
            @test Documenter.authentication_method(cfg) === Documenter.HTTPS
            @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
        end
        # Regular devbranch build with SSH deploy key (SSH key prioritized)
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/heads/master",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "hello-world"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "not-master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
            @test Documenter.authentication_method(cfg) === Documenter.SSH
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end

        # These tests requires GITHUB_TOKEN to be set (and valid) in order to verify the origin
        # of the PR. Only runs on CI.
        if get(ENV, "GITHUB_ACTIONS", nothing) == "true" && haskey(ENV, "GITHUB_TOKEN")
            # Regular pull request build with GITHUB_TOKEN
            withenv(
                "GITHUB_EVENT_NAME" => "pull_request",
                "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
                "GITHUB_REF" => "refs/pull/1962/merge",
                "GITHUB_ACTOR" => "github-actions",
                "DOCUMENTER_KEY" => nothing,
            ) do
                cfg = Documenter.GitHubActions()
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "master", devurl = "hello-world", push_preview = true
                )
                @test d.all_ok
                @test d.subfolder == "previews/PR1962"
                @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
                @test d.branch == "gh-pages"
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "not-master", devurl = "hello-world", push_preview = false
                )
                @test !d.all_ok
                @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                @test Documenter.authenticated_repo_url(cfg) == "https://github-actions:$(ENV["GITHUB_TOKEN"])@github.com/JuliaDocs/Documenter.jl.git"
            end
            # Regular pull request build with GITHUB_TOKEN, PR from a fork
            withenv(
                "GITHUB_EVENT_NAME" => "pull_request",
                "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
                "GITHUB_REF" => "refs/pull/1967/merge",
                "GITHUB_ACTOR" => "github-actions",
                "DOCUMENTER_KEY" => nothing,
            ) do
                cfg = Documenter.GitHubActions()
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "master", devurl = "hello-world", push_preview = true
                )
                @test !d.all_ok
            end
            # Regular pull request build with SSH deploy key (SSH key prioritized)
            withenv(
                "GITHUB_EVENT_NAME" => "pull_request",
                "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
                "GITHUB_REF" => "refs/pull/1962/merge",
                "GITHUB_ACTOR" => "github-actions",
                "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
            ) do
                cfg = Documenter.GitHubActions()
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "master", devurl = "hello-world", push_preview = true
                )
                @test d.all_ok
                @test d.subfolder == "previews/PR1962"
                @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
                @test d.branch == "gh-pages"
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "not-master", devurl = "hello-world", push_preview = false
                )
                @test !d.all_ok
                @test Documenter.authentication_method(cfg) === Documenter.SSH
                @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            end
            # Regular pull request build with SSH deploy key (SSH key prioritized), but push previews to a different repo and different branch
            withenv(
                "GITHUB_EVENT_NAME" => "pull_request",
                "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
                "GITHUB_REF" => "refs/pull/1962/merge",
                "GITHUB_ACTOR" => "github-actions",
                "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
            ) do
                cfg = Documenter.GitHubActions()
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "master", devurl = "hello-world", push_preview = true,
                    repo_previews = "github.com/JuliaDocs/Documenter-previews.jl.git",
                    branch_previews = "gh-pages-previews"
                )
                @test d.all_ok
                @test d.subfolder == "previews/PR1962"
                @test d.repo == "github.com/JuliaDocs/Documenter-previews.jl.git"
                @test d.branch == "gh-pages-previews"
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "not-master", devurl = "hello-world", push_preview = false,
                    repo_previews = "",
                    branch_previews = ""
                )
                @test !d.all_ok
                @test Documenter.authentication_method(cfg) === Documenter.SSH
                @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            end
            # Regular pull request build with SSH deploy key (SSH key prioritized), but push previews to a different repo and different branch; use a different deploy key for previews
            withenv(
                "GITHUB_EVENT_NAME" => "pull_request",
                "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
                "GITHUB_REF" => "refs/pull/1962/merge",
                "GITHUB_ACTOR" => "github-actions",
                "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
                "DOCUMENTER_KEY_PREVIEWS" => "SGVsbG8sIHdvcmxkLw==",
            ) do
                cfg = Documenter.GitHubActions()
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "master", devurl = "hello-world", push_preview = true,
                    repo_previews = "github.com/JuliaDocs/Documenter-previews.jl.git",
                    branch_previews = "gh-pages-previews"
                )
                @test d.all_ok
                @test d.subfolder == "previews/PR1962"
                @test d.repo == "github.com/JuliaDocs/Documenter-previews.jl.git"
                @test d.branch == "gh-pages-previews"
                d = Documenter.deploy_folder(
                    cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                    devbranch = "not-master", devurl = "hello-world", push_preview = false,
                    repo_previews = "",
                    branch_previews = ""
                )
                @test !d.all_ok
                @test Documenter.authentication_method(cfg) === Documenter.SSH
                @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
                @test Documenter.documenter_key_previews(cfg) === "SGVsbG8sIHdvcmxkLw=="
            end
        end
        # Missing environment variables
        withenv(
            "GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => nothing,
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
        end
    end
end

@testset "GitLab CI deploy configuration" begin
    with_logger(NullLogger()) do
        # Regular tag build
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "master",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => "v1.2.3",
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Regular tag build with tag_prefix
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "master",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => "MySubPackage-v1.2.3",
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true,
                tag_prefix = "MySubPackage-"
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Broken tag build
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "master",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => "not-a-version",
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test !d.all_ok
        end
        # Regular/broken devbranch build
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "master",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => nothing,
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "hello-world"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "not-master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Regular pull request build
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "something",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "42",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => nothing,
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "previews/PR42"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Missing/broken environment variables
        withenv(
            "GITLAB_CI" => "true",
            "CI_COMMIT_BRANCH" => "master",
            "CI_EXTERNAL_PULL_REQUEST_IID" => "",
            "CI_PROJECT_PATH_SLUG" => "juliadocs-documenter-jl",
            "CI_COMMIT_TAG" => "v1.2.3",
            "CI_PIPELINE_SOURCE" => "push",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitLab()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
        end
        # Build on `schedule` jobs
        withenv(
            "GITHUB_EVENT_NAME" => "schedule",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.GitHubActions()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.authentication_method(cfg) === Documenter.HTTPS
            @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
        end
    end
end

@testset "Buildkite CI deploy configuration" begin
    with_logger(NullLogger()) do
        # Regular tag build
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "master",
            "BUILDKITE_PULL_REQUEST" => "false",
            "BUILDKITE_TAG" => "v1.2.3",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Regular tag build with tag_prefix
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "master",
            "BUILDKITE_PULL_REQUEST" => "false",
            "BUILDKITE_TAG" => "MySubPackage-v1.2.3",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true,
                tag_prefix = "MySubPackage-"
            )
            @test d.all_ok
            @test d.subfolder == "v1.2.3"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
            @test Documenter.authentication_method(cfg) === Documenter.SSH
        end
        # Broken tag build
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "master",
            "BUILDKITE_PULL_REQUEST" => "false",
            "BUILDKITE_TAG" => "not-a-version",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "dev", push_preview = true
            )
            @test !d.all_ok
        end
        # Regular/broken devbranch build
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "master",
            "BUILDKITE_PULL_REQUEST" => "false",
            "BUILDKITE_TAG" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "hello-world"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "not-master", devurl = "hello-world", push_preview = true
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Regular pull request build
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "something",
            "BUILDKITE_PULL_REQUEST" => "42",
            "BUILDKITE_TAG" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = true
            )
            @test d.all_ok
            @test d.subfolder == "previews/PR42"
            @test d.repo == "github.com/JuliaDocs/Documenter.jl.git"
            @test d.branch == "gh-pages"
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
            @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        end
        # Missing/broken environment variables
        withenv(
            "BUILDKITE" => "true",
            "BUILDKITE_BRANCH" => "master",
            "BUILDKITE_PULL_REQUEST" => "false",
            "BUILDKITE_TAG" => "v1.2.3",
            "DOCUMENTER_KEY" => nothing,
        ) do
            cfg = Documenter.Buildkite()
            d = Documenter.deploy_folder(
                cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
                devbranch = "master", devurl = "hello-world", push_preview = false
            )
            @test !d.all_ok
        end
    end
end

@testset "Woodpecker CI deploy configuration" begin
    with_logger(NullLogger()) do
        @testset "Woodpecker 0.15.x" begin
            with_logger(NullLogger()) do
                # Regular tag build with PROJECT_ACCESS_TOKEN
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular tag build with PROJECT_ACCESS_TOKEN and with tag prefix
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/MySubPackage-v1.2.3",
                    "CI_COMMIT_TAG" => "MySubPackage-v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true,
                        tag_prefix = "MySubPackage-"
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Broken tag build
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/not-a-version",
                    "CI_COMMIT_TAG" => "not-a-version",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Regular devbranch build
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/heads/master",
                    "CI_COMMIT_TAG" => nothing,
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "hello-world"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "not-master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular pull request build
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "pull_request",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_BUILD_EVENT" => "pull_request",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "previews/PR42"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = false
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Not a pull request
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI_BUILD_EVENT" => "push",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_BUILD_EVENT" => "push",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Missing environment variables
                withenv(
                    "CI_SYSTEM_VERSION" => "0.15.0",
                    "CI" => "woodpecker",
                    "CI_REPO_LINK" => "https://github.com/JuliaDocs/Documenter.jl",
                    "CI_BUILD_EVENT" => "pull_request",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "PROJECT_ACCESS_TOKEN" => nothing,
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
            end
        end
        @testset "Woodpecker 1.0.0" begin
            with_logger(NullLogger()) do
                # Regular tag build with PROJECT_ACCESS_TOKEN
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular tag build with PROJECT_ACCESS_TOKEN and with tag prefix
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/MySubPackage-v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "MySubPackage-v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true,
                        tag_prefix = "MySubPackage-"
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Broken tag build
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/not-a-version",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "not-a-version",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Regular devbranch build
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/heads/master",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => nothing,
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "hello-world"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "not-master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular pull request build
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "previews/PR42"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = false
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Not a pull request
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_PIPELINE_EVENT" => "push",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Missing environment variables
                withenv(
                    "CI_SYSTEM_VERSION" => "1.0.0",
                    "CI" => "woodpecker",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "PROJECT_ACCESS_TOKEN" => nothing,
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
            end
        end
        @testset "Woodpecker 2.0.0" begin
            with_logger(NullLogger()) do
                # Regular tag build with PROJECT_ACCESS_TOKEN
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular tag build with PROJECT_ACCESS_TOKEN and with tag prefix
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/MySubPackage-v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "MySubPackage-v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true,
                        tag_prefix = "MySubPackage-"
                    )

                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Broken tag build
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/not-a-version",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "not-a-version",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Regular devbranch build
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/heads/master",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => nothing,
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "hello-world"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "not-master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Regular pull request build
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "previews/PR42"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = false
                    )
                    @test !d.all_ok
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Not a pull request
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI_COMMIT_PULL_REQUEST" => "42",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_PIPELINE_EVENT" => "push",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
                # Missing environment variables
                withenv(
                    "CI_SYSTEM_VERSION" => "2.0.0",
                    "CI" => "woodpecker",
                    "CI_PIPELINE_EVENT" => "pull_request",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/pull/42/merge",
                    "CI_FORGE_URL" => "https://github.com",
                    "PROJECT_ACCESS_TOKEN" => nothing,
                ) do
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "hello-world", push_preview = true
                    )
                    @test !d.all_ok
                end
            end
        end
        @testset "Woodpecker CI No CI_SYSTEM_VERSION environmental variable" begin
            with_logger(NullLogger()) do
                # Regular tag build with PROJECT_ACCESS_TOKEN but no CI_SYSTEM_VERSION. It should throw.
                withenv(
                    "CI_SYSTEM_VERSION" => nothing,
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    @test_throws KeyError cfg = Documenter.Woodpecker()
                end
            end
        end
        @testset "Woodpecker CI Unreleased Versions" begin
            with_logger(NullLogger()) do
                # NOTE Unreleased versions starts with `next-<commit hash>`
                # Regular tag build with PROJECT_ACCESS_TOKEN with next unreleased version.
                withenv(
                    "CI_SYSTEM_VERSION" => "next-woodpeckerversion",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    @test_warn r"(You are currently using an unreleased version of Woodpecker)*" Documenter.Woodpecker()
                    cfg = Documenter.Woodpecker()
                    d = Documenter.deploy_folder(
                        cfg; repo = "JuliaDocs/Documenter.jl",
                        devbranch = "master", devurl = "dev", push_preview = true
                    )
                    @test d.all_ok
                    @test d.subfolder == "v1.2.3"
                    @test d.repo == "JuliaDocs/Documenter.jl"
                    @test d.branch == "pages"
                    @test Documenter.authentication_method(cfg) === Documenter.HTTPS
                    @test Documenter.authenticated_repo_url(cfg) === "https://SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
                end
                # Incorrect `next` version
                withenv(
                    "CI_SYSTEM_VERSION" => "notnext-indeed",
                    "CI_PIPELINE_EVENT" => "push",
                    "CI" => "woodpecker",
                    "CI_REPO" => "JuliaDocs/Documenter.jl",
                    "CI_COMMIT_REF" => "refs/tags/v1.2.3",
                    "CI_FORGE_URL" => "https://github.com",
                    "CI_COMMIT_TAG" => "v1.2.3",
                    "PROJECT_ACCESS_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
                ) do
                    @test_throws ArgumentError cfg = Documenter.Woodpecker()
                end
            end
        end
    end
end

struct CustomConfig <: Documenter.DeployConfig end
Documenter.deploy_folder(::CustomConfig; kwargs...) = Documenter.DeployDecision(; all_ok = true, subfolder = "v1.2.3")
struct BrokenConfig <: Documenter.DeployConfig end

@testset "Custom configuration" begin
    with_logger(NullLogger()) do
        cfg = CustomConfig()
        d = Documenter.deploy_folder(
            cfg; repo = "github.com/JuliaDocs/Documenter.jl.git",
            devbranch = "master", devurl = "dev", push_preview = true
        )
        @test d.all_ok
        @test d.subfolder == "v1.2.3"
        cfg = BrokenConfig()
        @test (@test_logs (:warn, r"Documenter\.deploy_folder\(::BrokenConfig; kwargs\.\.\.\) not implemented") Documenter.deploy_folder(cfg)) == Documenter.DeployDecision(; all_ok = false)
        @test (@test_logs (:warn, r"Documenter could not auto-detect") Documenter.deploy_folder(nothing)) == Documenter.DeployDecision(; all_ok = false)
    end
end

@testset "Autodetection of deploy system" begin
    withenv(
        "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
        "GITHUB_REPOSITORY" => nothing,
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.Travis
    end
    withenv(
        "TRAVIS_REPO_SLUG" => nothing,
        "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.GitHubActions
    end
    withenv(
        "TRAVIS_REPO_SLUG" => nothing,
        "GITHUB_REPOSITORY" => nothing,
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg === nothing
    end

    # Woodpecker requires a CI_SYSTEM_VERSION env var
    withenv(
        "CI" => "woodpecker",
        "CI_SYSTEM_VERSION" => "1.0.0",
        "GITHUB_REPOSITORY" => nothing
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.Woodpecker
    end
    withenv(
        "CI" => "woodpecker",
        "CI_SYSTEM_VERSION" => "0.15.0",
        "GITHUB_REPOSITORY" => nothing
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.Woodpecker
    end
    withenv(
        "CI" => "woodpecker",
        "GITHUB_REPOSITORY" => nothing
    ) do
        @test_throws KeyError  cfg = Documenter.auto_detect_deploy_system()
    end
    # Drone compatibility ends post-1.0.0
    withenv(
        "CI" => "drone",
        "CI_SYSTEM_VERSION" => "0.15.0",
        "GITHUB_REPOSITORY" => nothing
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.Woodpecker
    end
    withenv(
        "CI" => "drone",
        "GITHUB_REPOSITORY" => nothing
    ) do
        @test_throws KeyError cfg = Documenter.auto_detect_deploy_system()
    end
    withenv(
        "CI" => nothing,
        "GITHUB_REPOSITORY" => nothing
    ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg === nothing
    end
end
##
@testset "Remote repository paths" begin
    uhu = Documenter.user_host_upstream("github.com/JuliaDocs/Documenter.jl.git")
    @test uhu == ("git", "github.com", "git@github.com:JuliaDocs/Documenter.jl.git")

    uhu = Documenter.user_host_upstream("github.com:JuliaDocs/Documenter.jl.git")
    @test uhu == ("git", "github.com", "git@github.com:JuliaDocs/Documenter.jl.git")

    uhu = Documenter.user_host_upstream("gitlab.com/JuliaDocs/Documenter.jl")
    @test uhu == ("git", "gitlab.com", "git@gitlab.com:JuliaDocs/Documenter.jl")

    uhu = Documenter.user_host_upstream("user@page.com:path/to/repo")
    @test uhu == ("user", "page.com", "user@page.com:path/to/repo")

    uhu = Documenter.user_host_upstream("user@page.com/path/to/repo")
    @test uhu == ("user", "page.com", "user@page.com:path/to/repo")

    uhu = Documenter.user_host_upstream("user@subdom.long-page.com:/path/to/repo")
    @test uhu == ("user", "subdom.long-page.com", "user@subdom.long-page.com:path/to/repo")

    @test_throws ErrorException Documenter.user_host_upstream("https://github.com/JuliaDocs/Documenter.jl.git")
    @test_throws ErrorException Documenter.user_host_upstream("user@subdom.long-page.com")
end

@testset "version_tag_strip_build" begin
    using Documenter: version_tag_strip_build
    @test version_tag_strip_build("v1.2.3") == "v1.2.3"
    @test version_tag_strip_build("v1.2.3+build") == "v1.2.3"
    @test version_tag_strip_build("v1.2.3+1") == "v1.2.3"
    @test version_tag_strip_build("v1.2.3-DEV") == "v1.2.3-DEV"
    @test version_tag_strip_build("v1.2.3-DEV+build") == "v1.2.3-DEV"
    @test version_tag_strip_build("v1.2") == "v1.2"
    @test version_tag_strip_build("v1.2+build-build") == "v1.2"
    @test version_tag_strip_build("v1.2-1+build-build") == "v1.2-1"
    @test version_tag_strip_build("v0") == "v0"
    @test version_tag_strip_build("v0+build-build") == "v0"
    @test version_tag_strip_build("v0-A+build-build") == "v0-A"
    # In case the tag does not have v, no v in the output
    @test version_tag_strip_build("1.2") == "1.2"
    @test version_tag_strip_build("1.2.3-DEV+build") == "1.2.3-DEV"
    # If it's not a valid version number
    @test version_tag_strip_build("") === nothing
    @test version_tag_strip_build("+A") === nothing
    @test version_tag_strip_build("X.Y.Z") === nothing
    @test version_tag_strip_build("1#2") === nothing
    @test version_tag_strip_build(".1") === nothing

    # ...and now when there's a non-empty tag_prefix:
    tag_prefix = "TagPrefix-"
    @test version_tag_strip_build("v1.2.3"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-v1.2.3"; tag_prefix) == "v1.2.3"
    @test version_tag_strip_build("TagPrefixTagPrefix-v1.2.3"; tag_prefix) === nothing
    @test version_tag_strip_build("v1.2.3-TagPrefix-"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-1.2"; tag_prefix) == "1.2"
    @test version_tag_strip_build("TagPrefix-1.2.3-DEV+build"; tag_prefix) == "1.2.3-DEV"
    @test version_tag_strip_build("TagPrefix-"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-+A"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-X.Y.Z"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-1#2"; tag_prefix) === nothing
    @test version_tag_strip_build("TagPrefix-.1"; tag_prefix) === nothing
end

@testset "verify_github_pull_repository" begin
    if Sys.which("curl") === nothing
        @warn "'curl' binary not found, skipping related tests."
    else
        r = Documenter.run_and_capture(`curl --help`)
        @test haskey(r, :stdout)
        @test haskey(r, :stderr)
        @test r.stdout isa String
        @test length(r.stdout) > 0
    end
end
