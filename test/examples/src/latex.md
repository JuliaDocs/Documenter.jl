# LaTeX MWEs

## `ContentsNode` level jumps

```@contents
Pages = ["latex.md"]
Depth = 9000
```

#### Level 4
## Level 2 again
### Level 3

## Empty `ContentsNode` and `IndexNode`

```@contents
Pages = ["does-not-exist.md"]
```

```@index
Pages = ["does-not-exist.md"]
```

## Issue 1119

```julia
1 % 2
1 ⊻ 2
1 | 2
```
