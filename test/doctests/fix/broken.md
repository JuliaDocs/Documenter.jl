```@docs
DocTestFixTest.Foo.foo
```

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
```jldoctest
julia> a = (1,2)

julia> a
```
```jldoctest
# Leading comment
julia> a
ERROR: UndefVarError: `a` not defined

julia> a = Int64[1,2]
2-element Vector{Int64}:
 1
 2

julia> b

julia> a
2-element Vector{Int64}:
 2

julia> a;
1

julia> b;

julia> a = Int64[3,4];

julia> a
 3
 4
```
```jldoctest
julia> a = ("a", "b", "c");

julia> a
```
```jldoctest
julia> :a / :b
ERROR: MethodError: no method matching /(::Symbol, ::Symbol)
[...]
```
