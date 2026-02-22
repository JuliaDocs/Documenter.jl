# Test module that sets its syntax version to 1.14
# Doctests in this module should automatically use 1.14 syntax

module SyntaxVersioning

# Set this module's syntax version to 1.14
Base.Experimental.@set_syntax_version v"1.14"

"""
Verify that the syntax version is set correctly.

```jldoctest
julia> (Base.Experimental.@VERSION).syntax
v"1.14.0"
```
"""
function check_syntax_version end

"""
This doctest uses labeled break syntax which requires Julia 1.14.
Since the module has its syntax version set, this should work without
needing a `syntax=` annotation.

```jldoctest
julia> result = @label myblock begin
           for i in 1:10
               if i > 5
                   break myblock i * 2
               end
           end
           0
       end
12
```
"""
function labeled_break_example end

"""
This doctest uses labeled continue syntax which requires Julia 1.14.

```jldoctest
julia> output = Int[]
Int64[]

julia> @label outer for i in 1:3
           for j in 1:3
               if j == 2
                   continue outer
               end
               push!(output, i * 10 + j)
           end
       end

julia> output
3-element Vector{Int64}:
 11
 21
 31
```
"""
function labeled_continue_example end

end # module
