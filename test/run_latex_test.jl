using Test
import Documenter
include("TestUtilities.jl"); using .TestUtilities

@testset "Examples/LaTeX" begin
    @testset "LaTeX backend custom style" begin
        @info "Building LaTeX_backend/cover_page"
        @quietly include("LaTeX_backend/cover_page/make.jl")
        
        @info "Building LaTeX_backend/toc_style"
        @quietly include("LaTeX_backend/toc_style/make.jl")
    end
end
