module ExceptTests
using Test
using Documenter: except, ERROR_NAMES

@testset "Documenter.except" begin
    @test_throws DomainError except(:foobar)
    @test_throws MethodError except([:linkcheck])
    @test sort(except()) == sort(ERROR_NAMES)
    @test sort(except(:linkcheck)) == sort(filter(!isequal(:linkcheck), ERROR_NAMES))
    @test isempty(except(ERROR_NAMES...))
end

end
