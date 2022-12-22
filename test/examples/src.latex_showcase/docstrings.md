# Docstrings

The following example docstrings come from the demo modules in `make.jl`.

```@docs
Mod.func
Mod.T
```

## An index of docstrings

The [`@index` block](@ref) can be used to generate a list of all the docstrings on a page (or even across pages) and will look as follows

```@index
Pages = ["docstrings.md"]
```

---

Missing docstring:

```@docs
this_docstring_does_not_exist
Mod.long_equations_in_docstrings
```

## at-autodocs

```@autodocs
Modules = [Main.AutoDocs]
```
