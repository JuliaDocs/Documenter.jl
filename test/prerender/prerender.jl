using Documenter, Test
import NodeJS_16_jll

function read_assets()
    path = joinpath(@__DIR__, "build", "assets", "documenter.js")
    return read(path, String)
end
function read_index()
    path = joinpath(@__DIR__, "build", "index.html")
    return read(path, String)
end

@testset "prerender with NodeJS" begin

    # Regular makedocs
    makedocs(;
        sitename = "Prerendering code blocks",
        format = Documenter.HTML(
            highlights = ["llvm"],
        ),
    )
    assets = read_assets()
    @test occursin("'highlight-julia'", assets)
    @test occursin("/languages/julia.min", assets)
    @test occursin("'highlight-julia-repl'", assets)
    @test occursin("/languages/julia-repl.min", assets)
    @test occursin("'highlight-llvm'", assets)
    @test occursin("/languages/llvm.min", assets)
    index = read_index()
    @test occursin("<code class=\"language-julia hljs\">function f()", index)
    @test occursin("<code class=\"language-julia-repl hljs\">julia&gt; function f()", index)
    @test occursin("<code class=\"language-llvm hljs\">;  @ int.jl:87 within", index)

    # With prerender
    HLJSFILES = Documenter.HTMLWriter.HLJSFILES
    for _ in 1:2 # test with and without highlightjs file given
        makedocs(;
            sitename = "Prerendering code blocks",
            format = Documenter.HTML(
                highlights = ["llvm"],
                prerender = true,
                node = NodeJS_16_jll.node(),
                highlightjs = length(HLJSFILES) == 0 ? nothing : last(first(HLJSFILES)),
            ),
        )
        local assets = read_assets()
        @test !occursin("'highlight-julia'", assets)
        @test !occursin("/languages/julia.min", assets)
        @test !occursin("'highlight-julia-repl'", assets)
        @test !occursin("/languages/julia-repl.min", assets)
        @test !occursin("'highlight-llvm'", assets)
        @test !occursin("/languages/llvm.min", assets)
        local index = read_index()
        @test !occursin("<code class=\"language-julia hljs\">function f()", index)
        @test !occursin("<code class=\"language-julia-repl hljs\">julia&gt; function f()", index)
        @test !occursin("<code class=\"language-llvm hljs\">;  @ int.jl:87 within", index)
        @test occursin("<code class=\"language-julia hljs\"><span class=\"hljs-keyword\">function</span> f()", index)
        @test occursin("<code class=\"language-julia-repl hljs\"><span class=\"hljs-meta prompt_\">julia&gt;</span>", index)
        @test occursin("<code class=\"language-llvm hljs\"><span class=\"hljs-comment\">;  @ int.jl:87", index)
        @test length(HLJSFILES) == 1
    end

    ## missing language (llvm)
    @test_logs (:error, "HTMLWriter: prerendering failed") match_mode = :any begin
        makedocs(;
            sitename = "Prerendering code blocks",
            format = Documenter.HTML(
                prerender = true,
                node = NodeJS_16_jll.node(),
            ),
        )
    end
    assets = read_assets()
    @test !occursin("'highlight-julia'", assets)
    @test !occursin("/languages/julia.min", assets)
    @test !occursin("'highlight-julia-repl'", assets)
    @test !occursin("/languages/julia-repl.min", assets)
    @test !occursin("'highlight-llvm'", assets)
    @test !occursin("/languages/llvm.min", assets)
    index = read_index()
    @test !occursin("<code class=\"language-julia hljs\">function f()", index)
    @test !occursin("<code class=\"language-julia-repl hljs\">julia&gt; function f()", index)
    @test occursin("<code class=\"language-llvm hljs\">;  @ int.jl:87 within", index)
    @test occursin("<code class=\"language-julia hljs\"><span class=\"hljs-keyword\">function</span> f()", index)
    @test occursin("<code class=\"language-julia-repl hljs\"><span class=\"hljs-meta prompt_\">julia&gt;</span>", index)
    @test !occursin("<code class=\"language-llvm hljs\"><span class=\"hljs-comment\">;  @ int.jl:87", index)

    @test length(HLJSFILES) == 2

    # Some failure modes
    @test_throws Base.IOError makedocs(;
        sitename = "Prerendering code blocks",
        format = Documenter.HTML(
            prerender = true,
            node = "nope",
        ),
    )

end # testset
