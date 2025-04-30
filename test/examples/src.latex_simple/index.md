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

## Issue 1401: rendering custom LaTeX

### @example block / show with `text/latex` MIME

```@example
struct Table end

Base.show(io, ::MIME"text/latex", ::Table) = write(io, raw"""
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
""")

Table()
```

### @raw block

```@raw latex
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
```

### Inline LaTeX

_Note: this should render as just text, not as a table._

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

## Printing LaTeX from Julia

To pretty-print LaTeX from Julia, overload `Base.show` for the
`MIME"text/latex"` type. For example:
```@example
struct LaTeXEquation
    content::String
end

function Base.show(io::IO, ::MIME"text/latex", x::LaTeXEquation)
    # Wrap in $$ for display math printing
    return print(io, "\$\$ " * x.content * " \$\$")
end

LaTeXEquation(raw"""
    \left[\begin{array}{c}
        x \\
        y
    \end{array}\right]
""")
```

```@example
struct LaTeXEquation2
    content::String
end

function Base.show(io::IO, ::MIME"text/latex", x::LaTeXEquation2)
    # Wrap in \[...\] for display math printing
    return print(io, "\\[ " * x.content * " \\]")
end

LaTeXEquation2(raw"""
    \left[\begin{array}{c}
        x \\
        y
    \end{array}\right]
""")
```

## `LineBreak` node

This sentence\
should be over **multiple\
lines**.

## Issue 2300

You Shall Not Break! You Shall Not Break! You Shall Not Break!

## PR 2056

Issues: `#1521`, `#2054`, `#2399`

```@repl
x = 1 # hide
x = 2 # hide
println(x)
x
```
