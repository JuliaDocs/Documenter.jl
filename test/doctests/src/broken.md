This source file contains broken doctests:

```jldoctest
julia> 2 + 2
-6
```

Filtering with regex substitutions:

```jldoctest; filter = r"([0-9]+\.[0-9]{8})[0-9]+" => s"\1***"
julia> sqrt(2)
1.4142999999999
```

Testing catching errors:

```jldoctest
julia> error("0123456789")
ERROR: ABCDEFGHIJ
Stacktrace:
 [...]
```

```jldoctest; filter = r"\b[0-9]+\b"
julia> error("0123456789")
ERROR: ABCDEFGHIJ
Stacktrace:
 [...]
```
