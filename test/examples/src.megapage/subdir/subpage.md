# Megabytepage: subdir

This page in a subdirectory has more than 1MB of HTML too.

```@example
using Random
for s in Base.Iterators.partition(randstring(2^20), 80)
    # Note: the join() is necessary to get strings (as opposed to Vector{Char} objects)
    # on older Julia versions, since there was a breaking-ish bugfix that changed how
    # Iterators.partition works with strings. join(::SubString) appears to basically be
    # a no-op, so it has no real effect on newer Julia versions.
    #
    # https://github.com/JuliaLang/julia/issues/45768
    # https://github.com/JuliaLang/julia/pull/46234
    #
    # Note: we _could_ also just print the vectors, but then the HTML files end up being
    # ~14 MiB.
    println(join(s))
end
```
