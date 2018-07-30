module HTMLWriterTests

using Test
using Compat

import Documenter.Writers.HTMLWriter: jsescape, generate_version_file

@testset "HTMLWriter" begin
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

    mktempdir() do tmpdir
        versions = ["stable", "latest", "release-0.2", "release-0.1", "v0.2.6", "v0.1.1", "v0.1.0"]
        cd(tmpdir) do
            mkdir("foobar")
            for version in versions
                mkdir(version)
            end
        end

        generate_version_file(tmpdir)

        versions_file = joinpath(tmpdir, "versions.js")
        @test isfile(versions_file)
        contents = String(read(versions_file))
        @test !occursin("foobar", contents) # only specific directories end up in the versions file
        # let's make sure they're in the right order -- they should be sorted in the output file
        last = 0:0
        for version in versions
            this = Compat.findfirst(version, contents)
            @test this !== nothing
            @test first(last) < first(this)
            last = this
        end
    end
end

end
