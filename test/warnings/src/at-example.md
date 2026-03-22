# Test warnings in `@example` block

Empty `@example` block should not result in an assertion (issue #2206).
```@example
```

Same if it consists of only a comment.
```@example
# comment
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@example
1 !in 2
```

Unsupported keyword arguments should warn and be ignored.
```@example demo ; typo = true, ansicolor = :blue
1 + 1
```
