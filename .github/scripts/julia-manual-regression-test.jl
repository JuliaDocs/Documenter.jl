# This builds the Julia manual for the latest Julia nightly build with
# the current Documenter, acting as a regression test.

# Terminate the script early if we see any non-zero error codes
# (Julia does this by default with run() calls)

using Dates, InteractiveUtils, Pkg

# Location of this Julia script
SCRIPT_DIR = @__DIR__
DOCUMENTER_SRC = dirname(dirname(SCRIPT_DIR))

# Figure out the Julia binary we use. This can be passed on the command line, but
# should always be a recent master build. Otherwise, we'll likely fail to check out
# the right commit in the shallow clone.
JULIA = length(ARGS) >= 1 ? ARGS[1] : joinpath(Sys.BINDIR, Base.julia_exename())
println("JULIA=$JULIA")
println("julia --version:")
println("  Julia Version $(VERSION)")
println("  Commit $(Base.GIT_VERSION_INFO.commit_short) ($(Base.GIT_VERSION_INFO.date_string))")
println("julia> versioninfo()")
versioninfo()

# We'll clone the Julia nightly release etc into a temp directory
TMP = mktempdir()
cd(TMP)
println("Running in: $(pwd())")
# Julia's mktempdir() automatically cleans up on exit

# Get the date one week ago, which we'll use for shallow-cloning the Git repo
one_week_ago = Dates.format(now() - Week(1), dateformat"yyyy-mm-dd")
julia_commit = Base.GIT_VERSION_INFO.commit

# Clone the repo
println("Cloning JuliaLang/julia.git (--shallow-since=$one_week_ago), checkout $julia_commit")
run(`git clone --branch master --shallow-since=$one_week_ago https://github.com/JuliaLang/julia.git`)
JULIA_SRC = realpath("julia")
run(`git -C $JULIA_SRC checkout $julia_commit`)

# Use the local checkout of Documenter
project_path = joinpath(JULIA_SRC, "deps", "jlutilities", "documenter")
Pkg.activate(project_path)
Pkg.develop(path=DOCUMENTER_SRC)

# Build the docs
run(`make -C julia/doc html JULIA_EXECUTABLE=$JULIA`)
