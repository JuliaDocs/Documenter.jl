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
    julia_source_path = abspath(joinpath(path, "julia"))

    # Clone the Julia repository & check out the commit of the currently running Julia version.
    # Doing a shallow clone of the exact commit, to avoid unnecessary downloads.
    cmd =
        `git clone --revision=$(Base.GIT_VERSION_INFO.commit) --depth=1 https://github.com/JuliaLang/julia.git $(julia_source_path)`
    @info """
    Cloning JuliaLang/julia.git
    $(cmd)
    """
    run(cmd)

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
        --
        $(DOCUMENTER_ROOT)
        ```
    )

    # Build the Julia manual. Apparently we need to build `julia-stdlib` first,
    # to ensure that all the stdlib sources would be present (which the doc build
    # depends on). This is relatively fast though, so not a problem.
    run(`make -C $(julia_source_path) julia-stdlib JULIA_EXECUTABLE=$(JULIA)`)
    return run(`make -C $(julia_source_path)/doc html JULIA_EXECUTABLE=$(JULIA)`)
end

# We'll clone the Julia nightly release etc into a temp directory, unless a path
# is passed.
cli_path = get(ARGS, 1, nothing)
if isnothing(cli_path)
    mktempdir(build_julia_manual)
else
    path = normpath(cli_path)
    if !isdir(path)
        error("not a directory: $(path)")
    end
    build_julia_manual(path)
end
