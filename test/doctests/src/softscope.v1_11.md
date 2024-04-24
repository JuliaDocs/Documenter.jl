Julia 1.5's REPL softscope

```jldoctest
julia> s = 0 # global
0

julia> for i = 1:10
           t = s + i # new local `t`
           s = t # assign global `s`
       end

julia> s # global
55

julia> @isdefined(t) # global
false
```

```@meta
DocTestFilters = [
    # replace filenames and line numbers in stacktraces
    # (mostly to handle path separator differences)
    r"   @ .+:([0-9]+)" => "   @ {FILEPATH}:{LINE}",
    # remove file paths from at-block URLs
    r"└ @ .+:[0-9]+",
]
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
┌ Warning: Assignment to `s` in soft scope is ambiguous because a global variable by the same name exists: `s` will be treated as a new local. Disambiguate by using `local s` to suppress this warning or `global s` to assign to the existing global variable.
└ @ string:4
ERROR: LoadError: UndefVarError: `s` not defined in local scope
Suggestion: check for an assignment to a local variable that shadows a global of the same name.
Stacktrace:
 [1] top-level scope
   @ ./string:3
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

┌ Warning: Assignment to `s` in soft scope is ambiguous because a global variable by the same name exists: `s` will be treated as a new local. Disambiguate by using `local s` to suppress this warning or `global s` to assign to the existing global variable.
└ @ doctests.jl:3
ERROR: UndefVarError: `s` not defined in local scope
Suggestion: check for an assignment to a local variable that shadows a global of the same name.
Stacktrace:
 [1] top-level scope
   @ ./none:2
[...]
```

```@meta
DocTestFilters = nothing
```
