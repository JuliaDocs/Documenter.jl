import JSON

"""
    DeployConfig

Abstract type which new deployment configs should be subtypes of.
"""
abstract type DeployConfig end

"""
    DeployDecision(; kwargs...)

Struct containing information about the decision to deploy or not deploy.

# Arguments

- `all_ok::Bool` - Should documentation be deployed?
- `branch::String` - The branch to which documentation should be pushed
- `is_preview::Bool` - Is this documentation build a pull request?
- `repo::String` - The repo to which documentation should be pushed
- `subfolder::String` - The subfolder to which documentation should be pushed
"""
Base.@kwdef struct DeployDecision
    all_ok::Bool
    branch::String = ""
    is_preview::Bool = false
    repo::String = ""
    subfolder::String = ""
end

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
    Documenter.documenter_key_previews(cfg::DeployConfig)

Return the Base64-encoded SSH private key for the repository.
Uses the `DOCUMENTER_KEY_PREVIEWS` environment variable if it is defined,
otherwise uses the `DOCUMENTER_KEY` environment variable.

This method must be supported by configs that push with SSH, see
[`Documenter.authentication_method`](@ref).
"""
function documenter_key_previews(cfg::DeployConfig)
    return get(ENV, "DOCUMENTER_KEY_PREVIEWS", documenter_key(cfg))
end

"""
    Documenter.deploy_folder(cfg::DeployConfig; repo, devbranch, push_preview, devurl, kwargs...)

Return a `DeployDecision`.
This function is called with the `repo`, `devbranch`, `push_preview` and `devurl`
arguments from [`deploydocs`](@ref).

!!! note
    Implementations of this functions should accept trailing `kwargs...` for
    compatibility with future Documenter releases which may pass additional
    keyword arguments.
"""
function deploy_folder(cfg::DeployConfig; kwargs...)
    @warn "Documenter.deploy_folder(::$(typeof(cfg)); kwargs...) not implemented. Skipping deployment."
    return DeployDecision(; all_ok = false)
end
function deploy_folder(::Nothing; kwargs...)
    @warn "Documenter could not auto-detect the building environment Skipping deployment."
    return DeployDecision(; all_ok = false)
end

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

post_status(cfg::Union{DeployConfig,Nothing}; kwargs...) = nothing
post_status(; kwargs...) = post_status(auto_detect_deploy_system(); kwargs...)

marker(x) = x ? "✔" : "✘"

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
function deploy_folder(cfg::Travis;
                       repo,
                       repo_previews = repo,
                       branch = "gh-pages",
                       branch_previews = branch,
                       devbranch,
                       push_preview,
                       devurl,
                       kwargs...)
    io = IOBuffer()
    all_ok = true
    ## Determine build type; release, devbranch or preview
    if cfg.travis_pull_request != "false"
        build_type = :preview
    elseif !isempty(cfg.travis_tag)
        build_type = :release
    else
        build_type = :devbranch
    end
    println(io, "Deployment criteria for deploying $(build_type) build from Travis:")
    ## The deploydocs' repo should match TRAVIS_REPO_SLUG
    repo_ok = occursin(cfg.travis_repo_slug, repo)
    all_ok &= repo_ok
    println(io, "- $(marker(repo_ok)) ENV[\"TRAVIS_REPO_SLUG\"]=\"$(cfg.travis_repo_slug)\" occurs in repo=\"$(repo)\"")
    if build_type === :release
        ## Do not deploy for PRs
        pr_ok = cfg.travis_pull_request == "false"
        println(io, "- $(marker(pr_ok)) ENV[\"TRAVIS_PULL_REQUEST\"]=\"$(cfg.travis_pull_request)\" is \"false\"")
        all_ok &= pr_ok
        tag_nobuild = version_tag_strip_build(cfg.travis_tag)
        ## If a tag exist it should be a valid VersionNumber
        tag_ok = tag_nobuild !== nothing
        all_ok &= tag_ok
        println(io, "- $(marker(tag_ok)) ENV[\"TRAVIS_TAG\"] contains a valid VersionNumber")
        deploy_branch = branch
        deploy_repo = repo
        is_preview = false
        ## Deploy to folder according to the tag
        subfolder = tag_nobuild
    elseif build_type === :devbranch
        ## Do not deploy for PRs
        pr_ok = cfg.travis_pull_request == "false"
        println(io, "- $(marker(pr_ok)) ENV[\"TRAVIS_PULL_REQUEST\"]=\"$(cfg.travis_pull_request)\" is \"false\"")
        all_ok &= pr_ok
        ## deploydocs' devbranch should match TRAVIS_BRANCH
        branch_ok = !isempty(cfg.travis_tag) || cfg.travis_branch == devbranch
        all_ok &= branch_ok
        println(io, "- $(marker(branch_ok)) ENV[\"TRAVIS_BRANCH\"] matches devbranch=\"$(devbranch)\"")
        deploy_branch = branch
        deploy_repo = repo
        is_preview = false
        ## Deploy to deploydocs devurl kwarg
        subfolder = devurl
    else # build_type === :preview
        pr_number = tryparse(Int, cfg.travis_pull_request)
        pr_ok = pr_number !== nothing
        all_ok &= pr_ok
        println(io, "- $(marker(pr_ok)) ENV[\"TRAVIS_PULL_REQUEST\"]=\"$(cfg.travis_pull_request)\" is a number")
        btype_ok = push_preview
        all_ok &= btype_ok
        println(io, "- $(marker(btype_ok)) `push_preview` keyword argument to deploydocs is `true`")
        deploy_branch = branch_previews
        deploy_repo = repo_previews
        is_preview = true
        ## deploy to previews/PR
        subfolder = "previews/PR$(something(pr_number, 0))"
    end
    ## DOCUMENTER_KEY should exist (just check here and extract the value later)
    key_ok = haskey(ENV, "DOCUMENTER_KEY")
    all_ok &= key_ok
    println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists")
    ## Cron jobs should not deploy
    type_ok = cfg.travis_event_type != "cron"
    all_ok &= type_ok
    println(io, "- $(marker(type_ok)) ENV[\"TRAVIS_EVENT_TYPE\"]=\"$(cfg.travis_event_type)\" is not \"cron\"")
    print(io, "Deploying: $(marker(all_ok))")
    @info String(take!(io))
    if all_ok
        return DeployDecision(; all_ok = true,
                                branch = deploy_branch,
                                is_preview = is_preview,
                                repo = deploy_repo,
                                subfolder = subfolder)
    else
        return DeployDecision(; all_ok = false)
    end
end


##################
# GitHub Actions #
##################

"""
    GitHubActions <: DeployConfig

Implementation of `DeployConfig` for deploying from GitHub Actions.

The following environment variables influences the build
when using the `GitHubActions` configuration:

 - `GITHUB_EVENT_NAME`: must be set to `push`.
   This avoids deployment on pull request builds.

 - `GITHUB_REPOSITORY`: must match the value of the `repo` keyword to [`deploydocs`](@ref).

 - `GITHUB_REF`: must match the `devbranch` keyword to [`deploydocs`](@ref), alternatively
   correspond to a git tag.

 - `GITHUB_TOKEN` or `DOCUMENTER_KEY`: used for authentication with GitHub,
   see the manual section for [GitHub Actions](@ref) for more information.

The `GITHUB_*` variables are set automatically on GitHub Actions, see the
[documentation](https://help.github.com/en/actions/configuring-and-managing-workflows/using-environment-variables#default-environment-variables).
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
function deploy_folder(cfg::GitHubActions;
                       repo,
                       repo_previews = repo,
                       branch = "gh-pages",
                       branch_previews = branch,
                       devbranch,
                       push_preview,
                       devurl,
                       kwargs...)
    io = IOBuffer()
    all_ok = true
    ## Determine build type
    if cfg.github_event_name == "pull_request"
        build_type = :preview
    elseif occursin(r"^refs\/tags\/(.*)$", cfg.github_ref)
        build_type = :release
    else
        build_type = :devbranch
    end
    println(io, "Deployment criteria for deploying $(build_type) build from GitHub Actions:")
    ## The deploydocs' repo should match GITHUB_REPOSITORY
    repo_ok = occursin(cfg.github_repository, repo)
    all_ok &= repo_ok
    println(io, "- $(marker(repo_ok)) ENV[\"GITHUB_REPOSITORY\"]=\"$(cfg.github_repository)\" occurs in repo=\"$(repo)\"")
    if build_type === :release
        ## Do not deploy for PRs
        event_ok = cfg.github_event_name == "push"
        all_ok &= event_ok
        println(io, "- $(marker(event_ok)) ENV[\"GITHUB_EVENT_NAME\"]=\"$(cfg.github_event_name)\" is \"push\"")
        ## If a tag exist it should be a valid VersionNumber
        m = match(r"^refs\/tags\/(.*)$", cfg.github_ref)
        tag_nobuild = version_tag_strip_build(m.captures[1])
        tag_ok = tag_nobuild !== nothing
        all_ok &= tag_ok
        println(io, "- $(marker(tag_ok)) ENV[\"GITHUB_REF\"]=\"$(cfg.github_ref)\" contains a valid VersionNumber")
        deploy_branch = branch
        deploy_repo = repo
        is_preview = false
        ## Deploy to folder according to the tag
        subfolder = m === nothing ? nothing : tag_nobuild
    elseif build_type === :devbranch
        ## Do not deploy for PRs
        event_ok = cfg.github_event_name == "push"
        all_ok &= event_ok
        println(io, "- $(marker(event_ok)) ENV[\"GITHUB_EVENT_NAME\"]=\"$(cfg.github_event_name)\" is \"push\"")
        ## deploydocs' devbranch should match the current branch
        m = match(r"^refs\/heads\/(.*)$", cfg.github_ref)
        branch_ok = m === nothing ? false : String(m.captures[1]) == devbranch
        all_ok &= branch_ok
        println(io, "- $(marker(branch_ok)) ENV[\"GITHUB_REF\"] matches devbranch=\"$(devbranch)\"")
        deploy_branch = branch
        deploy_repo = repo
        is_preview = false
        ## Deploy to deploydocs devurl kwarg
        subfolder = devurl
    else # build_type === :preview
        m = match(r"refs\/pull\/(\d+)\/merge", cfg.github_ref)
        pr_number = tryparse(Int, m === nothing ? "" : m.captures[1])
        pr_ok = pr_number !== nothing
        all_ok &= pr_ok
        println(io, "- $(marker(pr_ok)) ENV[\"GITHUB_REF\"] corresponds to a PR number")
        btype_ok = push_preview
        all_ok &= btype_ok
        println(io, "- $(marker(btype_ok)) `push_preview` keyword argument to deploydocs is `true`")
        deploy_branch = branch_previews
        deploy_repo = repo_previews
        is_preview = true
        ## deploydocs to previews/PR
        subfolder = "previews/PR$(something(pr_number, 0))"
    end
    ## GITHUB_ACTOR should exist (just check here and extract the value later)
    actor_ok = haskey(ENV, "GITHUB_ACTOR")
    all_ok &= actor_ok
    println(io, "- $(marker(actor_ok)) ENV[\"GITHUB_ACTOR\"] exists")
    ## GITHUB_TOKEN or DOCUMENTER_KEY should exist (just check here and extract the value later)
    token_ok = haskey(ENV, "GITHUB_TOKEN")
    key_ok = haskey(ENV, "DOCUMENTER_KEY")
    auth_ok = token_ok | key_ok
    all_ok &= auth_ok
    if key_ok
        println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists exists")
    elseif token_ok
        println(io, "- $(marker(token_ok)) ENV[\"GITHUB_TOKEN\"] exists exists")
    else
        println(io, "- $(marker(auth_ok)) ENV[\"DOCUMENTER_KEY\"] or ENV[\"GITHUB_TOKEN\"]  exists")
    end
    print(io, "Deploying: $(marker(all_ok))")
    @info String(take!(io))
    if all_ok
        return DeployDecision(; all_ok = true,
                                branch = deploy_branch,
                                is_preview = is_preview,
                                repo = deploy_repo,
                                subfolder = subfolder)
    else
        return DeployDecision(; all_ok = false)
    end
end

function authentication_method(::GitHubActions)
    if haskey(ENV, "DOCUMENTER_KEY")
        return SSH
    else
        @warn "Currently the GitHub Pages build is not triggered when " *
              "using `GITHUB_TOKEN` for authentication. See issue #1177 " *
              "(https://github.com/JuliaDocs/Documenter.jl/issues/1177) " *
              "for more information."
        return HTTPS
    end
end
function authenticated_repo_url(cfg::GitHubActions)
    return "https://$(ENV["GITHUB_ACTOR"]):$(ENV["GITHUB_TOKEN"])@github.com/$(cfg.github_repository).git"
end

function version_tag_strip_build(tag)
    m = match(Base.VERSION_REGEX, tag)
    m === nothing && return nothing
    s0 = startswith(tag, 'v') ? "v" : ""
    s1 = m[1] # major
    s2 = m[2] === nothing ? "" : ".$(m[2])" # minor
    s3 = m[3] === nothing ? "" : ".$(m[3])" # patch
    s4 = m[5] === nothing ? "" : m[5] # pre-release (starting with -)
    # m[7] is the build, which we want to discard
    "$s0$s1$s2$s3$s4"
end

function post_status(::GitHubActions; type, repo::String, subfolder=nothing, kwargs...)
    try # make this non-fatal and silent
        # If we got this far it usually means everything is in
        # order so no need to check everything again.
        # In particular this is only called after we have
        # determined to deploy.
        sha = nothing
        if get(ENV, "GITHUB_EVENT_NAME", nothing) == "pull_request"
            event_path = get(ENV, "GITHUB_EVENT_PATH", nothing)
            event_path === nothing && return
            event = JSON.parsefile(event_path)
            if haskey(event, "pull_request") &&
               haskey(event["pull_request"], "head") &&
               haskey(event["pull_request"]["head"], "sha")
               sha = event["pull_request"]["head"]["sha"]
            end
        elseif get(ENV, "GITHUB_EVENT_NAME", nothing) == "push"
            sha = get(ENV, "GITHUB_SHA", nothing)
        end
        sha === nothing && return
        return post_github_status(type, repo, sha, subfolder)
    catch
        @debug "Failed to post status"
    end
end

function post_github_status(type::S, deploydocs_repo::S, sha::S, subfolder=nothing) where S <: String
    try
        Sys.which("curl") === nothing && return
        ## Extract owner and repository name
        m = match(r"^github.com\/(.+?)\/(.+?)(.git)?$", deploydocs_repo)
        m === nothing && return
        owner = String(m.captures[1])
        repo = String(m.captures[2])

        ## Need an access token for this
        auth = get(ENV, "GITHUB_TOKEN", nothing)
        auth === nothing && return
        # construct the curl call
        cmd = `curl -sX POST`
        push!(cmd.exec, "-H", "Authorization: token $(auth)")
        push!(cmd.exec, "-H", "User-Agent: Documenter.jl")
        push!(cmd.exec, "-H", "Content-Type: application/json")
        json = Dict{String,Any}("context" => "documenter/deploy", "state"=>type)
        if type == "pending"
            json["description"] = "Documentation build in progress"
        elseif type == "success"
            json["description"] = "Documentation build succeeded"
            if subfolder !== nothing
                json["target_url"] = "https://$(owner).github.io/$(repo)/$(subfolder)/"
            end
        elseif type == "error"
            json["description"] = "Documentation build errored"
        elseif type == "failure"
            json["description"] = "Documentation build failed"
        else
            error("unsupported type: $type")
        end
        push!(cmd.exec, "-d", sprint(JSON.print, json))
        push!(cmd.exec, "https://api.github.com/repos/$(owner)/$(repo)/statuses/$(sha)")
        # Run the command (silently)
        io = IOBuffer()
        res = run(pipeline(cmd; stdout=io, stderr=devnull))
        @debug "Response of curl POST request" response=String(take!(io))
    catch
        @debug "Failed to post status"
    end
    return nothing
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
