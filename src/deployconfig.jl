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

marker(x) = x ? "✔" : "✘"

env_nonempty(key) = !isempty(get(ENV, key, ""))

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
    key_ok = env_nonempty("DOCUMENTER_KEY")
    all_ok &= key_ok
    println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists and is non-empty")
    ## Cron jobs should not deploy
    type_ok = cfg.travis_event_type != "cron"
    all_ok &= type_ok
    println(io, "- $(marker(type_ok)) ENV[\"TRAVIS_EVENT_TYPE\"]=\"$(cfg.travis_event_type)\" is not \"cron\"")
    print(io, "Deploying: $(marker(all_ok))")
    @info String(take!(io))
    if build_type === :devbranch && !branch_ok && devbranch == "master" && cfg.travis_branch == "main"
        @warn """
        Possible deploydocs() misconfiguration: main vs master
        Documenter's configured primary development branch (`devbranch`) is "master", but the
        current branch (\$TRAVIS_BRANCH) is "main". This can happen because Documenter uses
        GitHub's old default primary branch name as the default value for `devbranch`.

        If your primary development branch is 'main', you must explicitly pass `devbranch = "main"`
        to deploydocs.

        See #1443 for more discussion: https://github.com/JuliaDocs/Documenter.jl/issues/1443
        """
    end
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

 - `GITHUB_EVENT_NAME`: must be set to `push`, `workflow_dispatch`, or `schedule`.
   This avoids deployment on pull request builds.

 - `GITHUB_REPOSITORY`: must match the value of the `repo` keyword to [`deploydocs`](@ref).

 - `GITHUB_REF`: must match the `devbranch` keyword to [`deploydocs`](@ref), alternatively
   correspond to a git tag.

 - `GITHUB_TOKEN` or `DOCUMENTER_KEY`: used for authentication with GitHub,
   see the manual section for [GitHub Actions](@ref) for more information.

The `GITHUB_*` variables are set automatically on GitHub Actions, see the
[documentation](https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables).
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
        event_ok = in(cfg.github_event_name, ["push", "workflow_dispatch", "schedule"])
        all_ok &= event_ok
        println(io, "- $(marker(event_ok)) ENV[\"GITHUB_EVENT_NAME\"]=\"$(cfg.github_event_name)\" is \"push\", \"workflow_dispatch\" or \"schedule\"")
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
        event_ok = in(cfg.github_event_name, ["push", "workflow_dispatch", "schedule"])
        all_ok &= event_ok
        println(io, "- $(marker(event_ok)) ENV[\"GITHUB_EVENT_NAME\"]=\"$(cfg.github_event_name)\" is \"push\", \"workflow_dispatch\" or \"schedule\"")
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
        if pr_ok
            pr_origin_matches_repo = verify_github_pull_repository(cfg.github_repository, pr_number)
            all_ok &= pr_origin_matches_repo
            println(io, "- $(marker(pr_origin_matches_repo)) PR originates from the same repository")
        end
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
    actor_ok = env_nonempty("GITHUB_ACTOR")
    all_ok &= actor_ok
    println(io, "- $(marker(actor_ok)) ENV[\"GITHUB_ACTOR\"] exists and is non-empty")
    ## GITHUB_TOKEN or DOCUMENTER_KEY should exist (just check here and extract the value later)
    token_ok = env_nonempty("GITHUB_TOKEN")
    key_ok = env_nonempty("DOCUMENTER_KEY")
    auth_ok = token_ok | key_ok
    all_ok &= auth_ok
    if key_ok
        println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists and is non-empty")
    elseif token_ok
        println(io, "- $(marker(token_ok)) ENV[\"GITHUB_TOKEN\"] exists and is non-empty")
    else
        println(io, "- $(marker(auth_ok)) ENV[\"DOCUMENTER_KEY\"] or ENV[\"GITHUB_TOKEN\"] exists and is non-empty")
    end
    print(io, "Deploying: $(marker(all_ok))")
    @info String(take!(io))
    if build_type === :devbranch && !branch_ok && devbranch == "master" && cfg.github_ref == "refs/heads/main"
        @warn """
        Possible deploydocs() misconfiguration: main vs master
        Documenter's configured primary development branch (`devbranch`) is "master", but the
        current branch (from \$GITHUB_REF) is "main". This can happen because Documenter uses
        GitHub's old default primary branch name as the default value for `devbranch`.

        If your primary development branch is 'main', you must explicitly pass `devbranch = "main"`
        to deploydocs.

        See #1443 for more discussion: https://github.com/JuliaDocs/Documenter.jl/issues/1443
        """
    end
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

authentication_method(::GitHubActions) = env_nonempty("DOCUMENTER_KEY") ? SSH : HTTPS
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
            target_url = "https://$(owner).github.io/$(repo)/"
            if subfolder !== nothing
                target_url *= "$(subfolder)/"
            end
            json["target_url"] = target_url
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

function verify_github_pull_repository(repo, prnr)
    try
        github_token = get(ENV, "GITHUB_TOKEN", nothing)
        github_token === nothing && error("GITHUB_TOKEN missing")
        # Construct the curl call
        cmd = `curl -s`
        push!(cmd.exec, "-S", "GET")
        push!(cmd.exec, "-H", "Authorization: token $(github_token)")
        push!(cmd.exec, "-H", "User-Agent: Documenter.jl")
        push!(cmd.exec, "-H", "Content-Type: application/json")
        push!(cmd.exec, "--fail")
        push!(cmd.exec, "https://api.github.com/repos/$(repo)/pulls/$(prnr)")
        # Run the command (silently)
        response = run_and_capture(cmd)
        response = JSON.parse(response.stdout)
        pr_head_repo = response["head"]["repo"]["full_name"]
        @debug "pr_head_repo = '$pr_head_repo' vs repo = '$repo'"
        return (pr_head_repo == repo)
    catch e
        @warn "Unable to verify if PR comes from destination repository -- assuming it does."
        @debug "Running CURL led to an exception:" exception = (e, catch_backtrace())
        return true
    end
end

function run_and_capture(cmd)
    stdout, stderr = if VERSION < v"1.1"
        # On Julia 1.0, we can not pass IOBuffer() to pipeline(), so we're using the workaround
        # described here:
        # https://discourse.julialang.org/t/how-to-capture-stdout-and-stderr-in-1-1/20712/2
        stdout_pipe, stderr_pipe = Pipe(), Pipe()
        run(pipeline(cmd; stdout = stdout_pipe, stderr = stderr_pipe))
        close(stdout_pipe.in); close(stderr_pipe.in)
        stdout, stderr = read(stdout_pipe, String), read(stderr_pipe, String)
    else
        stdout_buffer, stderr_buffer = IOBuffer(), IOBuffer()
        run(pipeline(cmd; stdout = stdout_buffer, stderr = stderr_buffer))
        stdout, stderr = String(take!(stdout_buffer)), String(take!(stderr_buffer))
    end
    return (; stdout = stdout, stderr = stderr)
end

##########
# GitLab #
##########

"""
    GitLab <: DeployConfig

GitLab implementation of `DeployConfig`.

The following environment variables influence the build when using the
`GitLab` configuration:

 - `DOCUMENTER_KEY`: must contain the Base64-encoded SSH private key for the
   repository. This variable should be set in the GitLab settings. Make sure this
   variable is marked **NOT** to be displayed in the build log.

 - `CI_COMMIT_BRANCH`: the name of the commit branch.

 - `CI_EXTERNAL_PULL_REQUEST_IID`: Pull Request ID from GitHub if the pipelines
   are for external pull requests.

 - `CI_PROJECT_PATH_SLUG`: The namespace with project name. All letters
   lowercased and non-alphanumeric characters replaced with `-`.

 - `CI_COMMIT_TAG`: The commit tag name. Present only when building tags.

 - `CI_PIPELINE_SOURCE`: Indicates how the pipeline was triggered.

The `CI_*` variables are set automatically on GitLab. More information on how GitLab
sets the `CI_*` variables can be found in the
[GitLab documentation](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html).
"""
struct GitLab <: DeployConfig
    commit_branch::String
    pull_request_iid::String
    repo_slug::String
    commit_tag::String
    pipeline_source::String
end

function GitLab()
    commit_branch = get(ENV, "CI_COMMIT_BRANCH", "")
    pull_request_iid = get(ENV, "CI_EXTERNAL_PULL_REQUEST_IID", "")
    repo_slug = get(ENV, "CI_PROJECT_PATH_SLUG", "")
    commit_tag = get(ENV, "CI_COMMIT_TAG", "")
    pipeline_source = get(ENV, "CI_PIPELINE_SOURCE", "")
    GitLab(commit_branch, pull_request_iid, repo_slug, commit_tag, pipeline_source)
end

function deploy_folder(
    cfg::GitLab;
    repo,
    repo_previews = repo,
    devbranch,
    push_preview,
    devurl,
    branch = "gh-pages",
    branch_previews = branch,
    kwargs...,
)
    io = IOBuffer()
    all_ok = true

    println(io, "\nGitLab config:")
    println(io, "  Commit branch: \"", cfg.commit_branch, "\"")
    println(io, "  Pull request IID: \"", cfg.pull_request_iid, "\"")
    println(io, "  Repo slug: \"", cfg.repo_slug, "\"")
    println(io, "  Commit tag: \"", cfg.commit_tag, "\"")
    println(io, "  Pipeline source: \"", cfg.pipeline_source, "\"")

    build_type = if cfg.pull_request_iid != ""
        :preview
    elseif cfg.commit_tag != ""
        :release
    else
        :devbranch
    end

    println(io, "Detected build type: ", build_type)

    if build_type == :release
        tag_nobuild = version_tag_strip_build(cfg.commit_tag)
        ## If a tag exist it should be a valid VersionNumber
        tag_ok = tag_nobuild !== nothing

        println(
            io,
            "- $(marker(tag_ok)) ENV[\"CI_COMMIT_TAG\"] contains a valid VersionNumber",
        )
        all_ok &= tag_ok

        is_preview = false
        subfolder = tag_nobuild
        deploy_branch = branch
        deploy_repo = repo
    elseif build_type == :preview
        pr_number = tryparse(Int, cfg.pull_request_iid)
        pr_ok = pr_number !== nothing
        all_ok &= pr_ok
        println(
            io,
            "- $(marker(pr_ok)) ENV[\"CI_EXTERNAL_PULL_REQUEST_IID\"]=\"$(cfg.pull_request_iid)\" is a number",
        )
        btype_ok = push_preview
        all_ok &= btype_ok
        is_preview = true
        println(
            io,
            "- $(marker(btype_ok)) `push_preview` keyword argument to deploydocs is `true`",
        )
        ## deploy to previews/PR
        subfolder = "previews/PR$(something(pr_number, 0))"
        deploy_branch = branch_previews
        deploy_repo = repo_previews
    else
        branch_ok = !isempty(cfg.commit_tag) || cfg.commit_branch == devbranch
        all_ok &= branch_ok
        println(
            io,
            "- $(marker(branch_ok)) ENV[\"CI_COMMIT_BRANCH\"] matches devbranch=\"$(devbranch)\"",
        )
        is_preview = false
        subfolder = devurl
        deploy_branch = branch
        deploy_repo = repo
    end

    key_ok = env_nonempty("DOCUMENTER_KEY")
    println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists and is non-empty")
    all_ok &= key_ok

    print(io, "Deploying to folder $(repr(subfolder)): $(marker(all_ok))")
    @info String(take!(io))

    if all_ok
        return DeployDecision(;
            all_ok = true,
            branch = deploy_branch,
            repo = deploy_repo,
            subfolder = subfolder,
            is_preview = is_preview,
        )
    else
        return DeployDecision(; all_ok = false)
    end
end

authentication_method(::GitLab) = Documenter.SSH

documenter_key(::GitLab) = ENV["DOCUMENTER_KEY"]

#############
# Buildkite #
#############

"""
    Buildkite <: DeployConfig

Buildkite implementation of `DeployConfig`.

The following environment variables influence the build when using the
`Buildkite` configuration:

 - `DOCUMENTER_KEY`: must contain the Base64-encoded SSH private key for the
   repository. This variable should be somehow set in the CI environment, e.g.,
   provisioned by an agent environment plugin.

 - `BUILDKITE_BRANCH`: the name of the commit branch.

 - `BUILDKITE_PULL_REQUEST`: Pull Request ID from GitHub if the pipelines
   are for external pull requests.

 - `BUILDKITE_TAG`: The commit tag name. Present only when building tags.

The `BUILDKITE_*` variables are set automatically on GitLab. More information on how
Buildkite sets the `BUILDKITE_*` variables can be found in the
[Buildkite documentation](https://buildkite.com/docs/pipelines/environment-variables).
"""
struct Buildkite <: DeployConfig
    commit_branch::String
    pull_request::String
    commit_tag::String
end

function Buildkite()
    commit_branch = get(ENV, "BUILDKITE_BRANCH", "")
    pull_request = get(ENV, "BUILDKITE_PULL_REQUEST", "false")
    commit_tag = get(ENV, "BUILDKITE_TAG", "")
    Buildkite(commit_branch, pull_request, commit_tag)
end

function deploy_folder(
    cfg::Buildkite;
    repo,
    repo_previews = repo,
    devbranch,
    push_preview,
    devurl,
    branch = "gh-pages",
    branch_previews = branch,
    kwargs...,
)
    io = IOBuffer()
    all_ok = true

    println(io, "\nBuildkite config:")
    println(io, "  Commit branch: \"", cfg.commit_branch, "\"")
    println(io, "  Pull request: \"", cfg.pull_request, "\"")
    println(io, "  Commit tag: \"", cfg.commit_tag, "\"")

    build_type = if cfg.pull_request != "false"
        :preview
    elseif cfg.commit_tag != ""
        :release
    else
        :devbranch
    end

    println(io, "Detected build type: ", build_type)

    if build_type == :release
        tag_nobuild = version_tag_strip_build(cfg.commit_tag)
        ## If a tag exist it should be a valid VersionNumber
        tag_ok = tag_nobuild !== nothing

        println(
            io,
            "- $(marker(tag_ok)) ENV[\"BUILDKITE_TAG\"] contains a valid VersionNumber",
        )
        all_ok &= tag_ok

        is_preview = false
        subfolder = tag_nobuild
        deploy_branch = branch
        deploy_repo = repo
    elseif build_type == :preview
        pr_number = tryparse(Int, cfg.pull_request)
        pr_ok = pr_number !== nothing
        all_ok &= pr_ok
        println(
            io,
            "- $(marker(pr_ok)) ENV[\"BUILDKITE_PULL_REQUEST\"]=\"$(cfg.pull_request)\" is a number",
        )
        btype_ok = push_preview
        all_ok &= btype_ok
        is_preview = true
        println(
            io,
            "- $(marker(btype_ok)) `push_preview` keyword argument to deploydocs is `true`",
        )
        ## deploy to previews/PR
        subfolder = "previews/PR$(something(pr_number, 0))"
        deploy_branch = branch_previews
        deploy_repo = repo_previews
    else
        branch_ok = !isempty(cfg.commit_tag) || cfg.commit_branch == devbranch
        all_ok &= branch_ok
        println(
            io,
            "- $(marker(branch_ok)) ENV[\"BUILDKITE_BRANCH\"] matches devbranch=\"$(devbranch)\"",
        )
        is_preview = false
        subfolder = devurl
        deploy_branch = branch
        deploy_repo = repo
    end

    key_ok = env_nonempty("DOCUMENTER_KEY")
    println(io, "- $(marker(key_ok)) ENV[\"DOCUMENTER_KEY\"] exists and is non-empty")
    all_ok &= key_ok

    print(io, "Deploying to folder $(repr(subfolder)): $(marker(all_ok))")
    @info String(take!(io))
    if build_type === :devbranch && !branch_ok && devbranch == "master" && cfg.commit_branch == "main"
        @warn """
        Possible deploydocs() misconfiguration: main vs master
        Documenter's configured primary development branch (`devbranch`) is "master", but the
        current branch (\$BUILDKITE_BRANCH) is "main". This can happen because Documenter uses
        GitHub's old default primary branch name as the default value for `devbranch`.

        If your primary development branch is 'main', you must explicitly pass `devbranch = "main"`
        to deploydocs.

        See #1443 for more discussion: https://github.com/JuliaDocs/Documenter.jl/issues/1443
        """
    end

    if all_ok
        return DeployDecision(;
            all_ok = true,
            branch = deploy_branch,
            repo = deploy_repo,
            subfolder = subfolder,
            is_preview = is_preview,
        )
    else
        return DeployDecision(; all_ok = false)
    end
end

authentication_method(::Buildkite) = Documenter.SSH

documenter_key(::Buildkite) = ENV["DOCUMENTER_KEY"]

##################
# Auto-detection #
##################
function auto_detect_deploy_system()
    if haskey(ENV, "TRAVIS_REPO_SLUG")
        return Travis()
    elseif haskey(ENV, "GITHUB_REPOSITORY")
        return GitHubActions()
    elseif haskey(ENV, "GITLAB_CI")
        return GitLab()
    elseif haskey(ENV, "BUILDKITE")
        return Buildkite()
    else
        return nothing
    end
end
