# Defines the modules referred to in the example docs (under src/) and then builds them.
# It can be called separately to build the examples/, or as part of the test suite.
#
# It defines a set of variables (`examples_*`) that can be used in the tests.
# The `examples_root` should be used to check whether this file has already been included
# or not and should be kept unique.
isdefined(:examples_root) && error("examples_root is already defined\n$(@__FILE__) included multiple times?")

# The `Mod` and `AutoDocs` modules are assumed to exists in the Main module.
current_module() === Main || error("$(@__FILE__) must be included into Main.")

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
end

module Issue398

struct TestType{T} end

function _show end
Base.show(io::IO, t::TestType) = _show(io, t)

macro define_show_and_make_object(x, y)
    z = Expr(:quote, x)
    esc(quote
        $(Issue398)._show(io::IO, t::$(Issue398).TestType{$z}) = print(io, $y)
        const $x = $(Issue398).TestType{$z}()
    end)
end

export @define_show_and_make_object

end # module

module InlineSVG
export SVG
mutable struct SVG
    code :: String
end
Base.show(io, ::MIME"image/svg+xml", svg::SVG) = write(io, svg.code)
end # module

# Build example docs
using Documenter

const examples_root = dirname(@__FILE__)

info("Building mock package docs: MarkdownWriter")
examples_markdown_doc = makedocs(
    debug = true,
    root  = examples_root,
    build = "builds/markdown",
    doctest = false,
)

info("Building mock package docs: HTMLWriter")
examples_html_doc = makedocs(
    debug = true,
    root  = examples_root,
    build = "builds/html",
    format   = :html,
    assets = ["assets/custom.css"],
    sitename = "Documenter example",
    pages    = Any[
        "Home" => "index.md",
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
        ])
    ],

    linkcheck = true,
    linkcheck_ignore = [r"(x|y).md", "z.md", r":func:.*"],
)

info("Building mock package docs: HTMLWriter with pretty URLs")
examples_html_doc = makedocs(
    debug = true,
    root  = examples_root,
    build = "builds/html-pretty-urls",
    format   = :html,
    html_prettyurls = true,
    assets = ["assets/custom.css"],
    sitename = "Documenter example",
    pages    = Any[
        "Home" => "index.md",
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
        ])
    ],
    doctest = false,
)
