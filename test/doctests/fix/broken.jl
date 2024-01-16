module Foo
"""
```jldoctest
julia> Main.DocTestFixArray_2468
4×1×1 Array{Int64,3}:
[:, :, 1] =
 1
 2
 3
 4

julia> Main.DocTestFixArray_1234
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> Main.DocTestFixArray_1234
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> Main.DocTestFixArray_2468
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> Main.DocTestFixArray_2468
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> Main.DocTestFixArray_2468
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> begin
           Main.DocTestFixArray_2468
       end
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
Main.DocTestFixArray_2468

# output

4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest; filter = r"foo"
julia> println("  foobar")
  foobaz
```
```jldoctest
julia> 1 + 2

julia> 3 + 4
```
"""
foo() = 1

"""
```jldoctest
julia> begin
           Main.DocTestFixArray_2468
       end
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> println(); println("foo")

bar
```
"""
foo(x) = 1

end # module
