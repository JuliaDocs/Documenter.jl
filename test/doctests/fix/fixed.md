```@docs
DocTestFixTest.Foo.foo
```

```jldoctest
julia> reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8

julia> reshape(Int64[1, 2, 3, 4], (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 1
 2
 3
 4
```
```jldoctest
julia> reshape(Int64[1, 2, 3, 4], (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 1
 2
 3
 4

julia> reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
julia> reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8

julia> reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
julia> begin
          reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))
       end
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
reshape(Int64[1, 2, 3, 4] * 2, (4,1,1))

# output

4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest; filter = r"foo"
julia> println("  foobar")
  foobar
```
```jldoctest
julia> 1 + 2
3

julia> 3 + 4
7
```
