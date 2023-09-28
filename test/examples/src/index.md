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
DocTestFilters = [r"foo[a-z]+", r"[0-9]+"]
```

```jldoctest
julia> print("foobar123")
foobuu456
```

```@meta
DocTestFilters = r"foo[a-z]+"
```

```jldoctest
julia> print("foobar")
foobuu
```

```@meta
DocTestFilters = nothing
```

```jldoctest
julia> print("foobar")
foobar
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

# Doctest keyword arguments

```jldoctest; setup = :(f(x) = x^2; g(x) = x)
julia> f(2)
4

julia> g(2)
2
```
```jldoctest
julia> f(2)
ERROR: UndefVarError: f not defined
```

```jldoctest PR650; setup = :(f(x) = x^2; g(x) = x)
julia> f(2)
4

julia> g(2)
2
```
```jldoctest PR650
julia> f(2)
4

julia> g(2)
2
```

```jldoctest; filter = [r"foo[a-z]+"]
julia> print("foobar")
foobuu
```

```jldoctest; filter = [r"foo[a-z]+", r"[0-9]+"]
julia> print("foobar123")
foobuu456
```

```jldoctest; filter = r"foo[a-z]+"
julia> print("foobar")
foobuu
```

```jldoctest; filter = r"foo[a-z]+", setup = :(f() = print("foobar"))
julia> f()
foobuu
```

```jldoctest; output = false
foo(a, b) = a * b
foo(2, 3)

# output

6
```

## World age issue for show
```jldoctest
julia> @enum Color red blue green

julia> instances(Color)
(red, blue, green)
```


# Sanitise module names

```jldoctest
julia> struct T end

julia> t = T()
T()

julia> fullname(@__MODULE__)
(:Main,)

julia> fullname(Base.Broadcast)
(:Base, :Broadcast)

julia> @__MODULE__
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

# Issue653

```jldoctest
julia> struct MyException <: Exception
           msg::AbstractString
       end

julia> function Base.showerror(io::IO, err::MyException)
           print(io, "MyException: ")
           print(io, err.msg)
       end

julia> err = MyException("test exception")
MyException("test exception")

julia> sprint(showerror, err)
"MyException: test exception"

julia> throw(MyException("test exception"))
ERROR: MyException: test exception
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

```@repl
ex = :(1 + 5)
eval(ex)
```

```@example
ex = :(1 + 5)
eval(ex)
```

```@example
a = 1
:(a + 1)
```

# Issue #793
```jldoctest
julia> write("issue793.jl", "\"Hello!\"");

julia> include("issue793.jl")
"Hello!"

julia> rm("issue793.jl");
```
```@repl
write("issue793.jl", "\"Hello!\"")
include("issue793.jl")
rm("issue793.jl")
```
```@example
write("issue793.jl", "\"Hello!\"")
r = include("issue793.jl")
rm("issue793.jl")
r
```


```jldoctest
julia> a = 1
1

julia> ans
1
```

```jldoctest issue959
julia> "hello"; "world"
"world"

julia> ans
"world"
```

## Issue #1148

```@setup setup-include-test
write("issue1148.jl", "x = 1148")
r = include("issue1148.jl")
rm("issue1148.jl")
```

```@repl setup-include-test
x
@assert x == 1148
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

# Assigning symbols example

```@example
r = :a
```

# Bad links (Windows)

* [Colons not allowed on Windows -- `some:path`](some:path)
* [No "drive" -- `:path`](:path)
* [Absolute Windows paths -- `X:\some\path`](X:\some\path)

# Rendering text/markdown

```@example
struct MarkdownOnly
    value::String
end
Base.show(io::IO, ::MIME"text/markdown", mo::MarkdownOnly) = print(io, mo.value)

MarkdownOnly("""
**bold** output from MarkdownOnly
""")
```

# Empty heading
##

# Issue 1392

```1392-test-language 1392-extra-info
julia> function foo end;
```

# Issue 890

I will pay \$1 if $x^2$ is displayed correctly. People may also write \$s or
even money bag\$\$.

# Module scrubbing from `@repl` and `@example`

None of these expressions should result in the gensym'd module in the output

```@repl
@__MODULE__
println("@__MODULE__ is ", @__MODULE__) # sandbox printed to stdout
function f()
    println("@__MODULE__ is ", @__MODULE__)
    @warn "Main as the module for this log message"
    @__MODULE__
end
f()
@warn "Main as the module for this log message"
```
```@repl
module A
    function f()
        println("@__MODULE__ is ", @__MODULE__)
        @warn "Main.A as the module for this log message"
        @__MODULE__
    end
end
A.f()
```

```@example
@__MODULE__ # sandbox as return value
```

```@example
println("@__MODULE__ is ", @__MODULE__) # sandbox printed to stdout
```

```@example
function f()
    println("@__MODULE__ is ", @__MODULE__)
end
f()
```

```@example
function f()
    @__MODULE__
end
f()
```

```@example
@warn "Main as the module for this log message"
```

```@example moduleA
module A
    function f()
        println("@__MODULE__ is ", @__MODULE__)
        @warn "Main.A as the module for this log message"
        @__MODULE__
    end
end
```

```@example moduleA
A.f()
```

## Headings in block context

!!! error "Blocks in block context"

    ```julia
    x^2
    ```

    Headings:

    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

Also in block quotes:

> ```julia
> x^2
> ```
>
> Headings:
>
> # Heading 1
> ## Heading 2
> ### Heading 3
> #### Heading 4
> ##### Heading 5
> ###### Heading 6

# JuliaValue

It is possible to create pseudo-interpolations with the `Markdown` parser: $foo.

$([1 2 3; 4 5 6])

They do not get evaluated.

# Admonitions

!!! note "'note' admonition"
    Admonitions look like this. This is a `!!! note`-type admonition.

    Note that admonitions themselves can contain other block-level elements too,
    such as code blocks. E.g.

    ```julia
    f(x) = x^2
    ```

    However, you **can not** have at-blocks, docstrings, doctests etc. in an admonition.

    Headings are OK though:
    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

!!! info "'info' admonition"
    This is a `!!! info`-type admonition.

!!! tip "'tip' admonition"
    This is a `!!! tip`-type admonition.

!!! warning "'warning' admonition"
    This is a `!!! warning`-type admonition.

!!! danger "'danger' admonition"
    This is a `!!! danger`-type admonition.

!!! compat "'compat' admonition"
    This is a `!!! compat`-type admonition.

!!! details "'details' admonition"
    This is a `!!! details`-type admonition.

!!! ukw "Unknown admonition class"
    Admonition with an unknown admonition class.

## `@example` outputs to file

```@example
Main.AT_EXAMPLE_FILES[("png", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("png", :tiny)]
```
```@example
Main.AT_EXAMPLE_FILES[("webp", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("webp", :tiny)]
```
```@example
Main.AT_EXAMPLE_FILES[("gif", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("jpeg", :tiny)]
```
