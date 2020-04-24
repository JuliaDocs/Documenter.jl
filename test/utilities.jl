module UtilitiesTests

using Test
import Base64: stringmime

import Documenter
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

# hasfield was added in Julia 1.2. This definition borrowed from Compat.jl (MIT)
# Note: this can not be inside the testset
(VERSION < v"1.2.0-DEV.272") && (hasfield(::Type{T}, name::Symbol) where T = Base.fieldindex(T, name, false) > 0)

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

    # repo type
    @test Documenter.Utilities.repo_host_from_url("https://bitbucket.org/somerepo") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("https://www.bitbucket.org/somerepo") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("http://bitbucket.org/somethingelse") == Documenter.Utilities.RepoBitbucket
    @test Documenter.Utilities.repo_host_from_url("http://github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://www.github.com/Whatever") == Documenter.Utilities.RepoGithub
    @test Documenter.Utilities.repo_host_from_url("https://gitlab.com/Whatever") == Documenter.Utilities.RepoGitlab

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
            @test success(`git init`)
            @test success(`git config user.email "tester@example.com"`)
            @test success(`git config user.name "Test Committer"`)
            @test success(`git remote add origin git@github.com:JuliaDocs/Documenter.jl.git`)
            mkpath("src")
            filepath = abspath(joinpath("src", "SourceFile.jl"))
            write(filepath, "X")
            @test success(`git add -A`)
            @test success(`git commit -m"Initial commit."`)

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
            @test success(`git worktree add $(path_worktree)`)
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
            @test success(`git init`)
            @test success(`git config user.email "tester@example.com"`)
            @test success(`git config user.name "Test Committer"`)
            # NOTE: the target path in the `git submodule add` command is necessary for
            # Windows builds, since otherwise Git claims that the path is in a .gitignore
            # file.
            @test success(`git submodule add $(path_repo) repository`)
            @test success(`git add -A`)
            @test success(`git commit -m"Initial commit."`)
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

    # This test checks that deprecation warnings are captured correctly
    @static if isdefined(Base, :with_logger)
        @testset "withoutput" begin
            _, _, _, output = Documenter.Utilities.withoutput() do
                println("println")
                @info "@info"
                f() = (Base.depwarn("depwarn", :f); nothing)
                f()
            end
            # The output is dependent on whether the user is running tests with deprecation
            # warnings enabled or not. To figure out whether that is the case or not, we can
            # look at the .depwarn field of the undocumented Base.JLOptions object.
            @test isdefined(Base, :JLOptions)
            @test hasfield(Base.JLOptions, :depwarn)
            if Base.JLOptions().depwarn == 0 # --depwarn=no, default on Julia >= 1.5
                @test output == "println\n[ Info: @info\n"
            else # --depwarn=yes
                @test startswith(output, "println\n[ Info: @info\n┌ Warning: depwarn\n")
            end
        end
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

        @info "Expected error output:"
        @test_throws ArgumentError mdparse("!!! adm", mode=:span)
        @test_throws ArgumentError mdparse("x\n\ny")
        @test_throws ArgumentError mdparse("x\n\ny", mode=:span)
        @info ".. end of expected error output."
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
end

end
