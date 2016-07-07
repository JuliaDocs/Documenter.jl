
```@meta
CurrentModule = Main.Mod
```

# Function Index

```@index
Pages = ["lib/functions.md"]
```

# Functions

[`:ccall`](@ref), [`func(x)`](@ref), [`T`](@ref), [`:for`](@ref), and [`:while`](@ref).

```@docs
func(x)
T
:ccall
:for
:while
@time
@assert
```

# Foo

```@example
@show pwd()
a = 1
```

...

```@example
isdefined(:a)
```

```@example 1
f(x) = 2x
g(x) = 3x
nothing # hide
```

```@example 2
x, y = 1, 2
println(x, y)
```

```@example 3
type T end
t = T()
```

## Foo

```@example 3
isdefined(:T)
@show isdefined(:t) # hide
@show typeof(T)
typeof(t) # hide
```

```@example 2
x + y
```

```@example 1
f(2), g(2)
```

### Foo

```@example 2
x - y
```

```@example 1
f(1), g(1)
```

```@example 3
@which T()
```

#### Foo

```@example
a = 1
b = ans
@assert a === b
```

```@repl
srand(1); # hide
nothing
rand()
a = 1
println(a)
b = 2
a + b
type T
    x :: Int
    y :: Vector
end
x = T(1, [1])
x.y
x.x
```

```@repl 1
d = 1
```

```@repl 1
println(d)
```

# Autodocs

```@meta
CurrentModule = Main
```

## AutoDocs Module

```@autodocs
Modules = [AutoDocs]
```

## Functions, Modules, and Macros

```@autodocs
Modules = [AutoDocs.A, AutoDocs.B]
Order   = [:function, :module, :macro]
```

## Constants and Types

```@autodocs
Modules = [AutoDocs.A, AutoDocs.B]
Order   = [:constant, :type]
```
