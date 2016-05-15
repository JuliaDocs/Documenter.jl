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
    OS_NAME === :Linux  ? joinpath(homedir(), ".local", "bin") :
    OS_NAME === :Darwin ? joinpath(homedir(), "Library", "Python", "2.7", "bin") : ""
end

function updatepath!(p = localbin())
    if contains(ENV["PATH"], p)
        ENV["PATH"]
    else
        ENV["PATH"] = "$p:$(ENV["PATH"])"
    end
end

end
