module Markdown

import ...DocTrees: DocTrees, Node
import ...Selectors: runner
import ..Renderers

const MD = MIME"text/markdown"

runner(::Type{Renderers.TextTag}, io::IO, m::MD, n::Node) = print(io, n.text)

function runner(::Type{Renderers.Header}, io::IO, m::MD, n::Node)
    for _ in 1:findfirst(DocTrees.HEADER_TAGS, n.tag)
        print(io, '#')
    end
    print(io, ' ')
    Renderers.render(io, m, n.nodes)
    println(io)
end

function runner(::Type{Renderers.Paragraph}, io::IO, m::MD, n::Node)
    println(io)
    Renderers.render(io, m, n.nodes)
    println(io)
end

function runner(::Type{Renderers.PreTag}, io::IO, m::MD, n::Node)
    local source = n.nodes[1].nodes[1].text
    local language = get(DocTrees.metadata(n), :code, "")
    local count = mapreduce(length, max, 2, matchall(r"^(`+)"m, source)) + 1
    println(io)
    println(io, "`"^count, language)
    println(io, source)
    println(io, "`"^count)
    println(io)
end

function runner(::Type{Renderers.BlockQuote}, io::IO, m::MD, n::Node)
    let temp = IOBuffer()
        Renderers.render(temp, m, n.nodes)
        Renderers.indented(io, seekstart(temp), "> ")
    end
    println(io)
end

function runner(::Type{Renderers.CodeTag}, io::IO, m::MD, n::Node)
    local source = n.nodes[1].text
    local count = mapreduce(length, max, 0, matchall(r"`+", source)) + 1
    print(io, "`"^count, source, "`"^count)
end

runner(::Type{Renderers.SpanTag}, io::IO, m::MD, n::Node) = Renderers.render(io, m, n.nodes)

function runner(::Type{Renderers.StrongTag}, io::IO, m::MD, n::Node)
    print(io, "**")
    Renderers.render(io, m, n.nodes)
    print(io, "**")
end

function runner(::Type{Renderers.EmTag}, io::IO, m::MD, n::Node)
    print(io, "*")
    Renderers.render(io, m, n.nodes)
    print(io, "*")
end

function runner(::Type{Renderers.Link}, io::IO, m::MD, n::Node)
    if haskey(DocTrees.metadata(n), :footnote)
        print(io, "[^", get(DocTrees.metadata(n), :footnote, ""), "]")
    else
        print(io, "[")
        Renderers.render(io, m, n.nodes)
        print(io, "](", get(Renderers.attributes(n, m), :href, ""), ")")
    end
end

function runner(::Type{Renderers.Image}, io::IO, m::MD, n::Node)
    local alt = get(DocTrees.attributes(n), :alt, "")
    local src = get(DocTrees.attributes(n), :src, "")
    print(io, "![", alt, "](", src, ")")
end

function runner(::Type{Renderers.List}, io::IO, m::MD, n::Node)
    if n.tag === :ul
        local bullet = "  * "
        for node in n.nodes
            let temp = IOBuffer()
                Renderers.render(temp, m, node.nodes)
                Renderers.indented(io, seekstart(temp), " "^length(bullet), bullet)
            end
        end
    elseif n.tag === :ol
        local count = length(n.nodes)
        local width = ndigits(count)
        local offset = get(DocTrees.metadata(n), :list, 1) - 1
        for (number, node) in enumerate(n.nodes)
            number += offset
            let temp = IOBuffer(),
                bullet = string(lpad(number, width), ". ")
                Renderers.render(temp, m, node.nodes)
                Renderers.indented(io, seekstart(temp), " "^length(bullet), bullet)
            end
        end
    else
        error("fatal error. Unhandled list type '$n'.")
    end
end

runner(::Type{Renderers.HrTag}, io::IO, m::MD, n::Node) = println(io, "\n---\n")

runner(::Type{Renderers.BrTag}, io::IO, m::MD, n::Node) = println(io)

function runner(::Type{Renderers.Table}, io::IO, m::MD, n::Node)
    # Header.
    local header = n.nodes[1]
    print(io, "| ")
    for (nth, node) in enumerate(header.nodes)
        nth > 1 && print(io, " | ")
        let temp = IOBuffer()
            Renderers.render(temp, m, node.nodes)
            seekstart(temp)
            local range = Renderers.selection(temp, '\n', true, -1)
            Renderers.writeto(io, temp, range)
        end
    end
    println(io, " |")

    # Alignment.
    local align = DocTrees.metadata(n)[:table]
    print(io, "|")
    for (nth, sym) in enumerate(align)
        nth > 1 && print(io, "|")
        # Left side.
        left = sym === :l || sym === :c
        print(io, left ? ":" : " ")
        # Bar.
        print(io, "---")
        # Right side.
        right = sym === :r || sym === :c
        print(io, right ? ":" : " ")
    end
    println(io, "|")

    # Body.
    for row in n.nodes[2:end]
        print(io, "| ")
        for (nth, node) in enumerate(row.nodes)
            nth > 1 && print(io, " | ")
            let temp = IOBuffer()
                Renderers.render(temp, m, node.nodes)
                seekstart(temp)
                local range = Renderers.selection(temp, '\n', true, 0)
                Renderers.writeto(io, temp, range)
            end
        end
        println(io, " |")
    end
end

function runner(::Type{Renderers.Admonition}, io::IO, m::MD, n::Node)
    title, category = get(DocTrees.metadata(n), :admonition, ("", ""))
    println(io)
    println(io, "!!! ", category, " ", '"', title, '"')
    let temp = IOBuffer()
        Renderers.render(temp, m, n.nodes)
        Renderers.indented(io, seekstart(temp), "    ")
    end
    println(io)
end

function runner(::Type{Renderers.Footnote}, io::IO, m::MD, n::Node)
    local id = get(DocTrees.metadata(n), :footnote, "")
    println(io)
    println(io, "[^", id, "]:")
    let temp = IOBuffer()
        Renderers.render(temp, m, n.nodes)
        Renderers.indented(io, seekstart(temp), "    ")
    end
    println(io)
end

function runner(::Type{Renderers.DivTag}, io::IO, m::MD, n::Node)
    println(io)
    Renderers.render(io, m, n.nodes)
    println(io)
end

end
