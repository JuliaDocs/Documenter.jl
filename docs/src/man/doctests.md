# Doctests

Documenter will, by default, run `jldoctest` code blocks that it finds and makes sure that
the actual output matches what's in the doctest. This can help to avoid documentation
examples from becoming outdated, incorrect, or misleading. It's recommended that as many of
a package's examples be runnable by Documenter's doctest.

This section of the manual outlines how to go about enabling doctests for code blocks in
your package's documentation.

## "Script" Examples

The first, of two, types of doctests is the "script" code block. To make Documenter detect
this kind of code block the following format must be used:

````markdown
```jldoctest
a = 1
b = 2
a + b

# output

3
```
````

The code block's "language" must be `jldoctest` and must include a line containing the text `#
output`. The text before this line is the contents of the script which is run. The text that
appears after `# output` is the textual representation that would be shown in the Julia REPL
if the script had been `include`d.

The actual output produced by running the "script" is compared to the expected result and
any difference will result in [`makedocs`](@ref) throwing an error and terminating.

Note that the amount of whitespace appearing above and below the `# output` line is not
significant and can be increased or decreased if desired.

It is possible to suppress the output from the doctest by setting the `output` keyword
argument to `false`, for example

````markdown
```jldoctest; output = false
a = 1
b = 2
a + b

# output

3
```
````

Note that the output of the script will still be compared to the expected result,
i.e. what is `# output` section, but the `# output` section will be suppressed in
the rendered documentation.

## REPL Examples

The other kind of doctest is a simulated Julia REPL session. The following format is
detected by Documenter as a REPL doctest:

````markdown
```jldoctest
julia> a = 1
1

julia> b = 2;

julia> c = 3;  # comment

julia> a + b + c
6
```
````

As with script doctests, the code block must have it's language set to `jldoctest`. When a code
block contains one or more `julia> ` at the start of a line then it is assumed to be a REPL
doctest. Semi-colons, `;`, at the end of a line works in the same way as in the Julia REPL
and will suppress the output, although the line is still evaluated.

Note that not all features of the REPL are supported such as shell and help modes.

## Exceptions

Doctests can also test for thrown exceptions and their stacktraces. Comparing of the actual
and expected results is done by checking whether the expected result matches the start of
the actual result. Hence, both of the following errors will match the actual result.

````markdown
```jldoctest
julia> div(1, 0)
ERROR: DivideError: integer division error
 in div(::Int64, ::Int64) at ./int.jl:115

julia> div(1, 0)
ERROR: DivideError: integer division error
```
````

If instead the first `div(1, 0)` error was written as

````markdown
```jldoctest
julia> div(1, 0)
ERROR: DivideError: integer division error
 in div(::Int64, ::Int64) at ./int.jl:114
```
````

where line `115` is replaced with `114` then the doctest will fail.

In the second `div(1, 0)`, where no stacktrace is shown, it may appear to the reader that
it is expected that no stacktrace will actually be displayed when they attempt to try to
recreate the error themselves. To indicate to readers that the output result is truncated
and does not display the entire (or any of) the stacktrace you may write `[...]` at the
line where checking should stop, i.e.

````markdown
```jldoctest
julia> div(1, 0)
ERROR: DivideError: integer division error
[...]
```
````

## Preserving Definitions Between Blocks

Every doctest block is evaluated inside its own `module`. This means that definitions
(types, variables, functions etc.) from a block can *not* be used in the next block.
For example:

````markdown
```jldoctest
julia> foo = 42
42
```
````

The variable `foo` will not be defined in the next block:

````markdown
```jldoctest
julia> println(foo)
ERROR: UndefVarError: foo not defined
```
````

To preserve definitions it is possible to label blocks in order to collect several blocks
into the same module. All blocks with the same label (in the same file) will be evaluated
in the same module, and hence share scope. This can be useful if the same definitions are
used in more than one block, with for example text, or other doctest blocks, in between.
Example:

````markdown
```jldoctest mylabel
julia> foo = 42
42
```
````

Now, since the block below has the same label as the block above, the variable `foo` can
be used:

````markdown
```jldoctest mylabel
julia> println(foo)
42
```
````

!!! note

    Labeled doctest blocks do not need to be consecutive (as in the example above) to be
    included in the same module. They can be interspaced with unlabeled blocks or blocks
    with another label.

## Setup Code

Doctests may require some setup code that must be evaluated prior to that of the actual
example, but that should not be displayed in the final documentation. There are three ways
to specify the setup code, each appropriate in a different situation.

### `DocTestSetup` in `@meta` blocks

For doctests in the Markdown source files, an `@meta` block containing a `DocTestSetup =
...` value can be used. In the example below, the function `foo` is defined inside a `@meta`
block. This block will be evaluated at the start of the following doctest blocks:

````markdown
```@meta
DocTestSetup = quote
    function foo(x)
        return x^2
    end
end
```

```jldoctest
julia> foo(2)
4
```

```@meta
DocTestSetup = nothing
```
````

The `DocTestSetup = nothing` is not strictly necessary, but good practice nonetheless to
help avoid unintentional definitions in following doctest blocks.

While technically the `@meta` blocks also work within docstrings, their use there is
discouraged since the `@meta` blocks will show up when querying docstrings in the REPL.

!!! note "Historic note"
    It used to be that `DocTestSetup`s in `@meta` blocks in Markdown files that included
    docstrings also affected the doctests in the docstrings. Since Documenter 0.23 that is
    no longer the case. You should use [Module-level metadata](@ref) or [Block-level setup
    code](@ref) instead.

### Module-level metadata

For doctests that are in docstrings, the exported [`DocMeta`](@ref) module provides an API
to attach metadata that applies to all the docstrings in a particular module. Setting up the
`DocTestSetup` metadata should be done before the [`makedocs`](@ref) or [`doctest`](@ref)
call:

```julia
using MyPackage, Documenter
DocMeta.setdocmeta!(MyPackage, :DocTestSetup, :(using MyPackage); recursive=true)
makedocs(modules=[MyPackage], ...)
```

### Block-level setup code

Yet another option is to use the `setup` keyword argument to the `jldoctest` block, which is
convenient for short definitions, and for setups needed in inline docstrings.

````markdown
```jldoctest; setup = :(foo(x) = x^2)
julia> foo(2)
4
```
````

!!! note

    The `DocTestSetup` and the `setup` values are **re-evaluated** at the start of *each* doctest block
    and no state is shared between any code blocks.
    To preserve definitions see [Preserving Definitions Between Blocks](@ref).

## Filtering Doctests

A part of the output of a doctest might be non-deterministic, e.g. pointer addresses and timings.
It is therefore possible to filter a doctest so that the deterministic part can still be tested.

A filter takes the form of a regular expression.
In a doctest, each match in the expected output and the actual output is removed before the two outputs are compared.
Filters are added globally, i.e. applied to all doctests in the documentation, by passing a list of regular expressions to
`makedocs` with the keyword `doctestfilters`.

For more fine grained control it is possible to define filters in `@meta` blocks by assigning them
to the `DocTestFilters` variable, either as a single regular expression (`DocTestFilters = [r"foo"]`)
or as a vector of several regex (`DocTestFilters = [r"foo", r"bar"]`).

An example is given below where some of the non-deterministic output from `@time` is filtered.

````markdown
```@meta
DocTestFilters = r"[0-9\.]+ seconds \(.*\)"
```

```jldoctest
julia> @time [1,2,3,4]
  0.000003 seconds (5 allocations: 272 bytes)
4-element Array{Int64,1}:
 1
 2
 3
 4
```

```@meta
DocTestFilters = nothing
```
````

The `DocTestFilters = nothing` is not strictly necessary, but good practice nonetheless to
help avoid unintentional filtering in following doctest blocks.

Another option is to use the `filter` keyword argument. This defines a doctest-local filter
which is only active for the specific doctest. Note that such filters are not shared between
named doctests either. It is possible to define a filter by a single regex (filter = r"foo")
or as a list of regex (filter = [r"foo", r"bar"]). Example:

````markdown
```jldoctest; filter = r"[0-9\.]+ seconds \(.*\)"
julia> @time [1,2,3,4]
  0.000003 seconds (5 allocations: 272 bytes)
4-element Array{Int64,1}:
 1
 2
 3
 4
```
````

!!! note

    The global filters, filters defined in `@meta` blocks, and filters defined with the `filter`
    keyword argument are all applied to each doctest.


## Doctesting Without Building the Docs

Documenter has a few ways to verify the doctests without having to run a potentially
expensive full documentation build.

### Doctesting docstrings only

An option for doctesting just the docstrings of a particular module (and all its submodules)
is to use the [`doctest`](@ref) function. It takes a list of modules as an argument and runs
all the doctests in all the docstrings it finds. This can be handy for quick tests when
writing docstrings of a package.

[`doctest`](@ref) will return `true` or `false`, depending on whether the doctests pass or
not, making it easy to include a doctest of all the docstrings in the package test suite:

```julia
using MyPackage, Documenter, Test
@test doctest([MyPackage])
```

Note that you still need to make sure that all the necessary [Module-level metadata](@ref)
for the doctests is set up before [`doctest`](@ref) is called.

### Doctesting without a full build

An alternative, which also runs doctests on the manual pages, but still skips most other
build steps, is to pass `doctest = :only` to [`makedocs`](@ref).

This also makes it more practical to include doctests as part of the normal test suite of a
package. One option to set it up is to make the `doctest` keyword depend on command line
arguments passed to the `make.jl` script:

```julia
makedocs(...,
    doctest = ("doctest-only" in ARGS) ? :only : true
)
```

Now, the `make.jl` script can be run on the command line as `julia docs/make.jl
doctest-only` and it will only run the doctests. On doctest failure, the `makedocs` throws
an error and `julia` exits with a non-zero exit code.

For running the doctests as part of the standard test suite, the  `docs/make.jl` can simply
be `include`d in the `test/runtest.jl` file:

```julia
push!(ARGS, "doctest-only")
include(joinpath(@__DIR__, "..", "docs", "make.jl"))
```

The `push!` to `ARGS` emulates the passing of the `doctest-only` command line argument.

Note that, for this to work, you need to add Documenter and all the other packages that get
loaded in `make.jl`, or in the doctest, as test dependencies.


## Fixing Outdated Doctests

To fix outdated doctests, the `doctest` flag to [`makedocs`](@ref) can be set to
`doctest = :fix`. This will run the doctests, and overwrite the old results with
the new output.

!!! note

    The `:fix` option currently only works for LF line endings (`'\n'`)

!!! note

    It is recommended to `git commit` any code changes before running the doctest fixing.
    That way it is simple to restore to the previous state if the fixing goes wrong.

!!! note

    There are some corner cases where the fixing algorithm may replace the wrong code snippet.
    It is therefore recommended to manually inspect the result of the fixing before committing.


## Skipping Doctests

Doctesting can be disabled by setting the [`makedocs`](@ref) keyword `doctest = false`.
This should only be done when initially laying out the structure of a package's
documentation, after which it's encouraged to always run doctests when building docs.
