#!/usr/bin/env bash
#
# This builds the Julia manual for the latest Julia nightly build with
# the current Documenter, acting as a regression test.

# Terminate the script early if we see any non-zero error codes
set -e

# Figure out the Julia binary we use. This can be passed on the command line, but
# should always be a recent master build. Otherwise, we'll likely fail to check out
# the right commit in the shallow clone.
JULIA=${1:-$(which julia)}
echo "JULIA=$JULIA"
echo "julia --version:"
$JULIA --version
echo "julia> versioninfo()"
$JULIA -e 'using InteractiveUtils; versioninfo()'

# Get the commit the Julia nightly build is based on
julia_commit=$($JULIA -e 'print(Base.GIT_VERSION_INFO.commit)')

# Clone the repo
echo "Cloning JuliaLang/julia.git, commit ${julia_commit}"
git clone --revision=${julia_commit} --depth=1 https://github.com/JuliaLang/julia.git julia.git

# Use the local checkout of Documenter
$JULIA --project=julia.git -e 'using Pkg; Pkg.develop(path=".")'

# Build the docs
make -C julia.git/doc html JULIA_EXECUTABLE="${JULIA}"
