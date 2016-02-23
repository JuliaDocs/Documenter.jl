# Tutorial

[Documentation]({ref})

[Index]({ref})

[Functions]({ref})

[`Main.Mod.func(x)`]({ref})

[`Main.Mod.T`]({ref})

```julia
julia> a = 1
1

julia> b = 2;

julia> a + b
3
```

```julia
a = 1
b = 2
a + b

# output

3
```

```julia
srand(1)
A = rand(3, 3)
b = 1:3
A \ b

# output

3-element Array{Float64,1}:
 11.1972
 -0.32122
 -1.72323
```

```julia
julia> srand(1);

julia> A = rand(3, 3)
3x3 Array{Float64,2}:
 0.236033  0.00790928  0.951916
 0.346517  0.488613    0.999905
 0.312707  0.210968    0.251662

julia> b = 1:3
3-element UnitRange{Int64}:
 1,2,3

julia> A \ b
3-element Array{Float64,1}:
 11.1972
 -0.32122
 -1.72323
```
