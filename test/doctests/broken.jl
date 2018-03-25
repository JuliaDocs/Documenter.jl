module Foo
"""
```jldoctest
julia> Int64[1, 2, 3, 4] * 2
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> Int64[1, 2, 3, 4]
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> Int64[1, 2, 3, 4]
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> Int64[1, 2, 3, 4] * 2
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> Int64[1, 2, 3, 4] * 2
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> Int64[1, 2, 3, 4] * 2
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
julia> begin
          Int64[1, 2, 3, 4] * 2
       end
4-element Array{Int64,1}:
 1
 2
 3
 4
```
```jldoctest
Int64[1, 2, 3, 4] * 2

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
"""
foo() = 1

    """
    ```jldoctest
    julia> begin
              Int64[1, 2, 3, 4] * 2
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
