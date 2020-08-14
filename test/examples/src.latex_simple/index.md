# Simple LaTeX build

This build only contains a single paragraph of text to make sure that a
near-empty LaTeX builds passes.

```julia-repl
julia> 127 % Int8
127
```
## Issue 1119

```julia
1 % 2
1 ⊻ 2
1 | 2
```

## Escaping: ~, ^, \, ', ", _, &, %, \, $, #, { and }.

~, ^, \, ', ", _, &, %, \, $, #, { and }.

!!! info "~, ^, \, ', ", _, &, %, \, $, #, { and }."

    ~, ^, \, ', ", _, &, %, \, $, #, { and }.

## Issue 1392

```julia-repl sayhello2
julia> function foo end;
```
