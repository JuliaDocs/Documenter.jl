# This builds the Julia manual for the latest Julia nightly build with
# the current Documenter, acting as a regression test.

# Terminate the script early if we see any non-zero error codes
# (Julia does this by default with run() calls)

using Dates, InteractiveUtils, Pkg

const DOCUMENTER_ROOT = dirname(dirname(@__DIR__))
const JULIA = joinpath(Sys.BINDIR, Base.julia_exename())

# Figure out the Julia binary we use. This can be passed on the command line, but
# should always be a recent master build. Otherwise, we'll likely fail to check out
# the right commit in the shallow clone.
@info """
JULIA=$JULIA
Julia Version $(VERSION)
Commit: $(Base.GIT_VERSION_INFO.commit) ($(Base.GIT_VERSION_INFO.date_string))
Commit (short): $(Base.GIT_VERSION_INFO.commit_short)

julia> versioninfo()
$(sprint(versioninfo))
"""

function build_julia_manual(path::AbstractString)
    julia_commit = Base.GIT_VERSION_INFO.commit
    julia_source_path = abspath(joinpath(path, "julia"))

    # Clone the Julia repository & check out the commit of the currently
    # running Julia version.
    cmd = if Base.GIT_VERSION_INFO.tagged_commit
        println("Cloning JuliaLang/julia.git (--shallow-since), checkout $julia_commit")
        `git clone --branch $(Base.GIT_VERSION_INFO.branch) --depth 1 https://github.com/JuliaLang/julia.git $(julia_source_path)`
    else
        # We'll shallow clone the repository going back no more than one week. This is just
        # to make the clone go a bit faster on CI etc. We expect this to be fine, since this
        # workflow will run on Julia nightly.
        one_week_ago = Dates.format(now() - Week(1), dateformat"yyyy-mm-dd")
        println("Cloning JuliaLang/julia.git (--shallow-since=$one_week_ago), checkout $julia_commit")
        `git clone --branch $(Base.GIT_VERSION_INFO.branch) --shallow-since=$one_week_ago https://github.com/JuliaLang/julia.git $(julia_source_path)`
    end
    @info """
    Cloning JuliaLang/julia.git
    $(cmd)
    """
    run(cmd)
    run(`git -C $julia_source_path checkout $(Base.GIT_VERSION_INFO.commit)`)

    # Use the local checkout of Documenter in the Julia docs building environment
    project_path = joinpath(julia_source_path, "deps", "jlutilities", "documenter")
    let project_toml = joinpath(project_path, "Project.toml")
        if !isfile(project_toml)
            error("Unable to find julia Documenter env at $(project_toml)")
        end
    end
    @info "Update Documenter Julia doc environment" project_path
    run(
        ```
        $(Base.julia_cmd())
        --project=$(project_path)
        -e 'using Pkg; Pkg.develop(path=ARGS[1])'
        $(DOCUMENTER_ROOT)
        ```
    )

    # Build the Julia manual
    run(`make -C $(julia_source_path) julia-deps JULIA_EXECUTABLE=$(JULIA)`)
    return run(`make -C $(julia_source_path)/doc html JULIA_EXECUTABLE=$(JULIA)`)
end

# We'll clone the Julia nightly release etc into a temp directory
mktempdir() do tmp
    cd(tmp) do
        @info "Running in $(tmp)"
        build_julia_manual(tmp)
    end
end
