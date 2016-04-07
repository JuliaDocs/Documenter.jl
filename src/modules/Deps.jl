"""
Exported module that provides build and deploy dependancies and related functions.

Currently only [`pip`]({ref}) is implemented.
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

end
