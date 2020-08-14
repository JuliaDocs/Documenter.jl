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

## Issue 1401

1. The output is a latex tabular environment

```@example
using DataFrames
DataFrame(i=1:3, y='A':'C')
```

2. The paragraph itself is a latex tabular environment

\begin{tabular}{r|ccc}
        & i & y & z\\
        \hline
        & Int64 & Char & Int64\\
        \hline
        1 & 1 & 'A' & 5 \\
        2 & 2 & 'B' & 6 \\
        3 & 3 & 'C' & 7 \\
        4 & 4 & 'D' & 8 \\
\end{tabular}

