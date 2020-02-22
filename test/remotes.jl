module RemoteTests
using Test
using Documenter.Utilities: repofile, StringRemote, GitHub
#using Documenter.Utilities: reporoot

@testset "RepositoryRemote" begin
    #r = StringRemote("https://github.com/FOO/BAR", "https://github.com/FOO/BAR/blob/{commit}{path}#{line}")
    #@test reporoot(r) == "https://github.com/FOO/BAR"
    r = StringRemote("https://github.com/FOO/BAR/blob/{commit}{path}#{line}")
    @test repofile(r, "master", "src/foo.jl") == "https://github.com/FOO/BAR/blob/master/src/foo.jl#"
    @test repofile(r, "master", "src/foo.jl", 5:5) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L5"
    @test repofile(r, "master", "src/foo.jl", 10) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L10"
    @test repofile(r, "master", "src/foo.jl", 5:15) == "https://github.com/FOO/BAR/blob/master/src/foo.jl#L5-L15"

    # Default linerange formatting is GitHub-style
    #r = StringRemote("https://example.org/X", "http://example.org/{commit}/x{path}?lines={line}")
    #@test reporoot(r) == "https://example.org/X"
    r = StringRemote("http://example.org/{commit}/x{path}?lines={line}")
    @test repofile(r, "123abc", "src/foo.jl") == "http://example.org/123abc/x/src/foo.jl?lines="
    @test repofile(r, "123abc", "src/foo.jl", 5:5) == "http://example.org/123abc/x/src/foo.jl?lines=L5"
    @test repofile(r, "123abc", "src/foo.jl", 5:15) == "http://example.org/123abc/x/src/foo.jl?lines=L5-L15"

    # Different line range formatting for URLs containing 'bitbucket'
    #r = StringRemote("https://bitbucket.org/foo/bar/", "https://bitbucket.org/foo/bar/src/{commit}{path}#lines-{line}")
    #@test reporoot(r) == "https://bitbucket.org/foo/bar/"
    r = StringRemote("https://bitbucket.org/foo/bar/src/{commit}{path}#lines-{line}")
    @test repofile(r, "mybranch", "src/foo.jl") == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-"
    @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-5"
    @test repofile(r, "mybranch", "src/foo.jl", 5:15) == "https://bitbucket.org/foo/bar/src/mybranch/src/foo.jl#lines-5:15"

    # Different line range formatting for URLs containing 'gitlab'
    #r = StringRemote("https://gitlab.mydomain.eu/foo/bar/", "https://gitlab.mydomain.eu/foo/bar/-/blob/{commit}{path}#{line}")
    #@test reporoot(r) == "https://gitlab.mydomain.eu/foo/bar/"
    r = StringRemote("https://gitlab.mydomain.eu/foo/bar/-/blob/{commit}{path}#{line}")
    @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl") == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#"
    @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:5) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5"
    @test repofile(r, "v1.2.3-rc3+foo", "src/foo.jl", 5:15) == "https://gitlab.mydomain.eu/foo/bar/-/blob/v1.2.3-rc3+foo/src/foo.jl#L5-15"

    # GitHub remote
    r = GitHub("JuliaDocs", "Documenter.jl")
    #@test reporoot(r) == "https://github.com/JuliaDocs/Documenter.jl"
    @test repofile(r, "mybranch", "src/foo.jl") == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl"
    @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
    @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
    @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5-L8"

    r = GitHub("JuliaDocs/Documenter.jl")
    #@test reporoot(r) == "https://github.com/JuliaDocs/Documenter.jl"
    @test repofile(r, "mybranch", "src/foo.jl") == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl"
    @test repofile(r, "mybranch", "src/foo.jl", 5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
    @test repofile(r, "mybranch", "src/foo.jl", 5:5) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5"
    @test repofile(r, "mybranch", "src/foo.jl", 5:8) == "https://github.com/JuliaDocs/Documenter.jl/blob/mybranch/src/foo.jl#L5-L8"
end

end # module
