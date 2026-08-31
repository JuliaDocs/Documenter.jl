# Cross-references

Basic x-refs:

* [X-ref target](@ref)
* [`Mod.func`](@ref)

Named x-refs:

* [X-ref target with an ID](@ref xreftarget)
* [docstring target](@ref Mod.func)
* [docstring target via backticks](@ref `Mod.func`)
* [string target](@ref "X-ref target")
* [inline anchor target](@ref inline-anchor-target)
* [admonition anchor target](@ref admonition-anchor-target)

Inline anchor on arbitrary (non-header) content: [an anchored phrase](@id inline-anchor-target).

!!! note "[An anchored note](@id admonition-anchor-target)"
    An admonition with an anchor in its title.

## X-ref target

## [X-ref target with id](@id xreftarget)

## [x-ref with `@code` block](@id xrefcodeblock)

This should render as ```x-ref with `@code` block```: #2010, #2011.
