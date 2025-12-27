```@meta
CollapsedDocStrings = true
```

# Writers

```@autodocs
Modules = [
    Documenter,
    Documenter.HTMLWriter,
    Documenter.HTMLWriter.RD,
    Documenter.LaTeXWriter,
    Documenter.TypstWriter,
]
Filter = t -> t ∉ (asset, RawHTMLHeadContent)
Pages = ["writers.jl", "html/HTMLWriter.jl", "html/RD.jl", "html/write_inventory.jl", "latex/LaTeXWriter.jl", "typst/TypstWriter.jl"]
```
```@docs
Documenter.Plugin
```
