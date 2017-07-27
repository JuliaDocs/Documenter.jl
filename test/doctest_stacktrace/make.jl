module ErrorsModule

"""
    f()

This function throws an exception

```jldoctest
julia> using ErrorsModule

julia> ErrorsModule.f()
ERROR:
Stacktrace:
 [1] f() at ./make.jl:666666666666666666

julia> 1 + 1
2
```
"""
f() = throw(ErrorException(""))

end

using Documenter

makedocs(modules = [ErrorsModule], doctest_stacktraces = false)
