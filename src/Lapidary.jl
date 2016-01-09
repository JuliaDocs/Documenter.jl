module Lapidary

# imports
using Base.Meta

import URIParser

# exports
export makedocs

# includes
include("types.jl")
include("utilities.jl")
include("walker.jl")
include("passes.jl")


"""
    makedocs(
        src    = "src",
        build  = "build",
        format = ".md",
        clean  = true
    )

Converts markdown formatted template files found in `src` into `format`-formatted files in
the `build` directory. Option `clean` will empty out the `build` directory prior to building
new documentation.

`src` and `build` paths are set relative to the file from which `makedocs` is called. The
standard directory setup for using `makedocs` is as follows:

    docs/
        build/
        src/
        build.jl

where `build.jl` contains

```julia
using Lapidary

makedocs(
    # options...
)
```

Any non-markdown files found in the `src` directory are copied over to the `build` directory
without change. Markdown files are those with the extension `.md` only.
"""
function makedocs(;
        src     = "src",
        build   = "build",
        root    = Base.source_dir(),
        format  = ".md",
        clean   = true,
        passes  = [PassOne, PassTwo, PassThree],
    )
    cd(root) do
        process!(Document(src, build, format, clean, passes))
    end
end

end
