# build pdf version of Documenter's docs on 64-bit Linux
if Sys.ARCH === :x86_64 && Sys.KERNEL === :Linux
    cd(joinpath(@__DIR__, "..", "..")) do
        cmd = `$(Base.julia_cmd()) --project=docs/pdf/`
        @test success(`$(cmd) -e 'using Pkg; Pkg.instantiate()'`)
        @test success(`$(cmd) docs/pdf/make.jl --verbose`)
        # deploy only from Julia v1.0.X
        if VERSION.major == 1 && VERSION.minor == 1
            @test success(`$(cmd) docs/pdf/deploy.jl`)
        end
    end
end
