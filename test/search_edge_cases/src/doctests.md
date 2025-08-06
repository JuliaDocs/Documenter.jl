
# Doctests

This page tests doctests.

## Basic Arithmetic

```jldoctest
julia> 1 + 1
2
```

```jldoctest
julia> 2 + 2
4
```

```jldoctest
julia> 3 + 3
6
```

## String Operations

```jldoctest
julia> uppercase("hello")
"HELLO"

julia> lowercase("WORLD")
"world"

julia> string("test", 123)
"test123"
```

## Array Operations

```jldoctest
julia> [1, 2, 3] .+ 1
3-element Vector{Int64}:
 2
 3
 4

julia> sum([1, 2, 3, 4, 5])
15

julia> length([10, 20, 30])
3
```

## Function Definition and Usage

```jldoctest
julia> function multiply_by_two(x)
           return x * 2
       end
multiply_by_two (generic function with 1 method)

julia> multiply_by_two(5)
10

julia> multiply_by_two(3.5)
7.0
```

## Multiple Similar Examples

```jldoctest
julia> sqrt(4)
2.0

julia> sqrt(9)
3.0

julia> sqrt(16)
4.0
```

## Error Handling Tests

```jldoctest
julia> try
           1 ÷ 0
       catch e
           typeof(e)
       end
DivideError
```
