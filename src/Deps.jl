"""
Exported module that provides build and deploy dependancies and related functions.

Currently only [`pip`](@ref) is implemented.
"""
module Deps

export pip

"""
    pip(deps...)

Installs (as non-root user) all python packages listed in `deps`.

**Examples**

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
pip(deps...) = () -> run(`pip install --user $(deps...)`)


function localbin()
    is_linux() ? joinpath(homedir(), ".local", "bin") :
    is_apple() ? joinpath(homedir(), "Library", "Python", "2.7", "bin") : ""
end

function updatepath!(p = localbin())
    if contains(ENV["PATH"], p)
        ENV["PATH"]
    else
        ENV["PATH"] = "$p:$(ENV["PATH"])"
    end
end

if isdefined(:OS_NAME) && !isdefined(:is_linux) && !isdefined(:is_apple) # compat
    is_linux() = OS_NAME === :Linux
    is_apple() = OS_NAME === :Apple || OS_NAME === :Darwin
end

end
