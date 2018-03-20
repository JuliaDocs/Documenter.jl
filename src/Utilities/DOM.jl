"""
Provides a domain specific language for representing HTML documents.

# Examples

```julia
using Documenter.Utilities.DOM

# `DOM` does not export any HTML tags. Define the ones we actually need.
@tags div p em strong ul li

div(
    p("This ", em("is"), " a ", strong("paragraph."),
    p("And this is ", strong("another"), " one"),
    ul(
        li("and"),
        li("an"),
        li("unordered"),
        li("list")
    )
)
```

*Notes*

All the arguments passed to a node are flattened into a single vector rather
than preserving any nested structure. This means that passing two vectors of
nodes to a `div` will result in a `div` node with a single vector of children
(the concatenation of the two vectors) rather than two vector children. The
only arguments that are not flattened are nested nodes.

String arguments are automatically converted into text nodes. Text nodes do not
have any children or attributes and when displayed the string is escaped using
[`escapehtml`](@ref).

# Attributes

As well as plain nodes shown in the previous example, nodes can have attributes
added to them using the following syntax.

```julia
div[".my-class"](
    img[:src => "foo.jpg"],
    input[\"#my-id\", :disabled]
)
```

In the above example we add a `class = "my-class"` attribute to the `div` node,
a `src = "foo.jpg"` to the `img`, and `id = "my-id" disabled` attributes to the
`input` node.

The following syntax is supported within `[...]`:

```julia
tag[\"#id\"]
tag[".class"]
tag[\".class#id\"]
tag[:disabled]
tag[:src => "foo.jpg"]
# ... or any combination of the above arguments.
```

# Internal Representation

The [`@tags`](@ref) macro defines named [`Tag`](@ref) objects as follows

```julia
@tags div p em strong
```

expands to

```julia
const div, p, em, strong = Tag(:div), Tag(:p), Tag(:em), Tag(:strong)
```

These [`Tag`](@ref) objects are lightweight representations of empty HTML
elements without any attributes and cannot be used to represent a complete
document. To create an actual tree of HTML elements that can be rendered we
need to add some attributes and/or child elements using `getindex` or `call`
syntax. Applying either to a [`Tag`](@ref) object will construct a new
[`Node`](@ref) object.

```julia
tag(...)      # No attributes.
tag[...]      # No children.
tag[...](...) # Has both attributes and children.
```

All three of the above syntaxes return a new [`Node`](@ref) object. Printing of
`Node` objects is defined using the standard Julia display functions, so only
needs a call to `print` to print out a valid HTML document with all nessesary
text escaped.
"""
module DOM

import ..Utilities

using Compat

tostr(p::Pair) = p

export @tags

#
# The following sets are based on:
#
# - https://developer.mozilla.org/en/docs/Web/HTML/Block-level_elements
# - https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements
# - https://developer.mozilla.org/en-US/docs/Glossary/empty_element
#
const BLOCK_ELEMENTS = Set([
    :address, :article, :aside, :blockquote, :canvas, :dd, :div, :dl,
    :fieldset, :figcaption, :figure, :footer, :form, :h1, :h2, :h3, :h4, :h5,
    :h6, :header, :hgroup, :hr, :li, :main, :nav, :noscript, :ol, :output, :p,
    :pre, :section, :table, :tfoot, :ul, :video,
])
const INLINE_ELEMENTS = Set([
    :a, :abbr, :acronym, :b, :bdo, :big, :br, :button, :cite, :code, :dfn, :em,
    :i, :img, :input, :kbd, :label, :map, :object, :q, :samp, :script, :select,
    :small, :span, :strong, :sub, :sup, :textarea, :time, :tt, :var,
])
const VOID_ELEMENTS = Set([
    :area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen,
    :link, :meta, :param, :source, :track, :wbr,
])
const ALL_ELEMENTS = union(BLOCK_ELEMENTS, INLINE_ELEMENTS, VOID_ELEMENTS)

#
# Empty string as a constant to make equality checks slightly cheaper.
#
const EMPTY_STRING = ""
const TEXT = Symbol(EMPTY_STRING)

"""
Represents a empty and attribute-less HTML element.

Use [`@tags`](@ref) to define instances of this type rather than manually
creating them via `Tag(:tagname)`.
"""
struct Tag
    name :: Symbol
end

Base.show(io::IO, t::Tag) = print(io, "<", t.name, ">")

"""
Define a collection of [`Tag`](@ref) objects and bind them to constants
with the same names.

# Examples

Defined globally within a module:

```julia
@tags div ul li
```

Defined within the scope of a function to avoid cluttering the global namespace:

```julia
function template(args...)
    @tags div ul li
    # ...
end
```
"""
macro tags(args...) esc(tags(args)) end
tags(s) = :(($(s...),) = $(map(Tag, s)))

const Attributes = Vector{Pair{Symbol, String}}

"""
Represents an element within an HTML document including any textual content,
children `Node`s, and attributes.

This type should not be constructed directly, but instead via `(...)` and
`[...]` applied to a [`Tag`](@ref) or another [`Node`](@ref) object.
"""
struct Node
    name :: Symbol
    text :: String
    attributes :: Attributes
    nodes :: Vector{Node}

    Node(name::Symbol, attr::Attributes, data::Vector{Node}) = new(name, EMPTY_STRING, attr, data)
    Node(text::AbstractString) = new(TEXT, text)
end

#
# Syntax for defining `Node` objects from `Tag`s and other `Node` objects.
#
(t::Tag)(args...) = Node(t.name, Attributes(), data(args))
(n::Node)(args...) = Node(n.name, n.attributes, data(args))
Base.getindex(t::Tag, args...) = Node(t.name, attr(args), Node[])
Base.getindex(n::Node, args...) = Node(n.name, attr(args), n.nodes)

#
# Helper methods for the above `Node` "pseudo-constructors".
#
data(args) = flatten!(nodes!, Node[], args)
attr(args) = flatten!(attributes!, Attributes(), args)

#
# Types that must not be flattened when constructing a `Node`'s child vector.
#
const Atom = Union{AbstractString, Node, Pair, Symbol}

"""
# Signatures

```julia
flatten!(f!, out, x::Atom)
flatten!(f!, out, xs)
```

Flatten the contents the third argument into the second after applying the
function `f!` to the element.
"""
flatten!(f!, out, x::Atom) = f!(out, x)
flatten!(f!, out, xs)      = (for x in xs; flatten!(f!, out, x); end; out)

#
# Helper methods for handling flattening children elements in `Node` construction.
#
nodes!(out, s::AbstractString) = push!(out, Node(s))
nodes!(out, n::Node)           = push!(out, n)

#
# Helper methods for handling flattening in construction of attribute vectors.
#
function attributes!(out, s::AbstractString)
    class, id = IOBuffer(), IOBuffer()
    for x in eachmatch(r"[#|\.]([\w\-]+)", s)
        print(startswith(x.match, '.') ? class : id, x.captures[1], ' ')
    end
    position(class) === 0 || push!(out, tostr(:class => rstrip(String(take!(class)))))
    position(id)    === 0 || push!(out, tostr(:id    => rstrip(String(take!(id)))))
    return out
end
attributes!(out, s::Symbol) = push!(out, tostr(s => ""))
attributes!(out, p::Pair)   = push!(out, tostr(p))

function Base.show(io::IO, n::Node)
    if n.name === Symbol("#RAW#")
        print(io, n.nodes[1].text)
    elseif n.name === TEXT
        print(io, escapehtml(n.text))
    else
        print(io, '<', n.name)
        for (name, value) in n.attributes
            print(io, ' ', name)
            isempty(value) || print(io, '=', repr(escapehtml(value)))
        end
        if n.name in VOID_ELEMENTS
            print(io, "/>")
        else
            print(io, '>')
            if n.name === :script || n.name === :style
                isempty(n.nodes) || print(io, n.nodes[1].text)
            else
                for each in n.nodes
                    show(io, each)
                end
            end
            print(io, "</", n.name, '>')
        end
    end
end

Base.show(io::IO, ::MIME"text/html", n::Node) = print(io, n)

"""
Escape characters in the provided string. This converts the following characters:

- `<` to `&lt;`
- `>` to `&gt;`
- `&` to `&amp;`
- `'` to `&#39;`
- `\"` to `&quot;`

When no escaping is needed then the same object is returned, otherwise a new
string is constructed with the characters escaped. The returned object should
always be treated as an immutable copy and compared using `==` rather than `===`.
"""
function escapehtml(text::AbstractString)
    if occursin(r"[<>&'\"]", text)
        buffer = IOBuffer()
        for char in text
            char === '<'  ? write(buffer, "&lt;")   :
            char === '>'  ? write(buffer, "&gt;")   :
            char === '&'  ? write(buffer, "&amp;")  :
            char === '\'' ? write(buffer, "&#39;")  :
            char === '"'  ? write(buffer, "&quot;") : write(buffer, char)
        end
        String(take!(buffer))
    else
        text
    end
end

"""
A HTML node that wraps around the root node of the document and adds a DOCTYPE
to it.
"""
mutable struct HTMLDocument
    doctype :: String
    root    :: Node
end
HTMLDocument(root) = HTMLDocument("html", root)

function Base.show(io::IO, doc::HTMLDocument)
    println(io, "<!DOCTYPE $(doc.doctype)>")
    println(io, doc.root)
end

end
