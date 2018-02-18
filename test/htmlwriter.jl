module HTMLWriterTests

using Compat.Test
using Compat

import Documenter.Writers.HTMLWriter: jsescape

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
end

end
