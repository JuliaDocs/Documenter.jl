```@docs
DocTestFixTest.Foo.foo
```

```jldoctest
julia> Main.DocTestFixArray_2468
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8

julia> Main.DocTestFixArray_1234
4×1×1 Array{Int64,3}:
[:, :, 1] =
 1
 2
 3
 4
```
```jldoctest
julia> Main.DocTestFixArray_1234
4×1×1 Array{Int64,3}:
[:, :, 1] =
 1
 2
 3
 4

julia> Main.DocTestFixArray_2468
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
julia> Main.DocTestFixArray_2468
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8

julia> Main.DocTestFixArray_2468
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
julia> begin
          Main.DocTestFixArray_2468
       end
4×1×1 Array{Int64,3}:
[:, :, 1] =
 2
 4
 6
 8
```
```jldoctest
Main.DocTestFixArray_2468

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
```jldoctest
julia> a = (1,2)
(1, 2)

julia> a
(1, 2)
```
