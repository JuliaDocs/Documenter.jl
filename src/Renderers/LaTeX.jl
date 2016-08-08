module LaTeX

import ...DocTrees: DocTrees, Node
import ...Selectors: runner
import ..Renderers

const TeX = MIME"text/latex"

runner(::Type{Renderers.TextTag}, io::IO, m::TeX, n::Node) = print(io, n.text)

function runner(::Type{Renderers.Header}, io::IO, m::TeX, n::Node)
    print(io, "\\")
    for _ in 2:findfirst(DocTrees.HEADER_TAGS, n.tag)
        print(io, "sub")
    end
    print(io, "section{")
    Renderers.render(io, m, n.nodes)
    println(io, "}")
end

function runner(::Type{Renderers.Paragraph}, io::IO, m::TeX, n::Node)
    println(io)
    Renderers.render(io, m, n.nodes)
    println(io)
end

function runner(::Type{Renderers.PreTag}, io::IO, m::TeX, n::Node)
    local source = n.nodes[1].nodes[1].text
    local language = get(DocTrees.metadata(n), :code, "")
    println(io, "\\begin{minted}{", language, "}")
    println(io, source)
    println(io, "\\end{minted}")
end

function runner(::Type{Renderers.BlockQuote}, io::IO, m::TeX, n::Node)
    println(io, "\\begin{quote}")
    Renderers.render(io, m, n.nodes)
    println(io, "\\end{quote}")
end

function runner(::Type{Renderers.CodeTag}, io::IO, m::TeX, n::Node)
    print(io, "\\texttt{", n.nodes[1].text, "}")
end

runner(::Type{Renderers.SpanTag}, io::IO, m::TeX, n::Node) = Renderers.render(io, m, n.nodes)

function runner(::Type{Renderers.StrongTag}, io::IO, m::TeX, n::Node)
    print(io, "\\textbf{")
    Renderers.render(io, m, n.nodes)
    print(io, "}")
end

function runner(::Type{Renderers.EmTag}, io::IO, m::TeX, n::Node)
    print(io, "\\emph{")
    Renderers.render(io, m, n.nodes)
    print(io, "}")
end

function runner(::Type{Renderers.Link}, io::IO, m::TeX, n::Node)
    if haskey(DocTrees.metadata(n), :footnote)
        print(io, "\\footnotemark[", get(DocTrees.metadata(n), :footnote, ""), "]")
    else
        print(io, "\\href{")
        print(io, get(Renderers.attributes(n, m), :href, ""), "}{")
        Renderers.render(io, m, n.nodes)
        print(io, "}")
    end
end

function runner(::Type{Renderers.Image}, io::IO, m::TeX, n::Node)
    local src = get(DocTrees.attributes(n), :src, "")
    print(io, "\\includegraphics{", src, "}")
end

function runner(::Type{Renderers.List}, io::IO, m::TeX, n::Node)
    println(io, "\\begin{itemize}")
    if n.tag === :ul
        for node in n.nodes
            print(io, "\\item[]")
            let temp = IOBuffer()
                Renderers.render(temp, m, node.nodes)
                Renderers.indented(io, seekstart(temp), "    ")
            end
        end
    elseif n.tag === :ol
        local count = length(n.nodes)
        local width = ndigits(count)
        local offset = get(DocTrees.metadata(n), :list, 1) - 1
        for (number, node) in enumerate(n.nodes)
            print(io, "\\item[", lpad(number + offset, width), ". ]")
            let temp = IOBuffer()
                Renderers.render(temp, m, node.nodes)
                Renderers.indented(io, seekstart(temp), "    ")
            end
        end
    else
        error("fatal error. Unhandled list type '$n'.")
    end
    println(io, "\\end{itemize}")
end

function runner(::Type{Renderers.HrTag}, io::IO, m::TeX, n::Node)
    println(io, "\n\\begin{center}\\rule{0.5\\linewidth}{\\linethinkness}\\end{center}\n")
end

runner(::Type{Renderers.BrTag}, io::IO, m::TeX, n::Node) = println(io, "\\\\")

# TODO: print with "correct" width for each column?
function runner(::Type{Renderers.Table}, io::IO, m::TeX, n::Node)
    print(io, "\\begin{longtable}[]{@{}")
    join(io, DocTrees.metadata(n)[:table])
    println(io, "@{}}")
    println(io, "\\toprule")
    for (nth, node) in enumerate(n.nodes[1].nodes)
        nth > 1 && print(io, " & ")
        Renderers.render(io, m, node.nodes)
    end
    println(io, "\\tabularnewline")
    println(io, "\\midrule")
    println(io, "\\endhead")

    for row in n.nodes[2:end]
        for (nth, node) in enumerate(row.nodes)
            nth > 1 && print(io, " & ")
            Renderers.render(io, m, node.nodes)
        end
        println(io, "\\tabularnewline")
    end
    println(io, "\\bottomrule")
    println(io, "\\end{longtable}")
end

function runner(::Type{Renderers.Admonition}, io::IO, m::TeX, n::Node)
    title, category = get(DocTrees.metadata(n), :admonition, ("", ""))
    println(io)
    println(io, "\\begin{admonition}{", category, "}{", title, "}")
    let temp = IOBuffer()
        Renderers.render(temp, m, n.nodes)
        Renderers.indented(io, seekstart(temp), "    ")
    end
    println(io, "\\end{admonition}")
end

function runner(::Type{Renderers.Footnote}, io::IO, m::TeX, n::Node)
    local id = get(DocTrees.metadata(n), :footnote, "")
    println(io)
    println(io, "\\footnotetext[", id, "]{")
    Renderers.render(io, m, n.nodes)
    println(io, "}")
end

function runner(::Type{Renderers.DivTag}, io::IO, m::TeX, n::Node)
    println(io)
    Renderers.render(io, m, n.nodes)
    println(io)
end

end
