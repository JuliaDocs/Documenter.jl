# Font demo

```@example generate-font-example
using Documenter.DOM
function font_demo_snippet(weight, style)
    @tags pre code div
    codeblock = pre(code[".language-julia-repl"]("""
    julia> for n in 0x2700:0x27bf
                Base.isidentifier(string(Char(n))) && print(Char(n))
        end
    ✀✁✂✃✄✅✆✇✈✉✊✋✌✍✎✏✐✑✒✓✔✕✖✗✘✙✚✛✜✝✞✟✠✡✢✣✤✥✦✧✨✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺
    ✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋❌❍❎❏❐❑❒❓❔❕❖❗❘❙❚❛❜❝❞❟❠❡❢❣❤❥❦❧➔➕➖➗➘➙➚➛➜➝➞➟➠➡
    ➢➣➤➥➦➧➨➩➪➫➬➭➮➯➰➱➲➳➴➵➶➷➸➹➺➻➼➽➾➿

    julia> ❤(s) = println("I ❤ \$(s)")
    ❤ (generic function with 1 method)

    julia> ❤("Julia")
    I ❤ Julia
    """))

    wrapping_div = if isnothing(weight) && isnothing(style)
        div
    else
        css_style = isnothing(weight) ? "" : "font-weight: $(weight);"
        css_style *= isnothing(style) ? "" : "font-style: $(style);"
        div[:style => css_style]
    end

    return wrapping_div(codeblock)
end
```

## Standard font

```@example generate-font-example
font_demo_snippet(nothing, nothing)
```

## Different weights: `100:100:900`

```@example generate-font-example
font_demo_snippet(100, nothing)
```
```@example generate-font-example
font_demo_snippet(200, nothing)
```
```@example generate-font-example
font_demo_snippet(300, nothing)
```
```@example generate-font-example
font_demo_snippet(400, nothing)
```
```@example generate-font-example
font_demo_snippet(500, nothing)
```
```@example generate-font-example
font_demo_snippet(600, nothing)
```
```@example generate-font-example
font_demo_snippet(700, nothing)
```
```@example generate-font-example
font_demo_snippet(800, nothing)
```
```@example generate-font-example
font_demo_snippet(900, nothing)
```

## Italic & italic @ 900

```@example generate-font-example
font_demo_snippet(nothing, "italic")
```
```@example generate-font-example
font_demo_snippet(900, "italic")
```

## Unicode rendering

Unicode rendering examples based on issues [#618](https://github.com/JuliaDocs/Documenter.jl/issues/618), [#1561](https://github.com/JuliaDocs/Documenter.jl/issues/1561).

```
'∀'  : Unicode U+2200 (category Sm: Symbol, math)
ERROR: StringIndexError("∀ x ∃ y", 2)
1 ⊻ 3:
```

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

```
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
julia> pretty_table(data, display_size = (11,30))
┌────────┬────────┬────────┬──
│ Col. 1 │ Col. 2 │ Col. 3 │ ⋯
├────────┼────────┼────────┼──
│      1 │  false │    1.0 │ ⋯
│      2 │   true │    2.0 │ ⋯
│      3 │  false │    3.0 │ ⋯
│   ⋮    │   ⋮    │   ⋮    │ ⋱
└────────┴────────┴────────┴──
   1 column and 3 rows omitted
```
