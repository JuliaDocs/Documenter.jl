# XRefSignatures

This test documentation demonstrates the ability to cross-reference by signature, 
including references to:
- [specialized methods](@ref XRefSignaturesMain.g(::Float64))
- [parametric methods](@ref XRefSignaturesMain.g(::X) where X)
- [constrained parametric methods](@ref XRefSignaturesMain.g(::AbstractArray{T}) where T <: Number)

Union-all types may be equivalent without being identical. 
Thus, we can sometimes refer to them using alternative, but valid, names such as
 [`g(::Y) where Y`](@ref XRefSignaturesMain.g(::Y) where Y).

## API

```@docs
XRefSignaturesMain.g
XRefSignaturesMain.g(::Float64)
XRefSignaturesMain.g(::X) where X
XRefSignaturesMain.g(::AbstractArray{T}) where T <: Number
```
