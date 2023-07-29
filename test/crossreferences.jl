module CrossReferencesTests
import Documenter
using Test

@testset "CrossReferences" begin
    @test Documenter.xrefname("") === nothing
    @test Documenter.xrefname("@") === nothing
    @test Documenter.xrefname("@re") === nothing
    @test Documenter.xrefname("@refx") === nothing
    @test Documenter.xrefname("@ref#") === nothing
    @test Documenter.xrefname("@ref_") === nothing
    # basic at-refs
    @test Documenter.xrefname("@ref") == ""
    @test Documenter.xrefname("@ref ") == ""
    @test Documenter.xrefname("@ref     ") == ""
    @test Documenter.xrefname("@ref\t") == ""
    @test Documenter.xrefname("@ref\t  ") == ""
    @test Documenter.xrefname("@ref \t") == ""
    @test Documenter.xrefname(" @ref") == ""
    @test Documenter.xrefname(" \t@ref") == ""
    # named at-refs
    @test Documenter.xrefname("@ref foo") == "foo"
    @test Documenter.xrefname("@ref      foo") == "foo"
    @test Documenter.xrefname("@ref  foo  ") == "foo"
    @test Documenter.xrefname("@ref \t foo \t ") == "foo"
    @test Documenter.xrefname("@ref\tfoo") == "foo"
    @test Documenter.xrefname("@ref foo%bar") == "foo%bar"
    @test Documenter.xrefname("@ref  foo bar  \t baz   ") == "foo bar  \t baz"
    @test Documenter.xrefname(" \t@ref  foo") == "foo"
end

end
