"""
Provides the functions related to generating documentation stubs.
"""
module Generator

using DocStringExtensions

"""
$(SIGNATURES)

Attempts to save a file at `\$(root)/\$(filename)`. `f` will be called with file
stream (see [`open`](http://docs.julialang.org/en/latest/stdlib/io-network.html#Base.open)).

`filename` can also be a file in a subdirectory (e.g. `src/index.md`), and then
then subdirectories will be created automatically.
"""
function savefile(f, root, filename)
    filepath = joinpath(root, filename)
    if ispath(filepath) error("$(filepath) already exists") end
    info("Generating $filename at $filepath")
    mkpath(dirname(filepath))
    open(f,filepath,"w")
end

"""
$(SIGNATURES)

Attempts to append to a file at `\$(root)/\$(filename)`. `f` will be called with
file stream (see [`open`](http://docs.julialang.org/en/latest/stdlib/io-network/#Base.open)).
"""
function appendfile(f, root, filename)
    filepath = joinpath(root, filename)
    info("Appending to $filename at $filepath")
    open(f,filepath,"a")
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

    # for successful deployment, make sure to
    # - add a gh-pages branch on github
    # - run `import Documenter; Documenter.Travis.genkeys("$pkgname")` in a
    #       *REPL* and follow instructions. For Windows, run from inside
    #       git-bash.
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

"""
$(SIGNATURES)

Additions to `README.md`
"""
function readme(pkgname, user)
    docs_stable_url = "https://$user.github.io/$pkgname.jl/stable"
    docs_latest_url = "https://$user.github.io/$pkgname.jl/latest"
    """

    ## Documentation

    - [**STABLE**]($docs_stable_url) &mdash; **most recently tagged version of the documentation.**
    - [**LATEST**]($docs_latest_url) &mdash; *in-development version of the documentation.*
    """
end

"""
$(SIGNATURES)

Additions to `travis.yml`
"""
function travis(pkgname)
    """
      # build documentation
      - julia -e 'ENV["DOCUMENTER_DEBUG"] = "true"; cd(Pkg.dir("$pkgname")); Pkg.add("Documenter"); include(joinpath("docs", "make.jl"))'
    """
end

"""
$(SIGNATURES)

Additions to `test/REQUIRE`
"""
function require()
    """
    Documenter
    """
end

end
