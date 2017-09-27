# Documentation

## Index Page

```@contents
Pages = ["index.md"]
Depth = 5
```

## Functions Contents

```@contents
Pages = ["lib/functions.md"]
Depth = 3
```

## Tutorial Contents

```@contents
Pages = ["man/tutorial.md"]
```

## Index

```@index
```

### Embedded `@ref` links headers: [`ccall`](@ref)

[#60](@ref) [#61](@ref)

```@repl
zeros(5, 5)
zeros(50, 50)
```

```@meta
DocTestSetup = quote
    using Base
    x = -3:0.01:3
    y = -4:0.02:5
    z = [Float64((xi^2 + yi^2)) for xi in x, yi in y]
end
```

```jldoctest
julia> [1.0, 2.0, 3.0]
3-element Array{Float64,1}:
 1.0
 2.0
 3.0

```

```jldoctest
julia> println(" "^5)

julia> "\nfoo\n\nbar\n\n\nbaz"
"\nfoo\n\nbar\n\n\nbaz"

julia> println(ans)

foo

bar


baz
```

```jldoctest
julia> info("...")
INFO: ...

```

  * `one` two three
  * four `five` six

  * ```
    one
    ```

## Raw Blocks

```@raw html
<center class="raw-html-block">
    <strong>CENTER</strong>
</center>
```

```@raw latex
\begin{verbatim}
```

```@raw latex
\end{verbatim}
```

# Symbols in doctests

```jldoctest
julia> a = :undefined
:undefined

julia> a
:undefined
```

# Named doctests

```jldoctest test-one
julia> a = 1
1
```

```jldoctest test-one
julia> a + 1
2
```

# Sanitise module names

```jldoctest
julia> type T end

julia> t = T()
T()

julia> fullname(current_module())
()

julia> fullname(Base.Pkg)
(:Base,:Pkg)

julia> current_module()
Main
```

# Issue398

```@meta
DocTestSetup = quote
    using Issue398
end
```

```jldoctest
julia> @define_show_and_make_object q "abcd"
abcd
```

# Issue418

```jldoctest
julia> f(x::Float64) = x
f (generic function with 1 method)

julia> f("")
ERROR: MethodError: no method matching f(::String)
Closest candidates are:
  f(!Matched::Float64) at none:1
```


```jldoctest
julia> a = 1
1

julia> b = 2
2

julia> ex = :(a + b)
:(a + b)

julia> eval(ex)
3
```


```jldoctest
julia> a = 1
1

julia> ans
1
```

# Issue513

```jldoctest named
julia> a = 1
1

julia> ans
1
```

# Bad links (Windows)

* [Colons not allowed on Windows -- `some:path`](some:path)
* [No "drive" -- `:path`](:path)
* [Absolute Windows paths -- `X:\some\path`](X:\some\path)
