# Negative test: module with syntax version set to 1.13
# Verifies that the parser actually respects the older syntax version

module SyntaxVersioning13

Base.Experimental.@set_syntax_version v"1.13"

"""
Verify that the syntax version is 1.13, not 1.14.

```jldoctest
julia> (Base.Experimental.@VERSION).syntax == v"1.13"
true
```
"""
function check_syntax_version end

end # module
