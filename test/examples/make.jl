# Defines the modules referred to in the example docs (under src/) and then builds them.
# It can be called separately to build the examples/, or as part of the test suite.
#
# It defines a set of variables (`examples_*`) that can be used in the tests.
# The `examples_root` should be used to check whether this file has already been included
# or not and should be kept unique.
isdefined(@__MODULE__, :examples_root) && error("examples_root is already defined\n$(@__FILE__) included multiple times?")

# The `Mod` and `AutoDocs` modules are assumed to exists in the Main module.
(@__MODULE__) === Main || error("$(@__FILE__) must be included into Main.")

# DOCUMENTER_TEST_EXAMPLES environment variable can be used to control which
# builds actually run. E.g. to only build the HTML deployment example build, you
# could call the make.jl file as follows:
#
#     DOCUMENTER_TEST_EXAMPLES=html julia --project test/examples/make.jl
#
EXAMPLE_BUILDS = if haskey(ENV, "DOCUMENTER_TEST_EXAMPLES")
    split(ENV["DOCUMENTER_TEST_EXAMPLES"])
else
    ["markdown", "html", "html-local"]
end

# Modules `Mod` and `AutoDocs`
module Mod
    """
        func(x)

    [`T`](@ref)
    """
    func(x) = x

    """
        T

    [`func(x)`](@ref)
    """
    mutable struct T end
end

"`AutoDocs` module."
module AutoDocs
    module Pages
        include("pages/a.jl")
        include("pages/b.jl")
        include("pages/c.jl")
        include("pages/d.jl")
        include("pages/e.jl")
    end

    "Function `f`."
    f(x) = x

    "Constant `K`."
    const K = 1

    "Type `T`."
    mutable struct T end

    "Macro `@m`."
    macro m() end

    "Module `A`."
    module A
        "Function `A.f`."
        f(x) = x

        "Constant `A.K`."
        const K = 1

        "Type `B.T`."
        mutable struct T end

        "Macro `B.@m`."
        macro m() end
    end

    "Module `B`."
    module B
        "Function `B.f`."
        f(x) = x

        "Constant `B.K`."
        const K = 1

        "Type `B.T`."
        mutable struct T end

        "Macro `B.@m`."
        macro m() end
    end

    module Filter
        "abstract super type"
        abstract type Major end

        "abstract sub type 1"
        abstract type Minor1 <: Major end

        "abstract sub type 2"
        abstract type Minor2 <: Major end

        "random constant"
        qq = 3.14

        "random function"
        function qqq end
    end
end

# Helper functions
function withassets(f, assets...)
    src(asset) = joinpath(@__DIR__, asset)
    dst(asset) = joinpath(@__DIR__, "src/assets/$(basename(asset))")
    for asset in assets
        isfile(src(asset)) || error("$(asset) is missing")
    end
    for asset in assets
        cp(src(asset), dst(asset))
    end
    rv, exception = try
        f(), nothing
    catch e
        nothing, e
    end
    for asset in assets
        rm(dst(asset))
    end
    return (exception === nothing) ? rv : throw(exception)
end

# Build example docs
using Documenter, DocumenterMarkdown
isdefined(@__MODULE__, :TestUtilities) || (include("../TestUtilities.jl"); using .TestUtilities)

const examples_root = @__DIR__
const builds_directory = joinpath(examples_root, "builds")
ispath(builds_directory) && rm(builds_directory, recursive=true)

expandfirst = ["expandorder/AA.md"]
htmlbuild_pages = Any[
    "**Home**" => "index.md",
    "Manual" => [
        "man/tutorial.md",
    ],
    hide("hidden.md"),
    "Library" => [
        "lib/functions.md",
        "lib/autodocs.md",
        "lib/editurl.md",
    ],
    hide("Hidden Pages" => "hidden/index.md", Any[
        "Page X" => "hidden/x.md",
        "hidden/y.md",
        "hidden/z.md",
    ]),
    "Expandorder" => [
        "expandorder/00.md",
        "expandorder/01.md",
        "expandorder/AA.md",
    ],
    "unicode.md",
    "latex.md",
]

# Build with pretty URLs and canonical links and a PNG logo
examples_html_doc = if "html" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build")
    @quietly withassets("images/logo.png", "images/logo.jpg", "images/logo.gif") do
        makedocs(
            debug = true,
            root  = examples_root,
            build = "builds/html",
            doctestfilters = [r"Ptr{0x[0-9]+}"],
            sitename = "Documenter example",
            pages = htmlbuild_pages,
            expandfirst = expandfirst,
            doctest = false,
            format = Documenter.HTML(
                assets = [
                    "assets/favicon.ico",
                    "assets/custom.css",
                    asset("https://example.com/resource.js"),
                    asset("http://example.com/fonts?param=foo", class=:css),
                    asset("https://fonts.googleapis.com/css?family=Nanum+Brush+Script&display=swap", class=:css),
                ],
                prettyurls = true,
                canonical = "https://example.com/stable",
                mathengine = MathJax(Dict(:TeX => Dict(
                    :equationNumbers => Dict(:autoNumber => "AMS"),
                    :Macros => Dict(
                        :ket => ["|#1\\rangle", 1],
                        :bra => ["\\langle#1|", 1],
                    ),
                ))),
                highlights = ["erlang", "erlang-repl"],
            )
        )
    end
else
    @info "Skipping build: HTML/deploy" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# HTML: local build with pretty URLs off
examples_html_local_doc = if "html-local" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / local build")
    @quietly makedocs(
        debug = true,
        root  = examples_root,
        build = "builds/html-local",
        doctestfilters = [r"Ptr{0x[0-9]+}"],
        sitename = "Documenter example",
        pages = htmlbuild_pages,
        expandfirst = expandfirst,

        linkcheck = true,
        linkcheck_ignore = [r"(x|y).md", "z.md", r":func:.*"],
        format = Documenter.HTML(
            assets = ["assets/custom.css"],
            prettyurls = false,
            edit_branch = nothing,
        ),
    )
else
    @info "Skipping build: HTML/local" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# Markdown
examples_markdown_doc = if "markdown" in EXAMPLE_BUILDS
    @info("Building mock package docs: MarkdownWriter")
    @quietly makedocs(
        format = Markdown(),
        debug = true,
        root  = examples_root,
        build = "builds/markdown",
        doctest = false,
        expandfirst = expandfirst,
    )
else
    @info "Skipping build: Markdown" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# PDF/LaTeX
examples_latex_simple_doc = if "latex_simple" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/simple")
    @quietly makedocs(
        format = Documenter.Writers.LaTeXWriter.LaTeX(platform = "docker"),
        sitename = "Documenter LaTeX Simple",
        root  = examples_root,
        build = "builds/latex_simple",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/simple" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_doc = if "latex" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex")
    @quietly makedocs(
        format = Documenter.Writers.LaTeXWriter.LaTeX(platform = "docker"),
        sitename = "Documenter LaTeX",
        root  = examples_root,
        build = "builds/latex",
        pages = htmlbuild_pages = Any[
            "General" => [
                "index.md",
                "latex.md",
                "unicode.md",
                hide("hidden.md"),
            ],
            # man/tutorial.md can't be built because it contains SVG images
            # "Manual" => ["man/tutorial.md"],
            hide("Hidden Pages" => "hidden/index.md", Any[
                "Page X" => "hidden/x.md",
                "hidden/y.md",
                "hidden/z.md",
            ]),
            "Library" => [
                "lib/functions.md",
                "lib/autodocs.md",
                "lib/editurl.md",
            ],
            "Expandorder" => [
                "expandorder/00.md",
                "expandorder/01.md",
                "expandorder/AA.md",
            ],
        ],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_simple_nondocker_doc = if "latex_simple_nondocker" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_simple_nondocker")
    @quietly makedocs(
        format = Documenter.Writers.LaTeXWriter.LaTeX(),
        sitename = "Documenter LaTeX Simple Non-Docker",
        root  = examples_root,
        build = "builds/latex_simple_nondocker",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_simple_nondocker" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end
