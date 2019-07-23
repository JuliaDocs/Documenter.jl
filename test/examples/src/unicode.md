# Unicode

Some unicode tests here.

In main sans-serif font:

* Checkmark: "✓"
* Cicled plus: "⊕"
* XOR: "⊻"
* Exists: "∀", forall: "∃"

`\begin{lstlisting}` is used for non-highlighted blocks:

```
xor:    ⊻
forall: ∀
exists: ∃
check:  ✓
oplus:  ⊕

What about the other edge cases: \ % \% %\ %% %\%%
```

`\begin{minted}` is used for highlighted blocks:

```julia
xor:    ⊻
forall: ∀
exists: ∃
check:  ✓
oplus:  ⊕
```

Inlines:

`xor:    ⊻  -> %\unicodeveebar% <-`

`forall: ∀, exists: ∃, check:  ✓`

`%\%%\unicodeveebar, oplus:  ⊕`

## Drawings etc

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                             ┌───────────────┐              │
│ HTTP.request(method, uri, headers, body) -> │ HTTP.Response ├──────────────┼┐
│   │                                         └───────────────┘              ││
│   │                                                                        ││
│   │    ┌──────────────────────────────────────┐       ┌──────────────────┐ ││
│   └───▶│ request(RedirectLayer, ...)          │       │ HTTP.StatusError │ ││
│        └─┬────────────────────────────────────┴─┐     └─────────▲────────┘ ││
│          │ request(BasicAuthLayer, ...)         │               │          ││
│          └─┬────────────────────────────────────┴─┐             │          ││
│            │ request(CookieLayer, ...)            │             │          ││
│            └─┬────────────────────────────────────┴─┐           │          ││
│              │ request(CanonicalizeLayer, ...)      │           │          ││
│              └─┬────────────────────────────────────┴─┐         │          ││
│                │ request(MessageLayer, ...)           ├─────────┼──────┐   ││
```

```julia
  ┌──────────────────────────────────────────────────────────────────────┐
1 │                             ▗▄▞▀▀▀▀▀▀▀▄▄                             │
  │                           ▄▞▘           ▀▄▖                          │
  │                         ▄▀                ▝▚▖                        │
  │                       ▗▞                    ▝▄                       │
  │                      ▞▘                      ▝▚▖                     │
  │                    ▗▀                          ▝▚                    │
  │                   ▞▘                             ▀▖                  │
  │                 ▗▞                                ▝▄                 │
  │                ▄▘                                   ▚▖               │
  │              ▗▞                                      ▝▄              │
  │             ▄▘                                         ▚▖            │
  │           ▗▀                                            ▝▚           │
  │         ▗▞▘                                               ▀▄         │
  │       ▄▀▘                                                   ▀▚▖      │
0 │ ▄▄▄▄▀▀                                                        ▝▀▚▄▄▄▖│
  └──────────────────────────────────────────────────────────────────────┘
  0                                                                     70
```

```
2×4 DataFrames.DataFrame
│ Row │ a     │ b       │ c     │ d      │
│     │ Int64 │ Float64 │ Int64 │ String │
├─────┼───────┼─────────┼───────┼────────┤
│ 1   │ 2     │ 2.0     │ 2     │ John   │
│ 2   │ 2     │ 2.0     │ 2     │ Sally  │
```

```julia
function map_filter_iterators(xs, init)
    ret = iterate(xs)
    ret === nothing && return
    acc = init
    @goto filter
    local state, x
    while true
        while true                                    # input
            ret = iterate(xs, state)                  #
            ret === nothing && return acc             #
            @label filter                             #
            x, state = ret                            #
            iseven(x) && break             # filter   :
        end                                #          :
        y = 2x              # imap         :          :
        acc += y    # +     :              :          :
    end             # :     :              :          :
    #                 + <-- imap <-------- filter <-- input
    return acc
end
```
