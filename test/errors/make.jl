module ErrorsModule

"""
```julia
julia> a = 1
2

```
"""
func(x) = x

end

using Documenter

makedocs(modules = [ErrorsModule])
