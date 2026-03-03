# Test warnings in `@setup` block

Unsupported keyword arguments should warn and be ignored.
```@setup shared ; typo = true
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@setup
1 !in 2
```
