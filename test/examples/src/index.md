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

# Filtered doctests

## Global

```jldoctest
julia> print("Ptr{0x123456}")
Ptr{0x654321}
```

## Local
```@meta
DocTestFilters = [r"foo[a-z]+"]
```

```jldoctest
julia> print("foobar")
foobuu
```

```@meta
DocTestFilters = []
```

## Errors

```@meta
DocTestFilters = [r"Stacktrace:\n \[1\][\s\S]+"]
```

```jldoctest
julia> error()
ERROR:
Stacktrace:
 [1] error() at ./thisfiledoesnotexist.jl:123456789
```


```jldoctest
julia> error()
ERROR:
Stacktrace:
[...]
```

```@meta
DocTestFilters = []
```


# Sanitise module names

```jldoctest
julia> struct T end

julia> t = T()
T()

julia> fullname(current_module())
()

julia> fullname(Base.Pkg)
(:Base, :Pkg)

julia> current_module()
Main
```

# Issue398

```@meta
DocTestSetup = quote
    module Issue398

    struct TestType{T} end

    function _show end
    Base.show(io::IO, t::TestType) = _show(io, t)

    macro define_show_and_make_object(x, y)
        z = Expr(:quote, x)
        esc(quote
            $(Issue398)._show(io::IO, t::$(Issue398).TestType{$z}) = print(io, $y)
            const $x = $(Issue398).TestType{$z}()
        end)
    end

    export @define_show_and_make_object

    end # module

    using .Issue398
end
```

```jldoctest
julia> @define_show_and_make_object q "abcd"
abcd
```

```@meta
DocTestSetup = nothing
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

# Filtering of `Main.`

```jldoctest
julia> struct Point end;

julia> println(Point)
Point

julia> sqrt(100)
10.0

julia> sqrt = 4
ERROR: cannot assign variable Base.sqrt from module Main
```

```jldoctest
julia> g(x::Float64, y) = 2x + y
g (generic function with 1 method)

julia> g(x, y::Float64) = x + 2y
g (generic function with 2 methods)

julia> g(2.0, 3)
7.0

julia> g(2, 3.0)
8.0

julia> g(2.0, 3.0)
ERROR: MethodError: g(::Float64, ::Float64) is ambiguous. Candidates:
  g(x, y::Float64) in Main at none:1
  g(x::Float64, y) in Main at none:1
Possible fix, define
  g(::Float64, ::Float64)
```

# Anonymous function declaration

```jldoc
julia> x->x # ignore error on 0.7
#1 (generic function with 1 method)
```

# Bad links (Windows)

* [Colons not allowed on Windows -- `some:path`](some:path)
* [No "drive" -- `:path`](:path)
* [Absolute Windows paths -- `X:\some\path`](X:\some\path)
