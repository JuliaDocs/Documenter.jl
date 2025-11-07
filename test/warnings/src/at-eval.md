# Test warnings in `@eval` block

Eval block evaluates to a value with unsupported type (should be `nothing`
or `Markdown.MD`).
```@eval
"expanded_"*"eval"
```
