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
```jldoctest
# Leading comment
julia> a
ERROR: UndefVarError: `a` not defined in `Main`
Suggestion: check for spelling errors or missing imports.

julia> a = Int64[1,2]
2-element Vector{Int64}:
 1
 2

julia> b
ERROR: UndefVarError: `b` not defined in `Main`
Suggestion: check for spelling errors or missing imports.

julia> a
2-element Vector{Int64}:
 1
 2

julia> a;

julia> b;
ERROR: UndefVarError: `b` not defined in `Main`
Suggestion: check for spelling errors or missing imports.

julia> a = Int64[3,4];

julia> a
2-element Vector{Int64}:
 3
 4
```
```jldoctest
julia> a = ("a", "b", "c");

julia> a
("a", "b", "c")
```
```jldoctest
julia> :a / :b
ERROR: MethodError: no method matching /(::Symbol, ::Symbol)
[...]
```
