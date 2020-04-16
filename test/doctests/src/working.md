This source file contains a working doctest:

```jldoctest
julia> 2 + 2
4
```

Filtering with regex substitutions:

```jldoctest; filter = r"([0-9]+\.[0-9]{8})[0-9]+" => s"\1***"
julia> sqrt(2)
1.41421356000
```

Testing catching errors:

```jldoctest
julia> error("0123456789")
ERROR: 0123456789
Stacktrace:
[...]
```

```jldoctest; filter = r"\b[0-9]+\b"
julia> error("0123456789")
ERROR: 9876543210
Stacktrace:
[...]
```
