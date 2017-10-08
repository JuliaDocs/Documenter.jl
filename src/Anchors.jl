"""
Defines the [`Anchor`](@ref) and [`AnchorMap`](@ref) types.

`Anchor`s and `AnchorMap`s are used to represent links between objects within a document.
"""
module Anchors

using Compat, DocStringExtensions

# Types.
# ------

"""
Stores an arbitrary object called `.object` and it's location within a document.

**Fields**

- `object` -- the stored object.
- `order`  -- ordering of `object` within the entire document.
- `file`   -- the destination file, in `build`, where the object will be written to.
- `id`     -- the generated "slug" identifying the object.
- `nth`    -- integer that unique-ifies anchors with the same `id`.
"""
mutable struct Anchor
    object :: Any
    order  :: Int
    file   :: String
    id     :: String
    nth    :: Int
    Anchor(object) = new(object, 0, "", "", 1)
end

"""
Tree structure representating anchors in a document and their relationships with eachother.

**Object Hierarchy**

    id -> file -> anchors

Each `id` maps to a `file` which in turn maps to a vector of `Anchor` objects.
"""
mutable struct AnchorMap
    map   :: Dict{String, Dict{String, Vector{Anchor}}}
    count :: Int
    AnchorMap() = new(Dict(), 0)
end

# Add anchor.
# -----------

"""
$(SIGNATURES)

Adds a new [`Anchor`](@ref) to the [`AnchorMap`](@ref) for a given `id` and `file`.

Either an actual [`Anchor`](@ref) object may be provided or any other object which is
automatically wrapped in an [`Anchor`](@ref) before being added to the [`AnchorMap`](@ref).
"""
function add!(m::AnchorMap, anchor::Anchor, id, file)
    filemap = get!(m.map, id, Dict{String, Vector{Anchor}}())
    anchors = get!(filemap, file, Anchor[])
    push!(anchors, anchor)
    anchor.order = m.count += 1
    anchor.file  = file
    anchor.id    = id
    anchor.nth   = length(anchors)
    anchor
end
add!(m::AnchorMap, object, id, file) = add!(m, Anchor(object), id, file)

# Anchor existance.
# -----------------

"""
$(SIGNATURES)

Does the given `id` exist within the [`AnchorMap`](@ref)? A `file` and integer `n` may also
be provided to narrow the search for existance.
"""
exists(m::AnchorMap, id, file, n) = exists(m, id, file) && 1 ≤ n ≤ length(m.map[id][file])
exists(m::AnchorMap, id, file)    = exists(m, id) && haskey(m.map[id], file)
exists(m::AnchorMap, id)          = haskey(m.map, id)

# Anchor uniqueness.
# ------------------

"""
$(SIGNATURES)

Is the `id` unique within the given [`AnchorMap`](@ref)? May also specify the `file`.
"""
function isunique(m::AnchorMap, id)
    exists(m, id) &&
    length(m.map[id]) === 1 &&
    isunique(m, id, first(first(m.map[id])))
end
function isunique(m::AnchorMap, id, file)
    exists(m, id, file) &&
    length(m.map[id][file]) === 1
end

# Get anchor.
# -----------

"""
$(SIGNATURES)

Returns the [`Anchor`](@ref) object matching `id`. `file` and `n` may also be provided. An
`Anchor` is returned, or `nothing` in case of no match.
"""
function anchor(m::AnchorMap, id)
    isunique(m, id) ?
        anchor(m, id, first(first(m.map[id])), 1) :
        nothing
end
function anchor(m::AnchorMap, id, file)
    isunique(m, id, file) ?
        anchor(m, id, file, 1) :
        nothing
end
function anchor(m::AnchorMap, id, file, n)
    exists(m, id, file, n) ?
        m.map[id][file][n]   :
        nothing
end

end
