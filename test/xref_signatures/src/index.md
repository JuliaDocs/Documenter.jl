# XRefSignatures
```@meta
CurrentModule = XRefSignatures.XRefSignaturesContent
```

This test documentation demonstrates the ability to cross-reference by signature, 
including references to:
- [specialized methods](@ref XRefSignaturesContent.g(::Float64))
- [parametric methods](@ref XRefSignaturesContent.g(::X) where X)
- [constrained parametric methods](@ref XRefSignaturesContent.g(::AbstractArray{T}) where T <: Number)

Union-all types may be equivalent without being identical. 
Thus, we can sometimes refer to them using alternative, but valid, names such as
[`g(::Y) where Y`](@ref XRefSignaturesContent.g(::Y) where Y) which is equivalent to
[`g(::X) where X`](@ref XRefSignaturesContent.g(::X) where X).

## API

```@docs
XRefSignaturesContent.g
XRefSignaturesContent.g(::Float64)
XRefSignaturesContent.g(::X) where X
XRefSignaturesContent.g(::AbstractArray{T}) where T <: Number
```
