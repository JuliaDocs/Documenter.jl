using Lapidary

# Build documentation.
# ====================

makedocs(
    # options
    modules = [Lapidary],
    clean   = false
)

# Deploy built documentation from Travis.
# =======================================

# Needs to install an additional dep, mkdocs-material, so provide a custom `deps`.
custom_deps() = run(`pip install --user pygments mkdocs mkdocs-material`)

deploydocs(
    # options
    deps = custom_deps,
    repo = "github.com/MichaelHatherly/Lapidary.jl.git"
)
