
```@meta
CurrentModule = Main.Mod
CollapsedDocStrings = true
```

# Function Index

```@index
Pages = ["lib/functions.md"]
```

# Functions

[`ccall`](@ref), [`func(x)`](@ref), [`T`](@ref), [`for`](@ref), and [`while`](@ref).

```@docs
func(x)
T
ccall
for
while
@time
@assert
```

```@docs; canonical=false
func(x)
T
ccall
for
while
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
@isdefined a
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
struct T end
t = T()
```

```@example hide-all-the-things
a = 1#hide
b = 2# hide
c = 3#  hide
d = 4 #hide
e = 5 # hide
f = 6 #  hide
a + b + c + d + e + f
```

## Foo

```@example 3
@isdefined T
@show @isdefined t # hide
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
using InteractiveUtils
@which T()
```

```@example continued-code
A = 1
```
```@example continued-code; continued = true
for i in 1:3
```
```@example
A = 2
```
```@example continued-code; continued = true
    println(A + i)
```
```@example continued-code
end
```
```@example continued-code
A + 1
```

#### Foo

```@example
a = 1
b = ans
@assert a === b
```

```@repl
using Random    # hide
Random.seed!(1) # hide
nothing
rand()
a = 1
println(a)
b = 2
a + b
struct T
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

Test setup function

```@setup testsetup
w = 5
```

```@example testsetup
@assert w === 5
```

```@repl testsetup
@assert w === 5
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

## Autodocs by Page

```@autodocs
Modules = [AutoDocs.Pages]
Pages = ["a.jl", "b.jl"]
```

```@autodocs
Modules = [AutoDocs.Pages]
Pages = ["c.jl", "d.jl"]
```

A footnote reference [^footnote].

# Named docstring `@ref`s

  * a normal docstring `@ref` link: [`AutoDocs.Pages.f`](@ref);
  * a named docstring `@ref` link: [`f`](@ref AutoDocs.Pages.f);
  * and a link with custom text: [`@time 1 + 2`](@ref @time);
  * some invalid syntax: [`for i = 1:10; ...`](@ref for).
