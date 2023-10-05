module RemoteTests
using Test
using Documenter
using .Remotes: repofile, repourl, issueurl, URL, GitHub, GitLab

@testset "RepositoryRemote" begin
    let r = URL("https://github.com/FOO/BAR/blob/{commit}{path}#{line}")
        @test repourl(r) === nothing
        @test repofile(r, "master", "src/foo.jl") == "https://github.com/FOO/BAR/blob/master/src/foo.jl#"
        @test repofile(r, "master", "src/foo.jl", 5:5) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L5"
        @test repofile(r, "master", "src/foo.jl", 10) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L10"
        @test repofile(r, "master", "src/foo.jl", 5:15) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L5-L15"
        @test issueurl(r, "123") === nothing
    end

    # Default linerange formatting is GitHub-style
    let r = URL("http://example.org/{commit}/x{path}?lines={line}", "https://example.org/X")
        @test repourl(r) == "https://example.org/X"
        @test repofile(r, "123abc", "src/foo.jl") == "http://example.org/123abc/x/src/foo.jl?lines="
        @test repofile(r, "123abc", "src/foo.jl", 5:5) == "http://example.org/123abc/x/src/foo.jl?lines=L5"
        @test repofile(r, "123abc", "src/foo.jl", 5:15) == "http://example.org/123abc/x/src/foo.jl?lines=L5-L15"
        @test issueurl(r, "123") === nothing
    end

    # Different line range formatting for URLs containing 'bitbucket'
    let r = URL("https://bitbucket.org/foo/bar/src/{commit}{path}#lines-{line}")
        @test repourl(r) === nothing
        @test repofile(r, "mybranch", "src/foo.jl") == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:15) == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-5:15"
        @test issueurl(r, "123") === nothing
    end

    # Different line range formatting for URLs containing 'gitlab'
    let r = URL("https://gitlab.mydomain.eu/foo/bar/-/blob/{commit}{path}#{line}", "https://gitlab.mydomain.eu/foo/bar/")
        @test repourl(r) == "https://gitlab.mydomain.eu/foo/bar/"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl") == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:5) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:15) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5-15"
        @test issueurl(r, "123") === nothing
    end

    # Different line range formatting for URLs containing 'azure'
    let r = URL("https://gitlab.mydomain.eu/foo/bar/-/blob/{commit}{path}#{line}", "https://gitlab.mydomain.eu/foo/bar/")
        @test repourl(r) == "https://gitlab.mydomain.eu/foo/bar/"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl") == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:5) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5"
        @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:15) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5-15"
        @test issueurl(r, "123") === nothing
    end

    # GitHub remote
    let r = GitHub("JuliaDocs", "Documenter.jl")
        @test repourl(r) == "https://github.com/JuliaDocs/Documenter.jl"
        @test repofile(r, "mybranch", "src/foo.jl") == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl"
        @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5-L8"
        @test issueurl(r, "123") == "https://github.com/JuliaDocs/Documenter.jl/issues/123"
    end

    let r = GitHub("JuliaDocs/Documenter.jl")
        @test repourl(r) == "https://github.com/JuliaDocs/Documenter.jl"
        @test repofile(r, "mybranch", "src/foo.jl") == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl"
        @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5-L8"
        @test issueurl(r, "123") == "https://github.com/JuliaDocs/Documenter.jl/issues/123"
    end

    # GitLab remote
    let r = GitLab("JuliaDocs", "Documenter.jl")
        @test repourl(r) == "https://gitlab.com/JuliaDocs/Documenter.jl"
        @test repofile(r, "mybranch", "src/foo.jl") == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl"
        @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5-L8"
        @test issueurl(r, "123") == "https://gitlab.com/JuliaDocs/Documenter.jl/-/issues/123"
    end

    let r = GitLab("my-gitlab.com", "JuliaDocs", "Documenter.jl")
        @test repourl(r) == "https://my-gitlab.com/JuliaDocs/Documenter.jl"
        @test repofile(r, "mybranch", "src/foo.jl") == "https://my-gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl"
        @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://my-gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://my-gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://my-gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5-L8"
        @test issueurl(r, "123") == "https://my-gitlab.com/JuliaDocs/Documenter.jl/-/issues/123"
    end

    let r = GitLab("JuliaDocs/Documenter.jl")
        @test repourl(r) == "https://gitlab.com/JuliaDocs/Documenter.jl"
        @test repofile(r, "mybranch", "src/foo.jl") == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl"
        @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5"
        @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://gitlab.com/JuliaDocs/Documenter.jl/-/tree/mybranch/src/foo.jl#L5-L8"
        @test issueurl(r, "123") == "https://gitlab.com/JuliaDocs/Documenter.jl/-/issues/123"
    end
end

end # module
