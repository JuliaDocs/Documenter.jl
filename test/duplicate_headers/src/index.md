# Duplicate header tests

Reduced from https://github.com/JuliaDocs/Documenter.jl/issues/2668.

```@docs
-(::Main.DuplicateHeaderContent.MyStruct)
Main.DuplicateHeaderContent.Stepsize
```

A reference to the ambiguous header: [Blow-Ups](@ref).

A docstring reference whose name collides with the ambiguous header: [`Main.DuplicateHeaderContent.Stepsize`](@ref).
