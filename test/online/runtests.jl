using Test

@testset "Online Tests" begin
    include("online_linkcheck.jl")
    include("online_githubcheck.jl")
end
