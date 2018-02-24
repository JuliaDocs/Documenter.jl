"""
Provides the functions related to generating documentation stubs.
"""
module Generator

using DocStringExtensions
using Compat: @info

"""
$(SIGNATURES)

Attempts to save a file at `\$(root)/\$(filename)`. `f` will be called with file
stream (see [`open`](https://docs.julialang.org/en/latest/base/io-network/#Base.open)).

`filename` can also be a file in a subdirectory (e.g. `src/index.md`), and then
then subdirectories will be created automatically.
"""
function savefile(f, root, filename)
    filepath = joinpath(root, filename)
    if ispath(filepath) error("$(filepath) already exists") end
    @info("Generating $filename at $filepath")
    mkpath(dirname(filepath))
    open(f,filepath,"w")
end

"""
$(SIGNATURES)

Contents of the default `make.jl` file.
"""
function make(pkgname)
    """
    using Documenter
    using $(pkgname)

    makedocs(
        modules = [$(pkgname)]
    )

    # Documenter can also automatically deploy documentation to gh-pages.
    # See "Hosting Documentation" and deploydocs() in the Documenter manual
    # for more information.
    #=deploydocs(
        repo = "<repository url>"
    )=#
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

mkdocs_default(name, value, default) = value == nothing ? "#$name$default" : "$name$value"

"""
$(SIGNATURES)

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
    $(mkdocs_default("repo_url:         ", url, "https://github.com/USER_NAME/PACKAGE_NAME.jl"))
    $(mkdocs_default("site_description: ", description, "Description..."))
    $(mkdocs_default("site_author:      ", author, "USER_NAME"))

    theme: readthedocs

    extra_css:
      - assets/Documenter.css

    extra_javascript:
      - https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS_HTML
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
$(SIGNATURES)

Contents of the default `src/index.md` file.
"""
function index(pkgname)
    """
    # $(pkgname).jl

    Documentation for $(pkgname).jl
    """
end

end
