module DocTrees

import AbstractTrees

#
# Constants.
#

const NULL_TAG = Symbol("#NULL#")
const TEXT_TAG = Symbol("#TEXT#")

const EMPTY_TEXT = ""

const HEADER_TAGS = (:h1, :h2, :h3, :h4, :h5, :h6)


#
# Metadata and Attributes.
#

immutable Metadata
    dict::Base.ImmutableDict{Symbol, Any}

    function Metadata(args...)
        local dict = Base.ImmutableDict{Symbol, Any}()
        for (k, v) in args
            dict = Base.ImmutableDict{Symbol, Any}(dict, k, v)
        end
        return new(dict)
    end
end

immutable Attributes
    dict::Base.ImmutableDict{Symbol, String}

    function Attributes(args...)
        local dict = Base.ImmutableDict{Symbol, String}()
        for arg in args
            dict = attributes(dict, arg)
        end
        return new(dict)
    end

    function attributes{D <: Base.ImmutableDict}(dict::D, str::AbstractString)
        local class = IOBuffer()
        local id = IOBuffer()
        for each in eachmatch(r"[#|\.]([\w\-]+)", str)
            local buffer = startswith(each.match, '.') ? class : id
            print(buffer, position(buffer) === 0 ? "" : " ", each.captures[1])
        end
        dict = position(class) === 0 ? dict : D(dict, :class, takebuf_string(class))
        dict = position(id) === 0 ? dict : D(dict, :id, takebuf_string(id))
        return dict
    end
    attributes{D <: Base.ImmutableDict}(d::D, s::Symbol)       = D(d, s, "")
    attributes{D <: Base.ImmutableDict}(d::D, p::Pair{Symbol}) = D(d, p.first, string(p.second))
    attributes{D <: Base.ImmutableDict}(d::D, p::Pair)         = D(d, Symbol(p.first), string(p.second))
end

function Base.show(io::IO, data::Union{Attributes, Metadata})
    (left, right) = isa(data, Attributes) ? ('{', '}') : ('[', ']')
    print(io, left)
    join(io, ("$k: $(repr(v))" for (k, v) in data.dict), ", ")
    print(io, right)
end

#
# Nodes.
#

immutable Node
    tag::Symbol
    text::String
    attributes::Attributes
    metadata::Metadata

    nodes::Vector{Node}
    index::Base.RefValue{Int}
    parent::Base.RefValue{Node}

    Node() = new(NULL_TAG)
    Node(s::Symbol, args...) = link(s, EMPTY_TEXT, separate(args)...)
    Node(t::AbstractString, args...) = link(TEXT_TAG, t, separate(args)...)

    function link(tag, text, nodes, attrs, meta)
        local this = new(tag, text, attrs, meta, nodes, Ref(0), Ref(Node()))
        for (index, node) in enumerate(nodes)
            node.index[] = index
            node.parent[] = this
        end
        this.parent[] = this
        return this
    end

    function separate(args::Tuple)
        local nodes = Node[]
        local attrs = Attributes()
        local meta = Metadata()
        for arg in args
            isa(arg, Attributes) ? (attrs = arg) :
            isa(arg, Metadata)   ? (meta  = arg) : flatten!(nodes, arg)
        end
        return (nodes, attrs, meta)
    end

    function flatten!(out, nodes)
        for node in nodes
            flatten!(out, node)
        end
        return out
    end
    flatten!(out, s::Union{Symbol, AbstractString}) = push!(out, Node(s))
    flatten!(out, node::Node) = push!(out, node)
end

Base.show(io::IO, node::Node) = print(io, "(", node.tag, " ... )")

#
# Tags.
#

immutable Tag
    name::Symbol
end

Base.show(io::IO, t::Tag) = print(io, "<", t.name, ">")

macro tags(s...)
    esc(:(const ($(s...),) = $(map(Tag, s))))
end

(t::Tag)(args...) = Node(t.name, args...)
(n::Node)(args...) = Node(n.tag, n.attributes, n.metadata, args...)
Base.getindex(t::Tag, args...) = Node(t.name, Attributes(args...))
Base.getindex(n::Node, args...) = Node(n, Attributes(args...))

#
# Attribute and Metadata Queries.
#

attributes(n::Node) = n.attributes.dict
metadata(n::Node) = n.metadata.dict

getnull(a::Associative, key::Symbol, T) = Nullable{T}(haskey(a, key) ? a[key] : nothing)

function querynull(n::Node, key::Symbol, T)
    local dict = metadata(n)
    if isroot(n)
        return getnull(dict, key, T)
    else
        if haskey(dict, key)
            return Nullable{T}(dict[key])
        else
            return querynull(parent(n), key, T)
        end
    end
end

function query{T}(n::Node, key::Symbol, default::T)
    local results = querynull(n, key, T)
    return isnull(results) ? default : get(results)
end

#
# Node getters and predicates.
#

unwrap(f, n::Nullable) = (isnull(n) || f(get(n)); return nothing)

parent(n::Node) = n.parent[]
root(n::Node) = isroot(n) ? n : root(parent(n))
index(n::Node) = n.index[]

AbstractTrees.children(n::Node) = n.nodes

depth(n::Node) = isroot(n) ? 0 : (1 + depth(parent(n)))

isroot(n::Node) = parent(n) === n
istext(n::Node) = n.tag === TEXT_TAG
isadmonition(n::Node) = n.tag === :div && haskey(metadata(n), :admonition)
isfootnote(n::Node) = n.tag === :div && haskey(metadata(n), :footnote)
islist(n::Node) = n.tag === :ul || n.tag === :ol
islatex(n::Node) = n.tag === :div && haskey(metadata(n), :latex)

Base.isempty(n::Node) = isempty(n.nodes)

isfirst(n::Node) = index(n) === 1
islast(n::Node) = index(n) === length(parent(n).nodes)

function sibling(n::Node, offset::Integer)
    if isroot(n)
        return Nullable{Node}()
    else
        local nth = index(n) + offset
        local nodes = parent(n).nodes
        return Nullable{Node}(nth in 1:length(nodes) ? nodes[nth] : nothing)
    end
end

include("mdconvert.jl")

end
