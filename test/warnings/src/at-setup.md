# Test warnings in `@setup` block

Empty `@repl` block should not result in an assertion
```@setup empty
```

Same if it consists of only a comment.
```@setup just-comment
# comment
```

Unsupported keyword arguments should warn and be ignored.
```@setup shared ; typo = true
x = 1
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@setup
1 !in 2
```
