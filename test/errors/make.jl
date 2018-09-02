module ErrorsModule

"""
```jldoctest
julia> a = 1
2

```

```jldoctest
```
"""
func(x) = x

end

using Documenter

makedocs(sitename="-", modules = [ErrorsModule])

@test_throws ErrorException makedocs(modules = [ErrorsModule], strict = true)
