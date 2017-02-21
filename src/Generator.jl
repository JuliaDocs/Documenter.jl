"""
Provides the functions related to generating documentation stubs.
"""
module Generator

using DocStringExtensions

import ..Documenter:
    Utilities

"""
$(SIGNATURES)

Attempts to save a file at `\$(root)/\$(filename)`.

`f` will be called with file stream.
`root` defaults to your present working directory. `filename` can also be a file
in a subdirectory (e.g. `src/index.md`), and then subdirectories will be created
automatically. Errors if the creation location already exists.
"""
function savefile(filename, file, root = pwd() )
    filepath = joinpath(root, filename)
    if ispath(filepath)
        error("$filepath already exists")
    end
    info("Creating $filepath")
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
    if !ispath(filepath)
        savefile(filename, file, root)
    else
        info("Appending to $filepath")
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
        pages = ["Home" => "index.md"],
        strict = true
    )

    # See https://juliadocs.github.io/Documenter.jl/stable/man/hosting.html
    # for more information about deployment

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

    ## Documentation [here]($docs_stable_url)
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
