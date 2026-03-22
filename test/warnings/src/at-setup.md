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
x = 1  # unique placeholder so that find_block_in_file can locate this block
```

Syntax errors in blocks should be a `@docerror`, not an exception (issue #2731).
```@setup with-error
1 !in 2
```

Missing name should warn.
```@setup
x = 2  # unique placeholder so that find_block_in_file can locate this block
```
