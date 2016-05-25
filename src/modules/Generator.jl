"""
Provides the functions related to generating documentation stubs.
"""
module Generator

"""
    savefile(f, root, filename)

Attempts to save a file at `\$(root)/\$(filename)`. `f` will be called with file
stream (see [`open`](http://docs.julialang.org/en/latest/stdlib/io-network/#Base.open)).

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
Contents of the default `make.jl` file.
"""
function make(pkgname)
    """
    using Documenter
    using $(pkgname)

    makedocs(
        modules = [$(pkgname)]
    )

    #deploydocs()
    """
end

"""
Contents of the default `.gitignore` file.
"""
function gitignore()
    """
    build/
    site/
    """
end


macro mkdocs_default(name,value,default)
    quote
        if $value===nothing
            "#"*$name*$default
        else
            $name*$value
        end
    end
end

"""
Contents of the default `mkdocs.yml` file.
"""
function mkdocs(pkgname;
        description = nothing,
        author = nothing,
        url = nothing
    )
    s = """
    # See the mkdocs user guide for more information on these settings.
    #   http://www.mkdocs.org/user-guide/configuration/

    site_name:        $(pkgname).jl
    $(@mkdocs_default "repo_url:         " url "https://github.com/USER_NAME/PACKAGE_NAME.jl")
    $(@mkdocs_default "site_description: " description "Description...")
    $(@mkdocs_default "site_author:      " author "USER_NAME")

    theme: readthedocs

    extra_css:
      - assets/Documenter.css

    extra_javascript:
      - https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML
      - assets/mathjaxhelper.js

    markdown_extensions:
      - extra
      - tables
      - fenced_code
      - mdx_math

    docs_dir: 'build'

    pages:
      - Home: index.md
    """
end

"""
Contents of the default `src/index.md` file.
"""
function index(pkgname)
    """
    # $(pkgname).jl

    Documentation for $(pkgname).jl
    """
end

end
