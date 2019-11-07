"""
    DeployConfig

Abstract type which new deployment configs should be subtypes of.
"""
abstract type DeployConfig end

"""
    Documenter.documenter_key(cfg::DeployConfig)

Return the Base64-encoded SSH private key for the repository.
Defaults to reading the `DOCUMENTER_KEY` environment variable.

This method must be supported by configs that push with SSH, see
[`Documenter.authentication_method`](@ref).
"""
function documenter_key(::DeployConfig)
    return ENV["DOCUMENTER_KEY"]
end

"""
    Documenter.git_tag(cfg::DeployConfig)

Return the git tag of the build. If the build is not for a tag, return `nothing`.

This function determines the subfolder where the built docs are deployed.
Either a folder named as the tag (e.g. `vX.Y.Z`) or `devurl`
(see [`deploydocs`](@ref)) for non-tag builds.
"""
git_tag(::DeployConfig) = nothing

"""
    Documenter.should_deploy(cfg::DeployConfig; repo=repo, devbranch=devbranch)

Return `true` if the current build should deploy, and `false` otherwise.
This function is called with the `repo` and `devbranch` arguments from
[`deploydocs`](@ref).
"""
should_deploy(::DeployConfig; kwargs...) = false
should_deploy(::Nothing; kwargs...) = false # when auto-detection fails

@enum AuthenticationMethod SSH HTTPS

"""
    Documenter.authentication_method(::DeployConfig)

Return enum instance `SSH` or `HTTPS` depending on push method to be used.

Configs returning `SSH` should support [`Documenter.documenter_key`](@ref).
Configs returning `HTTPS` should support [`Documenter.authenticated_repo_url`](@ref).
"""
authentication_method(::DeployConfig) = SSH

"""
    Documenter.authenticated_repo_url(cfg::DeployConfig)

Return an authenticated URL to the upstream repository.

This method must be supported by configs that push with HTTPS, see
[`Documenter.authentication_method`](@ref).
"""
function authenticated_repo_url end

#############
# Travis CI #
#############

"""
    Travis <: DeployConfig

Default implementation of `DeployConfig`.

The following environment variables influences the build
when using the `Travis` configuration:

 - `DOCUMENTER_KEY`: must contain the Base64-encoded SSH private key for the repository.
   This variable should be set in the Travis settings for the repository. Make sure this
   variable is marked **NOT** to be displayed in the build log.

 - `TRAVIS_PULL_REQUEST`: must be set to `false`.
   This avoids deployment on pull request builds.

 - `TRAVIS_REPO_SLUG`: must match the value of the `repo` keyword to [`deploydocs`](@ref).

 - `TRAVIS_EVENT_TYPE`: may not be set to `cron`. This avoids re-deployment of existing
   docs on builds that were triggered by a Travis cron job.

 - `TRAVIS_BRANCH`: unless `TRAVIS_TAG` is non-empty, this must have the same value as
   the `devbranch` keyword to [`deploydocs`](@ref). This makes sure that only the
   development branch (commonly, the `master` branch) will deploy the "dev" documentation
   (deployed into a directory specified by the `devurl` keyword to [`deploydocs`](@ref)).

 - `TRAVIS_TAG`: if set, a tagged version deployment is performed instead; the value
   must be a valid version number (i.e. match `Base.VERSION_REGEX`). The documentation for
   a package version tag gets deployed to a directory named after the version number in
   `TRAVIS_TAG` instead.

The `TRAVIS_*` variables are set automatically on Travis. More information on how Travis
sets the `TRAVIS_*` variables can be found in the
[Travis documentation](https://docs.travis-ci.com/user/environment-variables/#default-environment-variables).
"""
struct Travis <: DeployConfig
    travis_branch::String
    travis_pull_request::String
    travis_repo_slug::String
    travis_tag::String
    travis_event_type::String
end
function Travis()
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_event_type   = get(ENV, "TRAVIS_EVENT_TYPE",    "")
    return Travis(travis_branch, travis_pull_request,
        travis_repo_slug, travis_tag, travis_event_type)
end

# Check criteria for deployment
function should_deploy(cfg::Travis; repo, devbranch, kwargs...)
    ## The deploydocs' repo should match TRAVIS_REPO_SLUG
    repo_ok = occursin(cfg.travis_repo_slug, repo)
    ## Do not deploy for PRs
    pr_ok = cfg.travis_pull_request == "false"
    ## If a tag exist it should be a valid VersionNumber
    tag_ok = isempty(cfg.travis_tag) || occursin(Base.VERSION_REGEX, cfg.travis_tag)
    ## If no tag exists deploydocs' devbranch should match TRAVIS_BRANCH
    branch_ok = !isempty(cfg.travis_tag) || cfg.travis_branch == devbranch
    ## DOCUMENTER_KEY should exist (just check here and extract the value later)
    key_ok = haskey(ENV, "DOCUMENTER_KEY")
    ## Cron jobs should not deploy
    type_ok = cfg.travis_event_type != "cron"
    all_ok = repo_ok && pr_ok && tag_ok && branch_ok && key_ok && type_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with Travis:
    - $(marker(repo_ok)) ENV["TRAVIS_REPO_SLUG"]="$(cfg.travis_repo_slug)" occurs in repo="$(repo)"
    - $(marker(pr_ok)) ENV["TRAVIS_PULL_REQUEST"]="$(cfg.travis_pull_request)" is "false"
    - $(marker(tag_ok)) ENV["TRAVIS_TAG"]="$(cfg.travis_tag)" is (i) empty or (ii) a valid VersionNumber
    - $(marker(branch_ok)) ENV["TRAVIS_BRANCH"]="$(cfg.travis_branch)" matches devbranch="$(devbranch)" (if tag is empty)
    - $(marker(key_ok)) ENV["DOCUMENTER_KEY"] exists
    - $(marker(type_ok)) ENV["TRAVIS_EVENT_TYPE"]="$(cfg.travis_event_type)" is not "cron"
    Deploying: $(marker(all_ok))
    """
    return all_ok
end

# Obtain git tag for the build
function git_tag(cfg::Travis)
    isempty(cfg.travis_tag) ? nothing : cfg.travis_tag
end


##################
# GitHub Actions #
##################

"""
    GitHubActions <: DeployConfig

Implementation of `DeployConfig` for deploying from GitHub Actions.

The following environment variables influences the build
when using the `GitHubActions` configuration:

 - `DOCUMENTER_KEY`: must contain the Base64-encoded SSH private key for the repository.
   This variable should be set in the GitHub Actions configuration file using a repository
   secret, see the documentation for
   [secret environment variables](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables).

 - `GITHUB_EVENT_NAME`: must be set to `push`.
   This avoids deployment on pull request builds.

 - `GITHUB_REPOSITORY`: must match the value of the `repo` keyword to [`deploydocs`](@ref).

 - `GITHUB_REF`: must match the `devbranch` keyword to [`deploydocs`](@ref), alternatively
   correspond to a git tag.

The `GITHUB_*` variables are set automatically on GitHub Actions, see the
[documentation](https://help.github.com/en/articles/virtual-environments-for-github-actions#default-environment-variables).
"""
struct GitHubActions <: DeployConfig
    github_repository::String
    github_event_name::String
    github_ref::String
end
function GitHubActions()
    github_repository = get(ENV, "GITHUB_REPOSITORY", "") # "JuliaDocs/Documenter.jl"
    github_event_name = get(ENV, "GITHUB_EVENT_NAME", "") # "push", "pull_request" or "cron" (?)
    github_ref        = get(ENV, "GITHUB_REF",        "") # "refs/heads/$(branchname)" for branch, "refs/tags/$(tagname)" for tags
    return GitHubActions(github_repository, github_event_name, github_ref)
end

# Check criteria for deployment
function should_deploy(cfg::GitHubActions; repo, devbranch, kwargs...)
    ## The deploydocs' repo should match GITHUB_REPOSITORY
    repo_ok = occursin(cfg.github_repository, repo)
    ## Do not deploy for PRs
    pr_ok = cfg.github_event_name == "push"
    ## If a tag exist it should be a valid VersionNumber
    m = match(r"^refs/tags/(.*)$", cfg.github_ref)
    tag_ok = m === nothing ? false : occursin(Base.VERSION_REGEX, String(m.captures[1]))
    ## If no tag exists deploydocs' devbranch should match the current branch
    m = match(r"^refs/heads/(.*)$", cfg.github_ref)
    branch_ok = m === nothing ? false : String(m.captures[1]) == devbranch
    ## GITHUB_ACTOR should exist (just check here and extract the value later)
    actor_ok = haskey(ENV, "GITHUB_ACTOR")
    ## GITHUB_TOKEN should exist (just check here and extract the value later)
    token_ok = haskey(ENV, "GITHUB_TOKEN")
    all_ok = repo_ok && pr_ok && (tag_ok || branch_ok) && actor_ok && token_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with GitHub Actions:
    - $(marker(repo_ok)) ENV["GITHUB_REPOSITORY"]="$(cfg.github_repository)" occurs in repo="$(repo)"
    - $(marker(pr_ok)) ENV["GITHUB_EVENT_NAME"]="$(cfg.github_event_name)" is "push"
    - $(marker(tag_ok || branch_ok)) ENV["GITHUB_REF"]="$(cfg.github_ref)" corresponds to a tag or matches devbranch="$(devbranch)"
    - $(marker(actor_ok)) ENV["GITHUB_ACTOR"] exists
    - $(marker(token_ok)) ENV["GITHUB_TOKEN"] exists
    Deploying: $(marker(all_ok))
    """
    return all_ok
end

authentication_method(::GitHubActions) = HTTPS
function authenticated_repo_url(cfg::GitHubActions)
    return "https://$(ENV["GITHUB_ACTOR"]):$(ENV["GITHUB_TOKEN"])@github.com/$(cfg.github_repository).git"
end

# Obtain git tag for the build
function git_tag(cfg::GitHubActions)
    m = match(r"^refs/tags/(.*)$", cfg.github_ref)
    return m === nothing ? nothing : String(m.captures[1])
end


##################
# Auto-detection #
##################
function auto_detect_deploy_system()
    if haskey(ENV, "TRAVIS_REPO_SLUG")
        return Travis()
    elseif haskey(ENV, "GITHUB_REPOSITORY")
        return GitHubActions()
    else
        return nothing
    end
end
