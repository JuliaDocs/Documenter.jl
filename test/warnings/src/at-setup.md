# Test warnings in `@setup` block

The name is required, so this should produce a warning.
TODO/FIXME: it currently does NOT warn
```@setup
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@setup
1 !in 2
```
