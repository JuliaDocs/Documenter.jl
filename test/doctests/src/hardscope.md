REPL scoping behaviour when Julia < 1.5

```@meta
DocTestFilters = [
    # remove stacktraces
    r"Stacktrace:(\n \[[0-9]+\].*)*",
    # remove file paths from at-block URLs
    r"└ @ .+:[0-9]+"
]
```

```jldoctest
julia> s = 0 # global
0

julia> for i = 1:10
           t = s + i # new local `t`
           s = t # assign global `s`
       end
ERROR: UndefVarError: s not defined
Stacktrace:
 [1] top-level scope at ./none:2
[...]
```

```jldoctest
julia> code = """
       s = 0 # global
       for i = 1:10
           t = s + i # new local `t`
           s = t # new local `s` with warning
       end
       s, # global
       @isdefined(t) # global
       """;

julia> include_string(Main, code)
ERROR: LoadError: UndefVarError: s not defined
Stacktrace:
 [1] top-level scope at ./string:3
[...]
```

```jldoctest
s = 0 # global
for i = 1:10
    t = s + i # new local `t`
    s = t # new local `s` with warning
end
s, # global
@isdefined(t) # global

# output

ERROR: UndefVarError: s not defined
Stacktrace:
 [1] top-level scope at ./none:2
[...]
```

```@meta
DocTestFilters = nothing
```
