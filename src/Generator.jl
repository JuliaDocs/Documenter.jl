"""
Provides the functions related to generating documentation stubs.
"""
module Generator

using DocStringExtensions

import ..Documenter:
    Utilities

"""
$(SIGNATURES)

Attempts to save a file at `\$(root)/\$(filename)`. `f` will be called with file
stream (see [`open`](http://docs.julialang.org/en/latest/stdlib/io-network.html#Base.open)).

`filename` can also be a file in a subdirectory (e.g. `src/index.md`), and then
then subdirectories will be created automatically.
"""
function savefile(filename, file, root = pwd() )
    filepath = joinpath(root, filename) |> Utilities.bad_dir
    info("Creating")
    mkpath(dirname(filepath) )
    open(filepath, "w") do io
        write(io, file)
    end
end

"""
$(SIGNATURES)

Attempts to append to a file at `\$(root)/\$(filename)`.
"""
function appendfile(filename, file, root = pwd() )
    filepath = joinpath(root, filename)
    if filepath |> Utilities.info_dir
        info("Appending")
        open(filepath, "a") do io
            write(io, file)
        end
    end
end

"""
$(SIGNATURES)

Contents of the default `make.jl` file.
"""
function make(pkgname, user)
    """
    using Documenter
    using $pkgname

    makedocs(
        modules = [$pkgname],
        format = :html,
        sitename = "$pkgname.jl",
        pages = Any["Home" => "index.md"],
        strict = true
    )

    deploydocs(
        repo = "github.com/$user/$pkgname.jl.git",
        target = "build",
        deps = nothing,
        make = nothing
    )
    """
end

"""
$(SIGNATURES)

Contents of the default `.gitignore` file.
"""
function gitignore()
    """
    build/
    site/
    """
end

"""
$(SIGNATURES)

Contents of the default `src/index.md` file.
"""
function index(pkgname)
    """
    # $pkgname.jl

    Documentation for $pkgname.jl

    ```@index
    ```

    ```@autodocs
    Modules = [$pkgname]
    ```
    """
end

function readme(pkgname, user)
    docs_stable_url = "https://$user.github.io/$pkgname.jl/stable"
    docs_latest_url = "https://$user.github.io/$pkgname.jl/latest"
    """

    ## Documentation

    - [Stable]($docs_stable_url)
    - [In Development]($docs_latest_url)
    """
end

function travis(pkgname)
    """
      # build documentation
      - julia -e 'cd(Pkg.dir("$pkgname")); Pkg.add("Documenter"); include(joinpath("docs", "make.jl"))'
    """
end

function require()
    """
    Documenter
    """
end

end
