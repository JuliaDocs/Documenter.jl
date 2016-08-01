
```@docs
missing_doc
```

```@docs
parse error
```

```@meta
CurrentModule = NonExistantModule
```

```@autodocs
Modules = [NonExistantModule]
```

```@eval
NonExistantModule
```

This is the footnote [^1]. And [^another] [^another].

[^1]: one

    [^nested]: a nested footnote

[^another_one]:

    Things! [^1]. [^2].

[^nested]

[^nested]:

    Duplicate [^1] nested footnote.
