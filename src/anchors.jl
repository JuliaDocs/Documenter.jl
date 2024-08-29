# Defines the [`Anchor`](@ref) and [`AnchorMap`](@ref) types.
#
# `Anchor`s and `AnchorMap`s are used to represent links between objects within a document.

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
    object::Any
    order::Int
    file::String
    id::String
    nth::Int
    # Reverse-lookup of .object for MarkdownAST trees. This is intentionally
    # uninitialized until set in Documenter.markdownast()
    node::MarkdownAST.Node{Nothing}
    Anchor(object) = new(object, 0, "", "", 1)
end

"""
Tree structure representing anchors in a document and their relationships with each other.

**Object Hierarchy**

    id -> file -> anchors

Each `id` maps to a `file` which in turn maps to a vector of `Anchor` objects.
"""
mutable struct AnchorMap
    map::Dict{String, Dict{String, Vector{Anchor}}}
    count::Int
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
function anchor_add!(m::AnchorMap, anchor::Anchor, id, file)
    filemap = get!(m.map, id, Dict{String, Vector{Anchor}}())
    anchors = get!(filemap, file, Anchor[])
    push!(anchors, anchor)
    anchor.order = m.count += 1
    anchor.file = file
    anchor.id = id
    anchor.nth = length(anchors)
    return anchor
end
anchor_add!(m::AnchorMap, object, id, file) = anchor_add!(m, Anchor(object), id, file)

# Anchor existence.
# -----------------

"""
$(SIGNATURES)

Does the given `id` exist within the [`AnchorMap`](@ref)? A `file` and integer `n` may also
be provided to narrow the search for existence.
"""
anchor_exists(m::AnchorMap, id, file, n) = anchor_exists(m, id, file) && 1 ≤ n ≤ length(m.map[id][file])
anchor_exists(m::AnchorMap, id, file) = anchor_exists(m, id) && haskey(m.map[id], file)
anchor_exists(m::AnchorMap, id) = haskey(m.map, id)

# Anchor uniqueness.
# ------------------

"""
$(SIGNATURES)

Is the `id` unique within the given [`AnchorMap`](@ref)? May also specify the `file`.
"""
function anchor_isunique(m::AnchorMap, id)
    return anchor_exists(m, id) &&
        length(m.map[id]) === 1 &&
        anchor_isunique(m, id, first(first(m.map[id])))
end
function anchor_isunique(m::AnchorMap, id, file)
    return anchor_exists(m, id, file) &&
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
    return anchor_isunique(m, id) ?
        anchor(m, id, first(first(m.map[id])), 1) :
        nothing
end
function anchor(m::AnchorMap, id, file)
    return anchor_isunique(m, id, file) ?
        anchor(m, id, file, 1) :
        nothing
end
function anchor(m::AnchorMap, id, file, n)
    return anchor_exists(m, id, file, n) ?
        m.map[id][file][n] :
        nothing
end

"""
Create a label from an anchor.
"""
anchor_label(a::Anchor) = (a.nth == 1) ? a.id : string(a.id, "-", a.nth)

"""
Create an HTML fragment from an anchor.
"""
function anchor_fragment(a::Anchor)
    frag = string("#", anchor_label(a))
    # TODO: Sanitize the fragment
    return frag
end
