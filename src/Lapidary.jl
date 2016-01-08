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

# interface
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
