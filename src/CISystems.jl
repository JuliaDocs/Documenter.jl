"""
    enum CI_SYSTEM

The supported CI systems to deploy docs from, using Documenter.jl.

Values:
* [`TRAVIS`](@ref)
* [`GITLAB_CI`](@ref)
* [`CIRRUS_CI`](@ref)
* [`DRONE`](@ref)
* [`APPVEYOR`](@ref)
"""
@enum CI_SYSTEM begin
    TRAVIS
    GITLAB_CI
    CIRRUS_CI
    DRONE
    APPVEYOR
end
# docstrings for CI_SYSTEM values
"Specialize [`deploydocs`](@ref) for [Travis CI](https://travis-ci.org/). See also [`Documenter.CI_SYSTEM`](@ref)."
TRAVIS
"Specialize [`deploydocs`](@ref) for [Appveyor](https://www.appveyor.com/). See also [`Documenter.CI_SYSTEM`](@ref)."
APPVEYOR
"Specialize [`deploydocs`](@ref) for [GitLab CI](https://about.gitlab.com/product/continuous-integration/). See also [`Documenter.CI_SYSTEM`](@ref)."
GITLAB_CI
"Specialize [`deploydocs`](@ref) for [Cirrus CI](https://cirrus-ci.org/). See also [`Documenter.CI_SYSTEM`](@ref)."
CIRRUS_CI
"Specialize [`deploydocs`](@ref) for [Drone](https://drone.io/). See also [`Documenter.CI_SYSTEM`](@ref)."
DRONE

"""
    read_ci_env([returnfinaldeploy::Bool]; uploader::CI_SYSTEM = TRAVIS)

Read the CI environment variables, and return (always) a NamedTuple where the first
five elements are, in order:
    - `cibranch`: which branch is CI running on?
    - `pull_request`: is CI building a pull request?  Empty string if not.
    - `repo_slug`: The URL-friendly repo name.
    - `tag`: The tag being built bu CI.  Empty string if not.
    - `event_type`: The event that triggered CI.
Furthermore, if `returnfinaldeploy` is true, the function will check whether the
current CI provider matches `uploader` (set by default to Travis).

Returns a NamedTuple.
"""
function read_ci_env(returnfinaldeploy=false; uploader::CI_SYSTEM = TRAVIS)

    arraylength = returnfinaldeploy ? 6 : 5

    ret = nothing

    if haskey(ENV, "TRAVIS")

        @info "Travis CI detected"

        cibranch     = get(ENV, "TRAVIS_BRANCH",             "")
        pull_request = get(ENV, "TRAVIS_PULL_REQUEST",       "")
        repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",          "")
        tag          = get(ENV, "TRAVIS_TAG",                "")
        event_type   = get(ENV, "TRAVIS_EVENT_TYPE",         "")

        ret = (cibranch = cibranch, pull_request = pull_request, repo_slug = repo_slug, tag = tag, event_type = event_type)

        returnfinaldeploy && begin ret = (ret..., uploader = uploader == TRAVIS) end

    elseif haskey(ENV, "GITLAB_CI")

        @info "Gitlab CI detected"

        cibranch     = get(ENV, "CI_COMMIT_REF_NAME",        "")
        pull_request = get(ENV, "CI_MERGE_REQUEST_ID",  "false")
        repo_slug    = get(ENV, "CI_PROJECT_PATH",           "")
        tag          = get(ENV, "CI_COMMIT_TAG",             "")
        event_type   = get(ENV, "CI_PIPELINE_SOURCE",        "")

        ret = (cibranch = cibranch, pull_request = pull_request, repo_slug = repo_slug, tag = tag, event_type = event_type)

        returnfinaldeploy && begin ret = (ret..., uploader = uploader == GITLAB_CI) end

    elseif haskey(ENV, "DRONE")

        @info "Drone CI detected"

        cibranch     = get(ENV, "DRONE_COMMIT_BRANCH",       "")
        pull_request = get(ENV, "DRONE_PULL_REQUEST",   "false")
        repo_slug    = get(ENV, "DRONE_REPO_NAMESPACE",      "") * "/" * get(ENV, "DRONE_REPO_NAME", "")
        tag          = get(ENV, "DRONE_TAG",                 "")
        event_type   = get(ENV, "DRONE_BUILD_EVENT",         "")

        ret = (cibranch = cibranch, pull_request = pull_request, repo_slug = repo_slug, tag = tag, event_type = event_type)

        returnfinaldeploy && begin ret = (ret..., uploader = uploader == DRONE) end

    elseif haskey(ENV, "CIRRUS_CI")

        @info "Cirrus CI detected"

        cibranch     = get(ENV, "CIRRUS_BRANCH",             "")
        pull_request = get(ENV, "CIRRUS_PR",            "false")
        repo_slug    = get(ENV, "CIRRUS_REPO_FULL_NAME",     "")
        tag          = get(ENV, "CIRRUS_TAG",                "")
        event_type   = "unknown" # Cirrus CI doesn't seem to provide the triggering event...

        ret[1:5] .= (cibranch, pull_request, repo_slug, tag, event_type)

        returnfinaldeploy && begin ret[6] = uploader == CIRRUS_CI end

    elseif haskey(ENV, "APPVEYOR") # the worst of them all

        @info "AppVeyor CI detected"

        pull_request = get(ENV, "APPVEYOR_PULL_REQUEST_NUMBER",  "false")
        cibranch     = if haskey(ENV, "APPVEYOR_PULL_REQUEST_NUMBER"    )
                            ENV["APPVEYOR_PULL_REQUEST_HEAD_REPO_BRANCH"]
                        else
                            get(ENV, "APPVEYOR_REPO_BRANCH",          "")
                        end
        repo_slug    = get(ENV, "APPVEYOR_PROJECT_SLUG",              "")
        tag          = get(ENV, "APPVEYOR_REPO_TAG_NAME",             "")
        event_type   = "unknown" # Appveyor has four env vars for this...

        ret = (cibranch = cibranch, pull_request = pull_request, repo_slug = repo_slug, tag = tag, event_type = event_type)

        returnfinaldeploy && begin ret = (ret..., uploader = uploader == APPVEYOR) end

    else
        @warn """
            We don't recognize the CI service you're running, or haven't added support for it.
            We currently support Travis CI, Gitlab CI, Drone CI, Cirrus CI and AppVeyor.
            """
        ret = (cibranch = nothing, pull_request = nothing, repo_slug = nothing, tag = nothing, event_type = nothing)
        returnfinaldeploy && begin ret = (ret..., uploader = uploader == nothing) end

    end
end
