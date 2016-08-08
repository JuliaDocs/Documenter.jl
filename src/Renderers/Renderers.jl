module Renderers

import ..DocTrees: DocTrees, Node

render(io, mime, node) = error("`render` not implemented for `$mime`.")

# Overload to replace `@ref` with correct links.
attributes(node::Node, mime) = DocTrees.attributes(node)


include("HTML.jl")


#
# Non-HTML renderers.
#

import ..DocTrees: DocTrees, Node
import ..Selectors: Selectors, AbstractSelector, order, matcher, runner


#
# `Selector` definitions needed for rendering non-HTML.
#
# This creates a jump table at compile time so that matching and rendering of tags
# can be decoupled yet not have to rely on dynamic dispatch.
#

abstract Tag <: AbstractSelector

const TAGS = (
    :TextTag     => :(DocTrees.istext(n)),
    :Header      => :(n.tag in DocTrees.HEADER_TAGS),
    :Paragraph   => :(n.tag === :p),
    :PreTag      => :(n.tag === :pre),
    :BlockQuote  => :(n.tag === :blockquote),
    :CodeTag     => :(n.tag === :code),
    :SpanTag     => :(n.tag === :span),
    :StrongTag   => :(n.tag === :strong),
    :EmTag       => :(n.tag === :em),
    :Link        => :(n.tag === :a),
    :Image       => :(n.tag === :img),
    :List        => :(DocTrees.islist(n)),
    :HrTag       => :(n.tag === :hr),
    :BrTag       => :(n.tag === :br),
    :Table       => :(n.tag === :table),
    :Admonition  => :(DocTrees.isadmonition(n)),
    :Footnote    => :(DocTrees.isfootnote(n)),
    :DivTag      => :(n.tag === :div),
)
for (nth, (tag, func)) in enumerate(TAGS)
    @eval begin
        immutable $tag <: Tag end
        order(::Type{$tag}) = $nth
        matcher(::Type{$tag}, io::IO, m::MIME, n::Node) = $func
    end
end

# For debugging.
function runner(::Type{Tag}, io::IO, m::MIME, n::Node)
    error("rendering failed for '$m' '$n'.")
end


#
# Common `render` definitions.
#

render(io::IO, m::MIME, n::DocTrees.Node) = Selectors.dispatch(Tag, io, m, n)

function render(io::IO, m::MIME, v::Vector)
    for each in v
        render(io, m, each)
    end
end


#
# Formats.
#

include("Markdown.jl")
include("LaTeX.jl")


#
# Buffer Utilties.
#

function escape(buffer::IO, ::MIME"text/html", text::AbstractString)
    if ismatch(r"[<>&'\"]", text)
        for char in text
            char === '<' ? write(buffer, "&lt;") :
            char === '>' ? write(buffer, "&gt;") :
            char === '&' ? write(buffer, "&amp;") :
            char === ''' ? write(buffer, "&#39;") :
            char === '"' ? write(buffer, "&quot;") : write(buffer, char)
        end
    else
        write(buffer, text)
    end
end

function indented(io::IO, buffer::IOBuffer, indent::AbstractString, first = indent)
    local pos = position(buffer)
    local firstline = true
    while !eof(buffer)
        local range = selection(buffer, '\n', true)
        if length(range) > 1
            print(io, firstline ? first : indent)
            firstline = false
            writeto(io, buffer, range)
        else
            println(io)
        end
    end
    seek(buffer, pos)
    return nothing
end

function selection(buffer::IOBuffer, until::Char, eat::Bool = false, offset::Integer = 0)
    local startof = position(buffer)
    local finish = startof
    while !eof(buffer)
        finish += 1
        read(buffer, Char) === until && break
    end
    eat || seek(buffer, startof)
    return (startof + 1):(finish + offset)
end

function writeto(io::IO, buffer::IOBuffer, range::Range)
    for index in range
        write(io, buffer.data[index])
    end
end

end

