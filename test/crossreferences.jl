module CrossReferencesTests
using Documenter: CrossReferences
using Test

@testset "CrossReferences" begin
    @test CrossReferences.xrefname("") === nothing
    @test CrossReferences.xrefname("@") === nothing
    @test CrossReferences.xrefname("@re") === nothing
    @test CrossReferences.xrefname("@refx") === nothing
    @test CrossReferences.xrefname("@ref#") === nothing
    @test CrossReferences.xrefname("@ref_") === nothing
    # basic at-refs
    @test CrossReferences.xrefname("@ref") == ""
    @test CrossReferences.xrefname("@ref ") == ""
    @test CrossReferences.xrefname("@ref     ") == ""
    @test CrossReferences.xrefname("@ref\t") == ""
    @test CrossReferences.xrefname("@ref\t  ") == ""
    @test CrossReferences.xrefname("@ref \t") == ""
    @test CrossReferences.xrefname(" @ref") == ""
    @test CrossReferences.xrefname(" \t@ref") == ""
    # named at-refs
    @test CrossReferences.xrefname("@ref foo") == "foo"
    @test CrossReferences.xrefname("@ref      foo") == "foo"
    @test CrossReferences.xrefname("@ref  foo  ") == "foo"
    @test CrossReferences.xrefname("@ref \t foo \t ") == "foo"
    @test CrossReferences.xrefname("@ref\tfoo") == "foo"
    @test CrossReferences.xrefname("@ref foo%bar") == "foo%bar"
    @test CrossReferences.xrefname("@ref  foo bar  \t baz   ") == "foo bar  \t baz"
    @test CrossReferences.xrefname(" \t@ref  foo") == "foo"
end

end
