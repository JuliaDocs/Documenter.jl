# Doctests

Documenter will, by default, try to run `jldoctest` code blocks that it finds in the generated
documentation. This can help to avoid documentation examples from becoming outdated,
incorrect, or misleading. It's recommended that as many of a package's examples be runnable
by Documenter's doctest.

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

## Preserving definitions between blocks

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

    Labeled doctest blocks does not need to be consecutive (as in the example above) to be
    included in the same module. They can be interspaced with unlabeled blocks or blocks
    with another label.

## Setup Code

Doctests may require some setup code that must be evaluated prior to that of the actual
example, but that should not be displayed in the final documentation. For this purpose a
`@meta` block containing a `DocTestSetup = ...` value can be used. In the example below,
the function `foo` is defined inside a `@meta` block. This block will be evaluated at
the start of the following doctest blocks:

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

!!! note

    The `DocTestSetup` value is **re-evaluated** at the start of *each* doctest block
    and no state is shared between any code blocks.

## Filtering Doctests

A part of the output of a doctest might be non-deterministic, e.g. pointer addresses and timings.
It is therefore possible to filter a doctest so that the deterministic part can still be tested.

A filter takes the form of a regular expression.
In a doctest, each match in the expected output and the actual output is removed before the two outputs are compared.
Filters are added globally, i.e. applied to all doctests in the documentation, by passing a list of regular expressions to
`makedocs` with the keyword `doctestfilters`.

For more fine grained control, a list of regular expressions can also be assigned inside a `@meta` block by assigning to the variable `DocTestFilters`.
The global filters and the filters defined in the `@meta` block are both applied to each doctest.

An example is given below where some of the non-deterministic output from `@time` is filered.

````markdown
```@meta
DocTestFilters = [r"[0-9\.]+ seconds \(.*\)"]
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
````

## Skipping Doctests

Doctesting can be disabled by setting the [`makedocs`](@ref) keyword `doctest = false`.
This should only be done when initially laying out the structure of a package's
documentation, after which it's encouraged to always run doctests when building docs.
