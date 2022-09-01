`MultiOutput`:

```@example
(1 // 2)^2
```

`MultiCodeBlock`:

```@repl
(1 // 2)^2
```

`EvalNode`:

```@eval
using Markdown
md"""
**asd**
"""
```

`SetupNode`:

```@setup foo
x = 5
```

Evaluates to:

```@example foo
x + 1
```
