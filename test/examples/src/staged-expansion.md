# Staged Expansion

Tests that non-executable templates are expanded before executable templates.

```@example
staged_meta_value = "meta_stage"
```

```@example
staged_meta_value * "_shared"
```

```@setup staged-execution
stage_prefix = "expanded"
```

```@eval staged-execution
import Markdown
Markdown.parse(stage_prefix * "-eval-shared")
```

```@example staged-execution
println(stage_prefix, "-example-shared")
```

```@meta
ShareDefaultModule = true
```
