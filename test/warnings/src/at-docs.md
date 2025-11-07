# Test warnings in `@docs` block

Binding that does not exist.
```@docs
Base.nonsenseBindingThatDoesNotExist()
```

Binding that exists but has no documentation.
```@docs
Base.sin()
```

Syntax error due to invalid type in argument list.
```@docs
Base.sin(::NonsenseTypeThatDoesNotExist)
```
