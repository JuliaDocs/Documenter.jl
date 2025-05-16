#!/usb/bin/env bash
#
# This builds the Julia manual for the latest Julia nightly build with
# the current Documenter, acting as a regression test.

# Terminate the script early if we see any non-zero error codes
set -e

# Location if this bash script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOCUMENTER_SRC=$(dirname $(dirname "$SCRIPT_DIR"))

# We'll download the Julia nightly release etc into a temp directory
TMP=$(mktemp -d)
cd "$TMP"
echo "Running in: $PWD"
# .. which we also want to clean up when the script exits
trap "rm -r $TMP" EXIT

# Pull down the latest Julia binary
wget https://julialangnightlies-s3.julialang.org/bin/linux/x86_64/julia-latest-linux-x86_64.tar.gz
tar -xzf julia-latest-linux-x86_64.tar.gz
# Find the Julia directory, since it has a hash in the name (julia-{commit})
JULIA_DIR=$(find . -maxdepth 1 -type d -name "julia-*")
JULIA=$(realpath "${JULIA_DIR}/bin/julia")
echo "julia --version:"
$JULIA --version
echo "julia> versioninfo()"
$JULIA -e 'using InteractiveUtils; versioninfo()'

# Get the date one week ago, which we'll use for shallow-cloning the Git repo
one_week_ago=$($JULIA -e 'using Dates; print(Dates.format(now() - Week(1), dateformat"yyyy-mm-dd"))')
julia_commit=$($JULIA -e 'print(Base.GIT_VERSION_INFO.commit)')

# Clone the repo
echo "Cloning JuliaLang/julia.git (--shallow-since=$(one_week_ago)), checkout $(julia_commit)"
git clone --branch master --shallow-since="$one_week_ago" https://github.com/JuliaLang/julia.git
JULIA_SRC=$(realpath "julia")
git -C "$(JULIA_SRC)" checkout "$(julia_commit)"

# Use the local checkout of Documenter
$JULIA --project="$(JULIA_SRC)/doc" -e 'using Pkg; Pkg.develop(path=ARGS[1])' -- "$DOCUMENTER_SRC"

# Build the docs
make -C julia/doc html JULIA_EXECUTABLE="$(JULIA)"
