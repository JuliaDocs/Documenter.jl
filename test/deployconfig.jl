using Logging

@testset "Travis CI deploy configuration" begin; with_logger(NullLogger()) do
    # Regular tag build
    withenv("TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "v1.2.3",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.Travis()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="dev", push_preview=true) == "v1.2.3"
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
        @test Documenter.authentication_method(cfg) === Documenter.SSH
    end
    # Broken tag build
    withenv("TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "not-a-version",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.Travis()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="dev", push_preview=true) === nothing
    end
    # Regular/broken devbranch build
    withenv("TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.Travis()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "hello-world"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="not-master", devurl="hello-world", push_preview=true) === nothing
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
    end
    # Regular pull request build
    withenv("TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "42",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "something",
            "TRAVIS_TAG" => nothing,
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.Travis()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "previews/PR42"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=false) === nothing
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
    end
    # Missing/broken environment variables
    withenv("TRAVIS_CI" => "true",
            "TRAVIS_PULL_REQUEST" => "false",
            "TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "TRAVIS_BRANCH" => "master",
            "TRAVIS_TAG" => "v1.2.3",
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.Travis()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=false) === nothing
    end
end end

@testset "GitHub Actions deploy configuration" begin; with_logger(NullLogger()) do
    # Regular tag build with GITHUB_TOKEN
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="dev", push_preview=true) == "v1.2.3"
        @test Documenter.authentication_method(cfg) === Documenter.HTTPS
        @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
    end
    # Regular tag build with SSH deploy key (SSH key prioritized)
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="dev", push_preview=true) == "v1.2.3"
        @test Documenter.authentication_method(cfg) === Documenter.SSH
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
    end
    # Broken tag build
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/not-a-version",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="dev", push_preview=true) === nothing
    end
    # Regular devbranch build with GITHUB_TOKEN
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/heads/master",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "hello-world"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="not-master", devurl="hello-world", push_preview=true) === nothing
        @test Documenter.authentication_method(cfg) === Documenter.HTTPS
        @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
    end
    # Regular devbranch build with SSH deploy key (SSH key prioritized)
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/heads/master",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "hello-world"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="not-master", devurl="hello-world", push_preview=true) === nothing
        @test Documenter.authentication_method(cfg) === Documenter.SSH
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
    end
    # Regular pull request build with GITHUB_TOKEN
    withenv("GITHUB_EVENT_NAME" => "pull_request",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/pull/42/merge",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "previews/PR42"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="not-master", devurl="hello-world", push_preview=false) === nothing
        @test Documenter.authentication_method(cfg) === Documenter.HTTPS
        @test Documenter.authenticated_repo_url(cfg) === "https://github-actions:SGVsbG8sIHdvcmxkLg==@github.com/JuliaDocs/Documenter.jl.git"
    end
    # Regular pull request build with SSH deploy key (SSH key prioritized)
    withenv("GITHUB_EVENT_NAME" => "pull_request",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/pull/42/merge",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => "SGVsbG8sIHdvcmxkLg==",
            "DOCUMENTER_KEY" => "SGVsbG8sIHdvcmxkLg==",
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) == "previews/PR42"
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="not-master", devurl="hello-world", push_preview=false) === nothing
        @test Documenter.authentication_method(cfg) === Documenter.SSH
        @test Documenter.documenter_key(cfg) === "SGVsbG8sIHdvcmxkLg=="
    end
    # Missing environment variables
    withenv("GITHUB_EVENT_NAME" => "push",
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
            "GITHUB_REF" => "refs/tags/v1.2.3",
            "GITHUB_ACTOR" => "github-actions",
            "GITHUB_TOKEN" => nothing,
            "DOCUMENTER_KEY" => nothing,
        ) do
        cfg = Documenter.GitHubActions()
        @test Documenter.deploy_folder(cfg; repo="github.com/JuliaDocs/Documenter.jl.git",
                  devbranch="master", devurl="hello-world", push_preview=true) === nothing
    end
end end

@testset "Autodetection of deploy system" begin
    withenv("TRAVIS_REPO_SLUG" => "JuliaDocs/Documenter.jl",
            "GITHUB_REPOSITORY" => nothing,
        ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.Travis
    end
    withenv("TRAVIS_REPO_SLUG" => nothing,
            "GITHUB_REPOSITORY" => "JuliaDocs/Documenter.jl",
        ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg isa Documenter.GitHubActions
    end
    withenv("TRAVIS_REPO_SLUG" => nothing,
            "GITHUB_REPOSITORY" => nothing,
        ) do
        cfg = Documenter.auto_detect_deploy_system()
        @test cfg === nothing
    end
end
