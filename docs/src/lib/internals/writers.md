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
]
Filter = t -> t ∉ (asset, RawHTMLHeadContent)
Pages = ["writers.jl", "html/HTMLWriter.jl", "html/RD.jl", "html/write_inventory.jl", "latex/LaTeXWriter.jl"]
```
```@docs
Documenter.Plugin
```
