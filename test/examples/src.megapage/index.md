# Megabytepage

This page has more than 1MB of HTML.

```@example
using Random
for s in Base.Iterators.partition(randstring(2^20), 80)
    println(s)
end
```
