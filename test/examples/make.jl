import SHA
using Documenter
include("../TestUtilities.jl"); using Main.TestUtilities

# Defines the modules referred to in the example docs (under src/) and then builds them.
# It can be called separately to build the examples/, or as part of the test suite.

# The `Mod` and `AutoDocs` modules are assumed to exist in the Main module.
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
    [
        "html", "html-meta-custom", "html-mathjax2-custom", "html-mathjax3", "html-mathjax3-custom",
        "html-local", "html-draft", "html-repo-git", "html-repo-nothing", "html-repo-error",
        "html-sizethreshold-defaults-fail", "html-sizethreshold-success", "html-sizethreshold-ignore-success", "html-sizethreshold-override-fail", "html-sizethreshold-ignore-success", "html-sizethreshold-ignore-fail",
        "latex_texonly", "latex_simple_texonly", "latex_showcase_texonly", "html-pagesonly",
    ]
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

    @doc raw"""
    Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

    Display equation:

    ```math
    \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
    ```

    !!! note "Long equations in admonitions"

        Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

        Display equation:

        ```math
        \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
        ```

    Long equations in footnotes.[^longeq_footnote]

    [^longeq_footnote]:

        Inline: ``\frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}``

        Display equation:

        ```math
        \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2} + \frac{1+2+3+4+5+6}{\sigma^2}
        ```
    """
    function long_equations_in_docstrings end
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

    using Markdown: @doc_str
    @doc doc"random function"
    function qqq end
end
end

struct MIMEBytes{M <: MIME}
    bytes::Vector{UInt8}
    hash_slug::String
    function MIMEBytes(mime::AbstractString, bytes::AbstractVector{UInt8})
        hash_slug = bytes2hex(SHA.sha1(bytes))[1:8]
        return new{MIME{Symbol(mime)}}(bytes, hash_slug)
    end
end
Base.show(io::IO, ::M, obj::MIMEBytes{M}) where {M <: MIME} = write(io, obj.bytes)

const AT_EXAMPLE_FILES = Dict(
    ("png", :big) => MIMEBytes("image/png", read(joinpath(@__DIR__, "images", "big.png"))),
    ("png", :tiny) => MIMEBytes("image/png", read(joinpath(@__DIR__, "images", "tiny.png"))),
    ("webp", :big) => MIMEBytes("image/webp", read(joinpath(@__DIR__, "images", "big.webp"))),
    ("webp", :tiny) => MIMEBytes("image/webp", read(joinpath(@__DIR__, "images", "tiny.webp"))),
    ("gif", :big) => MIMEBytes("image/gif", read(joinpath(@__DIR__, "images", "big.gif"))),
    ("jpeg", :tiny) => MIMEBytes("image/jpeg", read(joinpath(@__DIR__, "images", "tiny.jpeg"))),
)
SVG_BIG = MIMEBytes("image/svg+xml", read(joinpath(@__DIR__, "images", "big.svg")))
SVG_HTML = MIMEBytes("text/html", read(joinpath(@__DIR__, "images", "big.svg")))

struct MultiMIMESVG
    bytes::Vector{UInt8}
    hash_slug::String
    function MultiMIMESVG(bytes::AbstractVector{UInt8})
        hash_slug = bytes2hex(SHA.sha1(bytes))[1:8]
        return new(bytes, hash_slug)
    end
end
Base.show(io::IO, ::MIME"image/svg+xml", obj::MultiMIMESVG) = write(io, obj.bytes)
Base.show(io::IO, ::MIME"text/html", obj::MultiMIMESVG) = write(io, obj.bytes)
SVG_MULTI = MultiMIMESVG(read(joinpath(@__DIR__, "images", "big.svg")))

# Helper functions
function withassets(f, assets...)
    src(asset) = joinpath(@__DIR__, asset)
    dst(asset) = joinpath(@__DIR__, "src/assets/$(basename(asset))")
    for asset in assets
        isfile(src(asset)) || error("$(asset) is missing")
    end
    for asset in assets
        isfile(dst(asset)) && @warn "Asset '$asset' present, dirty build directory. Overwriting." src(asset) dst(asset)
        cp(src(asset), dst(asset), force = true)
    end
    return try
        f()
    finally
        @debug "Cleaning up assets" assets
        for asset in assets
            rm(dst(asset))
        end
    end
end

struct TestRemote <: Remotes.Remote end
Remotes.repourl(::TestRemote) = "https://example.org/Repository.jl"
function Remotes.fileurl(::TestRemote, ::Any, filename, linerange)
    L1, L2 = first(linerange), last(linerange)
    return "https://example.org/Repository.jl/blob/$(filename)#L$(L1)-$(L2)"
end
Remotes.issueurl(::TestRemote, issue) = "https://example.org/Repository.jl/blob/$(issue)"

# Build example docs

examples_root = @__DIR__
builds_directory = joinpath(examples_root, "builds")
ispath(builds_directory) && rm(builds_directory, recursive = true)

expandfirst = ["expandorder/AA.md"]
htmlbuild_pages = Any[
    "**Home**" => "index.md",
    "Manual" => [
        "man/tutorial.md",
        "man/style.md",
        "man/page with space.md",
    ],
    hide("hidden.md"),
    "Library" => [
        "lib/functions.md",
        "lib/autodocs.md",
    ],
    hide(
        "Hidden Pages" => "hidden/index.md", Any[
            "Page X" => "hidden/x.md",
            "hidden/y.md",
            "hidden/z.md",
        ]
    ),
    "Expandorder" => [
        "expandorder/00.md",
        "expandorder/01.md",
        "expandorder/AA.md",
    ],
    "unicode.md",
    "latex.md",
    "example-output.md",
    "fonts.md",
    "issue491.md",
    "linenumbers.md",
    "EditURL" => [
        "editurl/good.md",
        "editurl/bad.md",
        "editurl/ugly.md",
    ],
    "xrefs.md",
    "Outputs" => [
        "outputs/index.md",
        "outputs/outputs.md",
    ],
]

function html_doc(
        build_directory, mathengine;
        htmlkwargs = (;),
        image_assets = ("images/logo.png", "images/logo.jpg", "images/logo.gif"),
        warnonly = true,
        kwargs...
    )
    return @quietly withassets(image_assets...) do
        makedocs(;
            debug = true,
            root = examples_root,
            build = "builds/$(build_directory)",
            doctestfilters = [r"Ptr{0x[0-9]+}"],
            sitename = "Documenter example",
            pages = htmlbuild_pages,
            expandfirst = expandfirst,
            doctest = false,
            format = Documenter.HTML(;
                assets = [
                    "assets/favicon.ico",
                    "assets/custom.css",
                    asset("https://example.com/resource.js"),
                    asset("http://example.com/fonts?param=foo", class = :css),
                    asset("https://fonts.googleapis.com/css?family=Nanum+Brush+Script&display=swap", class = :css),
                ],
                prettyurls = true,
                canonical = "https://example.com/stable",
                mathengine = mathengine,
                highlights = ["erlang", "erlang-repl"],
                footer = "This footer has been customized.",
                inventory_version = "$(Documenter.DOCUMENTER_VERSION)+test",
                htmlkwargs...
            ),
            warnonly = warnonly,
            kwargs...
        )
    end
end

# Build with pretty URLs and canonical links and a PNG logo
examples_html_doc = if "html" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build")
    html_doc(
        "html",
        MathJax2(
            Dict(
                :TeX => Dict(
                    :equationNumbers => Dict(:autoNumber => "AMS"),
                    :Macros => Dict(
                        :ket => ["|#1\\rangle", 1],
                        :bra => ["\\langle#1|", 1],
                        :pdv => ["\\frac{\\partial^{#1} #2}{\\partial #3^{#1}}", 3, ""],
                    ),
                ),
            )
        ),
        htmlkwargs = (; edit_link = :commit),
    )
else
    @info "Skipping build: HTML/deploy"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# Same as HTML but with custom site description and preview image
examples_html_meta_custom_doc = if "html-meta-custom" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build (custom meta tags)")
    html_doc(
        "html-meta-custom",
        MathJax2(
            Dict(
                :TeX => Dict(
                    :equationNumbers => Dict(:autoNumber => "AMS"),
                    :Macros => Dict(
                        :ket => ["|#1\\rangle", 1],
                        :bra => ["\\langle#1|", 1],
                        :pdv => ["\\frac{\\partial^{#1} #2}{\\partial #3^{#1}}", 3, ""],
                    ),
                ),
            )
        ),
        htmlkwargs = (;
            edit_link = :commit,
            description = "Example site-wide description.",
        ),
        image_assets = ("images/logo.png", "images/logo.jpg", "images/logo.gif", "images/preview.png"),
    )
else
    @info "Skipping build: HTML/deploy (custom meta tags)"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# Same as HTML, but with variations on the MathJax configuration
examples_html_mathjax2_custom_doc = if "html-mathjax2-custom" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build using MathJax v2 (custom URL)")
    html_doc(
        "html-mathjax2-custom",
        MathJax2(
            Dict(
                :TeX => Dict(
                    :equationNumbers => Dict(:autoNumber => "AMS"),
                    :Macros => Dict(
                        :ket => ["|#1\\rangle", 1],
                        :bra => ["\\langle#1|", 1],
                        :pdv => ["\\frac{\\partial^{#1} #2}{\\partial #3^{#1}}", 3, ""],
                    ),
                ),
            ),
            url = "https://cdn.jsdelivr.net/npm/mathjax@2/MathJax.js?config=TeX-AMS-MML_HTMLorMML",
        ),
        htmlkwargs = (; edit_link = nothing, repolink = nothing),
    )
else
    @info "Skipping build: HTML/deploy MathJax v2 (custom URL)"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end
examples_html_mathjax3_doc = if "html-mathjax3" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build using MathJax v3")
    html_doc(
        "html-mathjax3",
        MathJax3(
            Dict(
                :loader => Dict("load" => ["[tex]/physics"]),
                :tex => Dict(
                    "inlineMath" => [["\$", "\$"], ["\\(", "\\)"]],
                    "tags" => "ams",
                    "packages" => ["base", "ams", "autoload", "physics"],
                ),
            )
        ),
    )
else
    @info "Skipping build: HTML/deploy MathJax v3"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end
examples_html_mathjax3_custom_doc = if "html-mathjax3-custom" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / deployment build using MathJax v3 (custom URL)")
    html_doc(
        "html-mathjax3-custom",
        MathJax3(
            Dict(
                :loader => Dict("load" => ["[tex]/physics"]),
                :tex => Dict(
                    "inlineMath" => [["\$", "\$"], ["\\(", "\\)"]],
                    "tags" => "ams",
                    "packages" => ["base", "ams", "autoload", "physics"],
                ),
            ),
            url = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js",
        ),
    )
else
    @info "Skipping build: HTML/deploy MathJax v3 (custom URL)"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# HTML: local build with pretty URLs off
examples_html_local_doc = if "html-local" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / local build")
    @quietly makedocs(
        debug = true,
        root = examples_root,
        build = "builds/html-local",
        doctestfilters = [r"Ptr{0x[0-9]+}"],
        sitename = "Documenter example",
        pages = htmlbuild_pages,
        expandfirst = expandfirst,
        repo = "https://dev.azure.com/org/project/_git/repo?path={path}&version={commit}{line}&lineStartColumn=1&lineEndColumn=1",
        linkcheck = true,
        linkcheck_ignore = [r"(x|y).md", "z.md", r":func:.*"],
        linkcheck_useragent = "Documenter/1",
        format = Documenter.HTML(
            assets = [
                "assets/custom.css",
                asset("https://plausible.io/js/plausible.js", class = :js, attributes = Dict(Symbol("data-domain") => "example.com", :defer => "")),
            ],
            prettyurls = false,
            footer = nothing,
        ),
        # TODO: example_block failure only happens on windows, so that's not actually expected
        warnonly = [:doctest, :footnote, :cross_references, :linkcheck, :example_block, :eval_block],
    )
else
    @info "Skipping build: HTML/local"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# HTML: draft mode
examples_html_draft_doc = if "html-draft" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / draft build")
    @quietly makedocs(
        debug = true,
        draft = true,
        root = examples_root,
        build = "builds/html-draft",
        sitename = "Documenter example (draft)",
        pages = htmlbuild_pages,
        warnonly = [:footnote, :cross_references],
    )
else
    @info "Skipping build: HTML/draft"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# HTML: pagesonly
examples_html_pagesonly_doc = if "html-pagesonly" in EXAMPLE_BUILDS
    @info("Building mock package docs: HTMLWriter / draft build")
    @quietly makedocs(
        debug = true,
        draft = true,
        root = examples_root,
        build = "builds/html-pagesonly",
        sitename = "Documenter example (pagesonly)",
        pages = [
            "**Home**" => "index.md",
            "Manual" => [
                "man/tutorial.md",
                "man/style.md",
            ],
        ],
        pagesonly = true,
        warnonly = :cross_references,
    )
else
    @info "Skipping build: HTML/pagesonly"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

# HTML: A few simple builds testing the repo keyword fallbacks
macro examplebuild(name, block)
    docvar = Symbol("examples_html_", replace(name, "-" => "_"), "_doc")
    fullname = "html-$(name)"
    return quote
        $(esc(docvar)) = if $(fullname) in EXAMPLE_BUILDS
            $(block)
        else
            @info string("Skipping build: HTML/", $(name))
            @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
            nothing
        end
    end
end
function html_repo(name; kwargs...)
    return @quietly makedocs(;
        sitename = "Documenter Repo ($name)",
        build = joinpath(examples_root, "builds/html-repo-$(name)"),
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
        kwargs...,
    )
end
@examplebuild "repo-git" begin
    # should pick up JuliaDocs/Documenter.jl remote from Documenter's repo
    html_repo("git", root = examples_root, source = "src.latex_simple")
end
@examplebuild "repo-nothing" begin
    mktempdir() do dir
        cp(joinpath(examples_root, "src.latex_simple"), joinpath(dir, "src"))
        html_repo("nothing", root = dir, remotes = nothing)
    end
end
@examplebuild "repo-error" begin
    mktempdir() do dir
        cp(joinpath(examples_root, "src.latex_simple"), joinpath(dir, "src"))
        html_repo("error", root = dir, remotes = nothing)
    end
end

# size thresholds
@examplebuild "sizethreshold-defaults-fail" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-defaults-fail",
            source = "src.megapage",
            debug = true,
        )
    catch e
        e
    end
end
@examplebuild "sizethreshold-success" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-success",
            source = "src.megapage",
            format = Documenter.HTML(size_threshold = 5 * 2^20),
            debug = true,
        )
    catch e
        e
    end
end
@examplebuild "sizethreshold-ignore-success" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-ignore-success",
            source = "src.megapage",
            format = Documenter.HTML(size_threshold = nothing),
            debug = true,
        )
    catch e
        e
    end
end
@examplebuild "sizethreshold-override-fail" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-override-fail",
            source = "src.megapage",
            format = Documenter.HTML(size_threshold = 100, size_threshold_warn = nothing),
            debug = true,
        )
    catch e
        e
    end
end
@examplebuild "sizethreshold-ignore-success" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-defaults-fail",
            source = "src.megapage",
            format = Documenter.HTML(size_threshold_ignore = ["index.md", "subdir/subpage.md"]),
            debug = true,
        )
    catch e
        e
    end
end
@examplebuild "sizethreshold-ignore-fail" begin
    @quietly try
        makedocs(;
            sitename = "Megabyte",
            root = examples_root,
            build = "builds/sizethreshold-defaults-fail",
            source = "src.megapage",
            # Note: it's fine to pass non-existent pages to size_threshold_ignore
            format = Documenter.HTML(size_threshold_ignore = ["foo.md"]),
            debug = true,
        )
    catch e
        e
    end
end

# PDF/LaTeX
examples_latex_simple_doc = if "latex_simple" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/simple")
    @quietly makedocs(
        format = Documenter.LaTeXWriter.LaTeX(platform = "docker", version = v"1.2.3"),
        sitename = "Documenter LaTeX Simple",
        root = examples_root,
        build = "builds/latex_simple",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/simple"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_doc = if "latex" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex")
    @quietly makedocs(
        format = Documenter.LaTeXWriter.LaTeX(platform = "docker"),
        sitename = "Documenter LaTeX",
        root = examples_root,
        build = "builds/latex",
        pages = htmlbuild_pages = Any[
            "General" => [
                "index.md",
                "latex.md",
                "unicode.md",
                hide("hidden.md"),
                # The title override tests that we escape headings correctly
                "`@example_output`" => "example-output.md",
            ],
            # SVG images nor code blocks in footnotes are allowed in LaTeX
            # "Manual" => [
            #     "man/tutorial.md",
            #     "man/style.md",
            # ],
            hide(
                "Hidden Pages" => "hidden/index.md", Any[
                    "Page X" => "hidden/x.md",
                    "hidden/y.md",
                    "hidden/z.md",
                ]
            ),
            "Library" => [
                "lib/functions.md",
                "lib/autodocs.md",
            ],
            "Expandorder" => [
                "expandorder/00.md",
                "expandorder/01.md",
                "expandorder/AA.md",
            ],
        ],
        doctest = false,
        debug = true,
        warnonly = [:footnote, :cross_references, :example_block, :eval_block],
    )
else
    @info "Skipping build: LaTeXWriter/latex"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_simple_nondocker_doc = if "latex_simple_nondocker" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_simple_nondocker")
    @quietly makedocs(
        format = Documenter.LaTeX(version = v"1.2.3"),
        sitename = "Documenter LaTeX Simple Non-Docker",
        root = examples_root,
        build = "builds/latex_simple_nondocker",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_simple_nondocker"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_simple_tectonic_doc = if "latex_simple_tectonic" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_simple_tectonic")
    using tectonic_jll: tectonic
    @quietly makedocs(
        format = Documenter.LaTeX(platform = "tectonic", version = v"1.2.3", tectonic = tectonic()),
        sitename = "Documenter LaTeX Simple Tectonic",
        root = examples_root,
        build = "builds/latex_simple_tectonic",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_simple_tectonic"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end


examples_latex_texonly_doc = if "latex_texonly" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_texonly")
    @quietly makedocs(
        format = Documenter.LaTeX(platform = "none"),
        sitename = "Documenter LaTeX",
        root = examples_root,
        build = "builds/latex_texonly",
        pages = Any[
            "General" => [
                "index.md",
                "latex.md",
                "unicode.md",
                hide("hidden.md"),
                "example-output.md",
                "linenumbers.md",
            ],
            # SVG images nor code blocks in footnotes are allowed in LaTeX
            # "Manual" => [
            #     "man/tutorial.md",
            #     "man/style.md",
            # ],
            hide(
                "Hidden Pages" => "hidden/index.md", Any[
                    "Page X" => "hidden/x.md",
                    "hidden/y.md",
                    "hidden/z.md",
                ]
            ),
            "Library" => [
                "lib/functions.md",
                "lib/autodocs.md",
            ],
            "Expandorder" => [
                "expandorder/00.md",
                "expandorder/01.md",
                "expandorder/AA.md",
            ],
        ],
        doctest = false,
        debug = true,
        warnonly = [:footnote, :cross_references, :example_block, :eval_block],
    )
else
    @info "Skipping build: LaTeXWriter/latex_texonly"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_simple_texonly_doc = if "latex_simple_texonly" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_simple_texonly")
    @quietly makedocs(
        format = Documenter.LaTeX(platform = "none", version = v"1.2.3"),
        sitename = "Documenter LaTeX Simple Non-Docker",
        root = examples_root,
        build = "builds/latex_simple_texonly",
        source = "src.latex_simple",
        pages = ["Main section" => ["index.md"]],
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_simple_texonly"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_cover_page = if "latex_cover_page" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_cover_page")
    @quietly makedocs(
        format = Documenter.LaTeXWriter.LaTeX(platform = "docker"),
        sitename = "Documenter LaTeX",
        root = examples_root,
        build = "builds/latex_cover_page",
        source = "src.cover_page",
        pages = ["Home" => "index.md"],
        authors = "The Julia Project",
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_cover_page"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_toc_style = if "latex_toc_style" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_toc_style")
    @quietly makedocs(
        format = Documenter.LaTeXWriter.LaTeX(platform = "docker"),
        sitename = "Documenter LaTeX",
        root = examples_root,
        build = "builds/latex_toc_style",
        source = "src.toc_style",
        pages = ["Part-I" => "index.md"],
        authors = "The Julia Project",
        doctest = false,
        debug = true,
    )
else
    @info "Skipping build: LaTeXWriter/latex_toc_style"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_showcase_doc = if "latex_showcase" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_showcase")
    @quietly makedocs(
        format = Documenter.LaTeX(platform = "docker", version = v"1.2.3"),
        sitename = "Documenter LaTeX Showcase",
        root = examples_root,
        build = "builds/latex_showcase",
        source = "src.latex_showcase",
        pages = ["Showcase" => ["showcase.md", "docstrings.md"]],
        remotes = Dict(@__DIR__() => (TestRemote(), "6ef16754bc5da93f67a4323fb204c5bd3e64f336")),
        doctest = false,
        debug = true,
        warnonly = [:docs_block, :cross_references],
    )
else
    @info "Skipping build: LaTeXWriter/latex_showcase"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end

examples_latex_showcase_texonly_doc = if "latex_showcase_texonly" in EXAMPLE_BUILDS
    @info("Building mock package docs: LaTeXWriter/latex_showcase_texonly")
    @quietly makedocs(
        format = Documenter.LaTeX(platform = "none", version = v"1.2.3"),
        sitename = "Documenter LaTeX Showcase",
        root = examples_root,
        build = "builds/latex_showcase_texonly",
        source = "src.latex_showcase",
        pages = ["Showcase" => ["showcase.md", "docstrings.md"]],
        remotes = Dict(@__DIR__() => (TestRemote(), "6ef16754bc5da93f67a4323fb204c5bd3e64f336")),
        doctest = false,
        debug = true,
        warnonly = [:docs_block, :cross_references],
    )
else
    @info "Skipping build: LaTeXWriter/latex_showcase_texonly"
    @debug "Controlling variables:" EXAMPLE_BUILDS get(ENV, "DOCUMENTER_TEST_EXAMPLES", nothing)
    nothing
end
