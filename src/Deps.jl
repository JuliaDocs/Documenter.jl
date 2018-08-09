"""
Exported module that provides build and deploy dependencies and related functions.

Currently only [`pip`](@ref) is implemented.
"""
module Deps

export pip

using DocStringExtensions

"""
$(SIGNATURES)

Installs (as non-root user) all python packages listed in `deps`.

# Examples

```julia
using Documenter

makedocs(
    # ...
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material"),
    # ...
)
```
"""
function pip(deps...)
    for dep in deps
        run(`pip install --user $(dep)`)
    end
end


function localbin()
    Sys.islinux() ? joinpath(homedir(), ".local", "bin") :
    Sys.isapple() ? joinpath(homedir(), "Library", "Python", "2.7", "bin") : ""
end

function updatepath!(p = localbin())
    if occursin(p, ENV["PATH"])
        ENV["PATH"]
    else
        ENV["PATH"] = "$p:$(ENV["PATH"])"
    end
end

end
