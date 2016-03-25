
    {meta}
    CurrentModule = Main.Mod

# Function Index

    {index}
    Pages = ["lib/functions.md"]

# Functions

[`:ccall`]({ref}), [`func(x)`]({ref}), [`T`]({ref}), [`:for`]({ref}), and [`:while`]({ref}).

    {docs}
    func(x)
    T
    :ccall
    :for
    :while
    @time(x)
    @assert

# Foo

```julia
{example}
@show pwd()
a = 1
```

...

```julia
{example}
isdefined(:a)
```

```julia
{example 1}
f(x) = 2x
g(x) = 3x
nothing # hide
```

```julia
{example 2}
x, y = 1, 2
println(x, y)
```

```julia
{example 3}
type T end
t = T()
```

## Foo

```julia
{example 3}
isdefined(:T)
@show isdefined(:t) # hide
@show typeof(T)
typeof(t) # hide
```

```julia
{example 2}
x + y
```

```julia
{example 1}
f(2), g(2)
```

### Foo

```julia
{example 2}
x - y
```

```julia
{example 1}
f(1), g(1)
```

```julia
{example 3}
@which T()
```

#### Foo
