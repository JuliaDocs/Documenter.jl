# JuliaValue

It is possible to create pseudo-interpolations with the `Markdown` parser: $foo.

$([1 2 3; 4 5 6])

They do not get evaluated.

They can also come from docstrings:
```@docs
WarningTests.dummyFunctionWithUnbalancedDollar
```
