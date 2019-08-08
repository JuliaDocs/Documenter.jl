module HTMLWriterTests

using Test
using Documenter.Writers.HTMLWriter: HTMLWriter, generate_version_file, expand_versions

function verify_version_file(versionfile, entries)
    @test isfile(versionfile)
    content = read(versionfile, String)
    idx = 1
    for entry in entries
        i = findnext(entry, content, idx)
        @test i !== nothing
        idx = last(i)
    end
end

@testset "HTMLWriter" begin
    @test isdir(HTMLWriter.ASSETS)
    @test isdir(HTMLWriter.ASSETS_SASS)
    @test isdir(HTMLWriter.ASSETS_THEMES)

    for theme in HTMLWriter.THEMES
        @test isfile(joinpath(HTMLWriter.ASSETS_SASS, "$(theme).scss"))
        @test isfile(joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css"))
    end

    mktempdir() do tmpdir
        versionfile = joinpath(tmpdir, "versions.js")
        versions = ["stable", "dev",
                    "2.1.1", "v2.1.0", "v2.0.1", "v2.0.0",
                    "1.1.1", "v1.1.0", "v1.0.1", "v1.0.0",
                    "0.1.1", "v0.1.0"] # note no `v` on first ones
        cd(tmpdir) do
            for version in versions
                mkdir(version)
            end
        end

        # expanding versions
        versions = ["stable" => "v^", "v#.#", "dev" => "dev"] # default to makedocs
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["stable", "v2.1", "v2.0", "v1.1", "v1.0", "v0.1", "dev"]
        @test symlinks == ["stable"=>"2.1.1", "v2.1"=>"2.1.1", "v2.0"=>"v2.0.1",
                           "v1.1"=>"1.1.1", "v1.0"=>"v1.0.1", "v0.1"=>"0.1.1",
                           "v2"=>"2.1.1", "v1"=>"1.1.1", "v2.1.1"=>"2.1.1",
                           "v1.1.1"=>"1.1.1", "v0.1.1"=>"0.1.1"]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)

        versions = ["v#"]
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["v2.1", "v1.1"]
        @test symlinks == ["v2.1"=>"2.1.1", "v1.1"=>"1.1.1", "v2"=>"2.1.1", "v1"=>"1.1.1",
                           "v2.0"=>"v2.0.1", "v1.0"=>"v1.0.1", "v0.1"=>"0.1.1",
                           "v2.1.1"=>"2.1.1", "v1.1.1"=>"1.1.1", "v0.1.1"=>"0.1.1"]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)

        versions = ["v#.#.#"]
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["v2.1.1", "v2.1.0", "v2.0.1", "v2.0.0", "v1.1.1", "v1.1.0",
                          "v1.0.1", "v1.0.0", "v0.1.1", "v0.1.0"]
        @test symlinks == ["v2.1.1"=>"2.1.1", "v1.1.1"=>"1.1.1", "v0.1.1"=>"0.1.1",
                           "v2"=>"2.1.1", "v1"=>"1.1.1", "v2.1"=>"2.1.1",
                           "v2.0"=>"v2.0.1", "v1.1"=>"1.1.1", "v1.0"=>"v1.0.1", "v0.1"=>"0.1.1"]
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)

        versions = ["v^", "devel" => "dev", "foobar", "foo" => "bar"]
        entries, symlinks = expand_versions(tmpdir, versions)
        @test entries == ["v2.1", "devel"]
        @test ("v2.1" => "2.1.1") in symlinks
        @test ("devel" => "dev") in symlinks
        generate_version_file(versionfile, entries)
        verify_version_file(versionfile, entries)

        versions = ["stable" => "v^", "dev" => "stable"]
        @test_throws ArgumentError expand_versions(tmpdir, versions)
    end
end

end
