# Test warnings in `@repl` block

Empty `@repl` block should not result in an assertion (issue #2206).
```@repl
```

Same if it consists of only a comment.
```@repl
# comment
```
