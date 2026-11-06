# Negative test: module with syntax version set to 1.13
# Verifies that the parser actually respects the older syntax version

module SyntaxVersioning13

Base.set_syntax_version(@__MODULE__, v"1.13")

"""
Labeled break syntax requires Julia 1.14, so it must not parse with syntax version 1.13.

```jldoctest
julia> @label myblock begin
           break myblock 1
       end
ERROR: ParseError:
[...]
```
"""
function check_syntax_version end

end # module
