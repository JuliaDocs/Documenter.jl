# Test warnings in `@eval` block

Empty `@example` block should not result in an assertion (issue #2206).
```@eval
```

Same if it consists of only a comment.
```@eval
# comment
```

Eval block evaluates to a value with unsupported type (should be `nothing`
or `Markdown.MD`).
```@eval
"expanded_"*"eval"
```
