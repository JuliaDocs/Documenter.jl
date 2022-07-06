module UtilitiesTests

using Test
using Logging: Info
import Base64: stringmime
include("TestUtilities.jl"); using .TestUtilities

import Documenter
using Documenter.Utilities: git
import Markdown

module UnitTests
    module SubModule end

    # Does `submodules` collect *all* the submodules?
    module A
        module B
            module C
                module D end
            end
        end
    end

    mutable struct T end
    mutable struct S{T} end

    "Documenter unit tests."
    Base.length(::T) = 1

    f(x) = x

    const pi = 3.0

    const TA = Vector{UInt128}
    const TB = Array{T, 8} where T
    const TC = Union{Int64, Float64, String}
end

module OuterModule
module InnerModule
import ..OuterModule
export OuterModule
end
end

module ExternalModule end
module ModuleWithAliases
using ..ExternalModule
Y = ExternalModule
module A
    module B
    const X = Main
    end
end
end

@testset "Utilities" begin
    let doc = @doc(length)
        a = Documenter.Utilities.filterdocs(doc, Set{Module}())
        b = Documenter.Utilities.filterdocs(doc, Set{Module}([UnitTests]))
        c = Documenter.Utilities.filterdocs(doc, Set{Module}([Base]))
        d = Documenter.Utilities.filterdocs(doc, Set{Module}([UtilitiesTests]))

        @test a !== nothing
        @test a === doc
        @test b !== nothing
        @test occursin("Documenter unit tests.", stringmime("text/plain", b))
        @test c !== nothing
        @test !occursin("Documenter unit tests.", stringmime("text/plain", c))
        @test d === nothing
    end

    # Documenter.Utilities.issubmodule
    @test Documenter.Utilities.issubmodule(Main, Main) === true
    @test Documenter.Utilities.issubmodule(UnitTests, UnitTests) === true
    @test Documenter.Utilities.issubmodule(UnitTests.SubModule, Main) === true
    @test Documenter.Utilities.issubmodule(UnitTests.SubModule, UnitTests) === true
    @test Documenter.Utilities.issubmodule(UnitTests.SubModule, Base) === false
    @test Documenter.Utilities.issubmodule(UnitTests, UnitTests.SubModule) === false

    @test UnitTests.A in Documenter.Utilities.submodules(UnitTests.A)
    @test UnitTests.A.B in Documenter.Utilities.submodules(UnitTests.A)
    @test UnitTests.A.B.C in Documenter.Utilities.submodules(UnitTests.A)
    @test UnitTests.A.B.C.D in Documenter.Utilities.submodules(UnitTests.A)
    @test OuterModule in Documenter.Utilities.submodules(OuterModule)
    @test OuterModule.InnerModule in Documenter.Utilities.submodules(OuterModule)
    @test length(Documenter.Utilities.submodules(OuterModule)) == 2
    @test Documenter.Utilities.submodules(ModuleWithAliases) == Set([ModuleWithAliases, ModuleWithAliases.A, ModuleWithAliases.A.B])

    @test Documenter.Utilities.isabsurl("file.md") === false
    @test Documenter.Utilities.isabsurl("../file.md") === false
    @test Documenter.Utilities.isabsurl(".") === false
    @test Documenter.Utilities.isabsurl("https://example.org/file.md") === true
    @test Documenter.Utilities.isabsurl("http://example.org") === true
    @test Documenter.Utilities.isabsurl("ftp://user:pw@example.org") === true
    @test Documenter.Utilities.isabsurl("/fs/absolute/path") === false

    @test Documenter.Utilities.doccat(UnitTests) == "Module"
    @test Documenter.Utilities.doccat(UnitTests.T) == "Type"
    @test Documenter.Utilities.doccat(UnitTests.S) == "Type"
    @test Documenter.Utilities.doccat(UnitTests.f) == "Function"
    @test Documenter.Utilities.doccat(UnitTests.pi) == "Constant"
    @test Documenter.Utilities.doccat(UnitTests.TA) == "Type"
    @test Documenter.Utilities.doccat(UnitTests.TB) == "Type"
    @test Documenter.Utilities.doccat(UnitTests.TC) == "Type"

    # repo type
    @test Documenter.Utilities.repo_host_from_url("https://bitbucket.org/somerepo") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("https://www.bitbucket.org/somerepo") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("http://bitbucket.org/somethingelse") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("http://github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://www.github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://gitlab.com/Whatever") == Documenter.Utilities.RepoGitlab
    @test Documenter.Utilities.repo_host_from_url("https://dev.azure.com/Whatever") == Documenter.Utilities.RepoAzureDevOps

    # line range
    let formatting = Documenter.Utilities.LineRangeFormatting(Documenter.Utilities.RepoGithub)
        @test Documenter.Utilities.format_line(1:1, formatting) == "L1"
        @test Documenter.Utilities.format_line(123:123, formatting) == "L123"
        @test Documenter.Utilities.format_line(2:5, formatting) == "L2-L5"
        @test Documenter.Utilities.format_line(100:9999, formatting) == "L100-L9999"
    end

    let formatting = Documenter.Utilities.LineRangeFormatting(Documenter.Utilities.RepoGitlab)
        @test Documenter.Utilities.format_line(1:1, formatting) == "L1"
        @test Documenter.Utilities.format_line(123:123, formatting) == "L123"
        @test Documenter.Utilities.format_line(2:5, formatting) == "L2-5"
        @test Documenter.Utilities.format_line(100:9999, formatting) == "L100-9999"
    end

    let formatting = Documenter.Utilities.LineRangeFormatting(Documenter.Utilities.RepoBitbucket)
        @test Documenter.Utilities.format_line(1:1, formatting) == "1"
        @test Documenter.Utilities.format_line(123:123, formatting) == "123"
        @test Documenter.Utilities.format_line(2:5, formatting) == "2:5"
        @test Documenter.Utilities.format_line(100:9999, formatting) == "100:9999"
    end

    let formatting = Documenter.Utilities.LineRangeFormatting(Documenter.Utilities.RepoAzureDevOps)
        @test Documenter.Utilities.format_line(1:1, formatting) == "&line=1"
        @test Documenter.Utilities.format_line(123:123, formatting) == "&line=123"
        @test Documenter.Utilities.format_line(2:5, formatting) == "&line=2&lineEnd=5"
        @test Documenter.Utilities.format_line(100:9999, formatting) == "&line=100&lineEnd=9999"
    end

    @test Documenter.Utilities.linerange(Core.svec(), 0) === 0:0

    # commit format
    @test Documenter.Utilities.format_commit("7467441e33e2bd586fb0ec80ed4c4cdef5068f6a", Documenter.Utilities.RepoGithub) == "7467441e33e2bd586fb0ec80ed4c4cdef5068f6a"
    @test Documenter.Utilities.format_commit("test", Documenter.Utilities.RepoGithub) == "test"
    @test Documenter.Utilities.format_commit("7467441e33e2bd586fb0ec80ed4c4cdef5068f6a", Documenter.Utilities.RepoGitlab) == "7467441e33e2bd586fb0ec80ed4c4cdef5068f6a"
    @test Documenter.Utilities.format_commit("test", Documenter.Utilities.RepoGitlab) == "test"
    @test Documenter.Utilities.format_commit("7467441e33e2bd586fb0ec80ed4c4cdef5068f6a", Documenter.Utilities.RepoBitbucket) == "7467441e33e2bd586fb0ec80ed4c4cdef5068f6a"
    @test Documenter.Utilities.format_commit("test", Documenter.Utilities.RepoBitbucket) == "test"
    @test Documenter.Utilities.format_commit("7467441e33e2bd586fb0ec80ed4c4cdef5068f6a", Documenter.Utilities.RepoAzureDevOps) == "GC7467441e33e2bd586fb0ec80ed4c4cdef5068f6a"
    @test Documenter.Utilities.format_commit("test", Documenter.Utilities.RepoAzureDevOps) == "GBtest"

    # URL building
    filepath = string(first(methods(Documenter.Utilities.url)).file)
    Sys.iswindows() && (filepath = replace(filepath, "/" => "\\")) # work around JuliaLang/julia#26424
    let expected_filepath = "/src/Utilities/Utilities.jl"
        Sys.iswindows() && (expected_filepath = replace(expected_filepath, "/" => "\\"))
        @test endswith(filepath, expected_filepath)
    end

    mktempdir() do path
        path_repo = joinpath(path, "repository")
        mkpath(path_repo)
        cd(path_repo) do
            # Create a simple mock repo in a temporary directory with a single file.
            @test trun(`$(git()) init`)
            @test trun(`$(git()) config user.email "tester@example.com"`)
            @test trun(`$(git()) config user.name "Test Committer"`)
            @test trun(`$(git()) remote add origin git@github.com:JuliaDocs/Documenter.jl.git`)
            mkpath("src")
            filepath = abspath(joinpath("src", "SourceFile.jl"))
            write(filepath, "X")
            @test trun(`$(git()) add -A`)
            @test trun(`$(git()) commit -m"Initial commit."`)

            # Run tests
            commit = Documenter.Utilities.repo_commit(filepath)

            @test Documenter.Utilities.url("//blob/{commit}{path}#{line}", filepath) == "//blob/$(commit)/src/SourceFile.jl#"
            @test Documenter.Utilities.url(nothing, "//blob/{commit}{path}#{line}", Documenter.Utilities, filepath, 10:20) == "//blob/$(commit)/src/SourceFile.jl#L10-L20"

            # repo_root & relpath_from_repo_root
            @test Documenter.Utilities.repo_root(filepath) == dirname(abspath(joinpath(dirname(filepath), ".."))) # abspath() keeps trailing /, hence dirname()
            @test Documenter.Utilities.repo_root(filepath; dbdir=".svn") == nothing
            @test Documenter.Utilities.relpath_from_repo_root(filepath) == joinpath("src", "SourceFile.jl")
            # We assume that a temporary file is not in a repo
            @test Documenter.Utilities.repo_root(tempname()) == nothing
            @test Documenter.Utilities.relpath_from_repo_root(tempname()) == nothing
        end

        # Test worktree
        path_worktree = joinpath(path, "worktree")
        cd("$(path_repo)") do
            @test trun(`$(git()) worktree add $(path_worktree)`)
        end
        cd("$(path_worktree)") do
            filepath = abspath(joinpath("src", "SourceFile.jl"))
            # Run tests
            commit = Documenter.Utilities.repo_commit(filepath)

            @test Documenter.Utilities.url("//blob/{commit}{path}#{line}", filepath) == "//blob/$(commit)/src/SourceFile.jl#"
            @test Documenter.Utilities.url(nothing, "//blob/{commit}{path}#{line}", Documenter.Utilities, filepath, 10:20) == "//blob/$(commit)/src/SourceFile.jl#L10-L20"

            # repo_root & relpath_from_repo_root
            @test Documenter.Utilities.repo_root(filepath) == dirname(abspath(joinpath(dirname(filepath), ".."))) # abspath() keeps trailing /, hence dirname()
            @test Documenter.Utilities.repo_root(filepath; dbdir=".svn") == nothing
            @test Documenter.Utilities.relpath_from_repo_root(filepath) == joinpath("src", "SourceFile.jl")
            # We assume that a temporary file is not in a repo
            @test Documenter.Utilities.repo_root(tempname()) == nothing
            @test Documenter.Utilities.relpath_from_repo_root(tempname()) == nothing
        end

        # Test submodule
        path_submodule = joinpath(path, "submodule")
        mkpath(path_submodule)
        cd(path_submodule) do
            @test trun(`$(git()) init`)
            @test trun(`$(git()) config user.email "tester@example.com"`)
            @test trun(`$(git()) config user.name "Test Committer"`)
            # NOTE: the target path in the `git submodule add` command is necessary for
            # Windows builds, since otherwise Git claims that the path is in a .gitignore
            # file.
            @test trun(`$(git()) submodule add $(path_repo) repository`)
            @test trun(`$(git()) add -A`)
            @test trun(`$(git()) commit -m"Initial commit."`)
        end
        path_submodule_repo = joinpath(path, "submodule", "repository")
        @test isdir(path_submodule_repo)
        cd(path_submodule_repo) do
            filepath = abspath(joinpath("src", "SourceFile.jl"))
            # Run tests
            commit = Documenter.Utilities.repo_commit(filepath)

            @test isfile(filepath)

            @test Documenter.Utilities.url("//blob/{commit}{path}#{line}", filepath) == "//blob/$(commit)/src/SourceFile.jl#"
            @test Documenter.Utilities.url(nothing, "//blob/{commit}{path}#{line}", Documenter.Utilities, filepath, 10:20) == "//blob/$(commit)/src/SourceFile.jl#L10-L20"

            # repo_root & relpath_from_repo_root
            @test Documenter.Utilities.repo_root(filepath) == dirname(abspath(joinpath(dirname(filepath), ".."))) # abspath() keeps trailing /, hence dirname()
            @test Documenter.Utilities.repo_root(filepath; dbdir=".svn") == nothing
            @test Documenter.Utilities.relpath_from_repo_root(filepath) == joinpath("src", "SourceFile.jl")
            # We assume that a temporary file is not in a repo
            @test Documenter.Utilities.repo_root(tempname()) == nothing
            @test Documenter.Utilities.relpath_from_repo_root(tempname()) == nothing
        end
    end

    import Documenter.Documents: Document, Page, Globals
    import Documenter.Utilities: Markdown2
    let page = Page("source", "build", :build, [], IdDict{Any,Any}(), Globals(), Markdown2.MD()), doc = Document()
        code = """
        x += 3
        γγγ_γγγ
        γγγ
        """
        exprs = Documenter.Utilities.parseblock(code, doc, page)

        @test isa(exprs, Vector)
        @test length(exprs) === 3

        @test isa(exprs[1][1], Expr)
        @test exprs[1][1].head === :+=
        @test exprs[1][2] == "x += 3\n"

        @test exprs[2][2] == "γγγ_γγγ\n"

        @test exprs[3][1] === :γγγ
        @test exprs[3][2] == "γγγ\n"
    end

    @testset "TextDiff" begin
        import Documenter.Utilities.TextDiff: splitby
        @test splitby(r"\s+", "X Y  Z") == ["X ", "Y  ", "Z"]
        @test splitby(r"[~]", "X~Y~Z") == ["X~", "Y~", "Z"]
        @test splitby(r"[▶]", "X▶Y▶Z") == ["X▶", "Y▶", "Z"]
        @test splitby(r"[▶]+", "X▶▶Y▶Z▶") == ["X▶▶", "Y▶", "Z▶"]
        @test splitby(r"[▶]+", "▶▶Y▶Z▶") == ["▶▶", "Y▶", "Z▶"]
        @test splitby(r"[▶]+", "Ω▶▶Y▶Z▶") == ["Ω▶▶", "Y▶", "Z▶"]
        @test splitby(r"[▶]+", "Ω▶▶Y▶Z▶κ") == ["Ω▶▶", "Y▶", "Z▶", "κ"]
    end

    @testset "issues #749, #790, #823" begin
        let parse(x) = Documenter.Utilities.parseblock(x, nothing, nothing)
            for LE in ("\r\n", "\n")
                l1, l2 = parse("x = Int[]$(LE)$(LE)push!(x, 1)$(LE)")
                @test l1[1] == :(x = Int[])
                @test l1[2] == "x = Int[]$(LE)"
                @test l2[1] == :(push!(x, 1))
                @test l2[2] == "push!(x, 1)$(LE)"
            end
        end
    end

    @testset "PR #1634, issue #1655" begin
        let parse(x) = Documenter.Utilities.parseblock(x, nothing, nothing;
                           linenumbernode=LineNumberNode(123, "testfile.jl")
                       )
            code = """
            1 + 1
            2 + 2
            """
            exs = parse(code)
            @test length(exs) == 2
            @test exs[1][2] == "1 + 1\n"
            @test exs[1][1].head == :toplevel
            @test exs[1][1].args[1] == LineNumberNode(124, "testfile.jl")
            @test exs[1][1].args[2] == Expr(:call, :+, 1, 1)
            @test exs[2][2] == "2 + 2\n"
            @test exs[2][1].head == :toplevel
            @test exs[2][1].args[1] == LineNumberNode(125, "testfile.jl")
            @test exs[2][1].args[2] == Expr(:call, :+, 2, 2)

            # corner case trailing whitespace
            code1 = """
            1 + 1

            """
            # corner case: trailing comment
            code2 = """
            1 + 1
            # comment
            """
            for code in (code1, code2)
                exs = parse(code)
                @test length(exs) == 1
                @test exs[1][2] == "1 + 1\n"
                @test exs[1][1].head == :toplevel
                @test exs[1][1].args[1] == LineNumberNode(124, "testfile.jl")
                @test exs[1][1].args[2] == Expr(:call, :+, 1, 1)
            end
        end
    end

    @testset "mdparse" begin
        mdparse = Documenter.Utilities.mdparse

        @test_throws ArgumentError mdparse("", mode=:foo)

        mdparse("") isa Markdown.Paragraph
        @test mdparse("foo bar") isa Markdown.Paragraph
        let md = mdparse("", mode=:span)
            @test md isa Vector{Any}
            @test length(md) == 1
        end
        let md = mdparse("", mode=:blocks)
            @test md isa Vector{Any}
            @test length(md) == 0
        end

        @test mdparse("!!! adm"; mode=:single) isa Markdown.Admonition
        let md = mdparse("!!! adm", mode=:blocks)
            @test md isa Vector{Any}
            @test length(md) == 1
        end
        let md = mdparse("x\n\ny", mode=:blocks)
            @test md isa Vector{Any}
            @test length(md) == 2
        end

        @quietly begin
            @test_throws ArgumentError mdparse("!!! adm", mode=:span)
            @test_throws ArgumentError mdparse("x\n\ny")
            @test_throws ArgumentError mdparse("x\n\ny", mode=:span)
        end
    end

    @testset "JSDependencies" begin
        using Documenter.Utilities.JSDependencies:
            RemoteLibrary, Snippet, RequireJS, verify, writejs, parse_snippet
        libraries = [
            RemoteLibrary("foo", "example.com/foo"),
            RemoteLibrary("bar", "example.com/bar"; deps = ["foo"]),
        ]
        snippet = Snippet(["foo", "bar"], ["Foo"], "f(x)")
        let r = RequireJS(libraries)
            push!(r, snippet)
            @test verify(r)
            output = let io = IOBuffer()
                writejs(io, r)
                String(take!(io))
            end
            # The expected output should look something like this:
            #
            #   // Generated by Documenter.jl
            #   requirejs.config({
            #     paths: {
            #       'bar': 'example.com/bar',
            #       'foo': 'example.com/foo',
            #     },
            #     shim: {
            #     "bar": {
            #       "deps": [
            #         "foo"
            #       ]
            #     }
            #   }
            #   });
            #   ////////////////////////////////////////////////////////////////////////////////
            #   require(['foo', 'bar'], function(Foo) {
            #   f(x)
            #   })
            #
            # But the output is not entirely deterministic, so we can't do just a string
            # comparison. Hence, we'll just do a few simple `occursin` tests, to make sure
            # that the most important things are at least present.
            @test occursin("'foo'", output)
            @test occursin("'bar'", output)
            @test occursin("example.com/foo", output)
            @test occursin("example.com/bar", output)
            @test occursin("f(x)", output)
            @test occursin(r"requirejs\.config\({[\S\s]+}\)", output)
            @test occursin(r"require\([\S\s]+\)", output)
        end
        # Error conditions: missing dependency
        let r = RequireJS([
                RemoteLibrary("foo", "example.com/foo"),
                RemoteLibrary("bar", "example.com/bar"; deps = ["foo", "baz"]),
            ])
            @test !verify(r)
            push!(r, RemoteLibrary("baz", "example.com/baz"))
            @test verify(r)
            push!(r, Snippet(["foo", "qux"], ["Foo"], "f(x)"))
            @test !verify(r)
            push!(r, RemoteLibrary("qux", "example.com/qux"))
            @test verify(r)
        end

        let io = IOBuffer(raw"""
            // libraries: foo, bar
            // arguments: $
            script
            """)
            snippet = parse_snippet(io)
            @test snippet.deps == ["foo", "bar"]
            @test snippet.args == ["\$"]
            @test snippet.js == "script\n"
        end

        # jsescape
        @testset "jsescape" begin
            using Documenter.Utilities.JSDependencies: jsescape
            @test jsescape("abc123") == "abc123"
            @test jsescape("▶αβγ") == "▶αβγ"
            @test jsescape("") == ""

            @test jsescape("a\nb") == "a\\nb"
            @test jsescape("\r\n") == "\\r\\n"
            @test jsescape("\\") == "\\\\"

            @test jsescape("\"'") == "\\\"\\'"

            # Ref: #639
            @test jsescape("\u2028") == "\\u2028"
            @test jsescape("\u2029") == "\\u2029"
            @test jsescape("policy to  delete.") == "policy to\\u2028 delete."
        end

        @testset "json_jsescape" begin
            using Documenter.Utilities.JSDependencies: json_jsescape
            @test json_jsescape(["abc"]) == raw"[\"abc\"]"
            @test json_jsescape(["\\"]) == raw"[\"\\\\\"]"
            @test json_jsescape(["x\u2028y"]) == raw"[\"x\u2028y\"]"
        end

        # Proper escaping of generated JS
        let r = RequireJS([
                RemoteLibrary("fo\'o", "example.com\n/foo"),
            ])
            @test verify(r)
            push!(r, Snippet(["fo\'o"], ["Foo"], "f(x)"))
            output = let io = IOBuffer()
                writejs(io, r)
                String(take!(io))
            end
            @test occursin("'fo\\'o'", output)
            @test occursin("example.com\\n/foo", output)
            @test !occursin("'fo'o'", output)
            @test !occursin("example.com\n/foo", output)
        end
    end

    @testset "codelang" begin
        @test Documenter.Utilities.codelang("") == ""
        @test Documenter.Utilities.codelang(" ") == ""
        @test Documenter.Utilities.codelang("  ") == ""
        @test Documenter.Utilities.codelang("\t  ") == ""
        @test Documenter.Utilities.codelang("julia") == "julia"
        @test Documenter.Utilities.codelang("julia-repl") == "julia-repl"
        @test Documenter.Utilities.codelang("julia-repl x=y") == "julia-repl"
        @test Documenter.Utilities.codelang("julia-repl\tx=y") == "julia-repl"
        @test Documenter.Utilities.codelang(" julia-repl\tx=y") == "julia-repl"
        @test Documenter.Utilities.codelang("\t julia   \tx=y ") == "julia"
        @test Documenter.Utilities.codelang("\t julia   \tx=y ") == "julia"
        @test Documenter.Utilities.codelang("&%^ ***") == "&%^"
    end

    @testset "is_strict" begin
        @test Documenter.Utilities.is_strict(true, :doctest)
        @test Documenter.Utilities.is_strict([:doctest], :doctest)
        @test Documenter.Utilities.is_strict(:doctest, :doctest)
        @test !Documenter.Utilities.is_strict(false, :doctest)
        @test !Documenter.Utilities.is_strict(:setup_block, :doctest)
        @test !Documenter.Utilities.is_strict([:setup_block], :doctest)

        @test Documenter.Utilities.is_strict(true, :setup_block)
        @test !Documenter.Utilities.is_strict(false, :setup_block)
        @test Documenter.Utilities.is_strict(:setup_block, :setup_block)
        @test Documenter.Utilities.is_strict([:setup_block], :setup_block)
    end

    @testset "check_strict_kw" begin
        @test Documenter.Utilities.check_strict_kw(:setup_block) === nothing
        @test Documenter.Utilities.check_strict_kw(:doctest) === nothing
        @test_throws ArgumentError Documenter.Utilities.check_strict_kw(:a)
        @test_throws ArgumentError Documenter.Utilities.check_strict_kw([:a, :doctest])
    end

    @testset "@docerror" begin
        doc = (; internal = (; errors = Symbol[]), user = (; strict = [:doctest, :setup_block]))
        foo = 123
        @test_logs (:warn, "meta_block issue 123") (Documenter.Utilities.@docerror(doc, :meta_block, "meta_block issue $foo"))
        @test :meta_block ∈ doc.internal.errors
        @test_logs (:error, "doctest issue 123") (Documenter.Utilities.@docerror(doc, :doctest, "doctest issue $foo"))
        @test :doctest ∈ doc.internal.errors
        try
            @macroexpand Documenter.Utilities.@docerror(doc, :foo, "invalid tag")
            error("unexpected")
        catch err
            err isa LoadError && (err = err.error)
            @test err isa ArgumentError
            @test err.msg == "tag :foo is not a valid Documenter error"
        end
    end

    @testset "git_remote_head_branch" begin

        function git_create_bare_repo(path; head = nothing)
            mkdir(path)
            @test trun(`$(git()) -C $(path) init --bare`)
            @test isfile(joinpath(path, "HEAD"))
            if head !== nothing
                write(joinpath(path, "HEAD"), """
                ref: refs/heads/$(head)
                """)
            end
            mktempdir() do subdir_path
                # We need to commit something to the non-standard branch to actually
                # "activate" the non-standard HEAD:
                head = (head === nothing) ? "master" : head
                @test trun(`$(git()) clone $(path) $(subdir_path)`)
                @test trun(`$(git()) -C $(subdir_path) config user.email "tester@example.com"`)
                @test trun(`$(git()) -C $(subdir_path) config user.name "Test Committer"`)
                @test trun(`$(git()) -C $(subdir_path) checkout -b $(head)`)
                @test trun(`$(git()) -C $(subdir_path) commit --allow-empty -m"initial empty commit"`)
                @test trun(`$(git()) -C $(subdir_path) push --set-upstream origin $(head)`)
            end
        end

        mktempdir() do path
            cd(path) do
                # Note: running @test_logs with match_mode=:any here so that the tests would
                # also pass when e.g. JULIA_DEBUG=Documenter when the tests are being run.
                # If there is no parent remote repository, we should get a warning and the fallback value:
                @test (@test_logs (:warn,) match_mode=:any Documenter.Utilities.git_remote_head_branch(".", pwd(); fallback = "fallback")) == "fallback"
                @test (@test_logs (:warn,) match_mode=:any Documenter.Utilities.git_remote_head_branch(".", pwd())) == "master"
                # We'll set up two "remote" bare repositories with non-standard HEADs:
                git_create_bare_repo("barerepo", head = "maindevbranch")
                git_create_bare_repo("barerepo_other", head = "main")
                # Clone barerepo and test git_remote_head_branch:
                @test trun(`$(git()) clone barerepo/ local/`)
                @test Documenter.Utilities.git_remote_head_branch(".", "local") == "maindevbranch"
                # Now, let's add the other repo as another remote, and fetch the HEAD for that:
                @test trun(`$(git()) -C local/ remote add other ../barerepo_other/`)
                @test trun(`$(git()) -C local/ fetch other`)
                @test Documenter.Utilities.git_remote_head_branch(".", "local") == "maindevbranch"
                @test Documenter.Utilities.git_remote_head_branch(".", "local"; remotename = "other") == "main"
                # Asking for a nonsense remote should also warn and drop back to fallback:
                @test (@test_logs (:warn,) match_mode=:any Documenter.Utilities.git_remote_head_branch(".", pwd(); remotename = "nonsense", fallback = "fallback")) == "fallback"
                @test (@test_logs (:warn,) match_mode=:any Documenter.Utilities.git_remote_head_branch(".", pwd(); remotename = "nonsense")) == "master"
            end
        end
    end
end

end
