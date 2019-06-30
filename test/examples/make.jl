# Defines the modules referred to in the example docs (under src/) and then builds them.
# It can be called separately to build the examples/, or as part of the test suite.
#
# It defines a set of variables (`examples_*`) that can be used in the tests.
# The `examples_root` should be used to check whether this file has already been included
# or not and should be kept unique.
isdefined(@__MODULE__, :examples_root) && error("examples_root is already defined\n$(@__FILE__) included multiple times?")

# The `Mod` and `AutoDocs` modules are assumed to exists in the Main module.
(@__MODULE__) === Main || error("$(@__FILE__) must be included into Main.")

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

# Build example docs
using Documenter, DocumenterMarkdown

const examples_root = @__DIR__
const builds_directory = joinpath(examples_root, "builds")
ispath(builds_directory) && rm(builds_directory, recursive=true)

expandfirst = ["expandorder/AA.md"]

@info("Building mock package docs: MarkdownWriter")
examples_markdown_doc = makedocs(
    format = Markdown(),
    debug = true,
    root  = examples_root,
    build = "builds/markdown",
    doctest = false,
    expandfirst = expandfirst,
)


htmlbuild_pages = Any[
    "**Home**" => "index.md",
    "Manual" => [
        "man/tutorial.md",
    ],
    hide("hidden.md"),
    "Library" => [
        "lib/functions.md",
        "lib/autodocs.md",
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
    ]
]

@info("Building mock package docs: HTMLWriter / local build")
examples_html_local_doc = makedocs(
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

# Build with pretty URLs and canonical links and a PNG logo
@info("Building mock package docs: HTMLWriter / deployment build")

function withassets(f, assets...)
    src(asset) = joinpath(@__DIR__, asset)
    dst(asset) = joinpath(@__DIR__, "src/assets/$(basename(asset))")
    for asset in assets
        isfile(src(asset)) || error("$(asset) is missing")
    end
    for asset in assets
        cp(src(asset), dst(asset))
    end
    rv = try
        f()
    catch exception
        @warn "f() threw an exception" exception
        nothing
    end
    for asset in assets
        rm(dst(asset))
    end
    return rv
end

examples_html_deploy_doc = withassets("images/logo.png", "images/logo.jpg", "images/logo.gif") do
    makedocs(
        debug = true,
        root  = examples_root,
        build = "builds/html-deploy",
        doctestfilters = [r"Ptr{0x[0-9]+}"],
        sitename = "Documenter example",
        pages = htmlbuild_pages,
        expandfirst = expandfirst,
        doctest = false,
        format = Documenter.HTML(
            assets = [
                "assets/favicon.ico",
                "assets/custom.css"
            ],
            prettyurls = true,
            canonical = "https://example.com/stable",
        )
    )
end
