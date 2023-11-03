module InvalidLinksTests
using Test
using Documenter
import IOCapture


module InvalidLinks
    export f

    """Link to [invalid](http://domain.invalid/docstring.html)"""
    f(x) = x

end


@testset "invalid links" begin
    c = IOCapture.capture(; rethrow=Union{}) do
        makedocs(;
            root = dirname(@__FILE__),
            modules = InvalidLinks,
            sitename = "InvalidLinks Checks",
            warnonly = false,
            linkcheck=true,
            debug=false
        )
    end
    @test contains(c.output, r"Error:.*http://domain.invalid/index.html")
    @test_broken contains(c.output, r"Error:.*http://domain.invalid/docstring.html")
    @test c.value isa ErrorException
    @test contains(c.value.msg, "`makedocs` encountered an error [:linkcheck]")
end

end
