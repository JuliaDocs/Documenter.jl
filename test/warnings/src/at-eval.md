# Test warnings in `@eval` block

Empty `@example` block should not result in an assertion (issue #2206).
```@eval
```

Same if it consists of only a comment.
```@eval
# comment
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@eval
1 !in 2
```

Eval block evaluates to a value with unsupported type (should be `nothing`
or `Markdown.MD`).
```@eval
"expanded_"*"eval"
```

# Test other `@eval` block behavior

Verify that `cd(path)` in an `@eval` block works as intended.
```@eval
using Test
dir = Base.pwd()
cd("..")
rel = relpath(Base.pwd(),dir)
@test rel == ".."
nothing
```
