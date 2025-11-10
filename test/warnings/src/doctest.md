# Test warnings in `jldoctest` block

Warning about leading empty line
```jldoctest

julia> 1+1
2
```

Warning about missing line between two prompts
```jldoctest
julia> a=1;
julia> a+1
2
```
