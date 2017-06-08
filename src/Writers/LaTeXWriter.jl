"""
A module for rendering `Document` objects to LaTeX and PDF.
"""
module LaTeXWriter

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Formats,
    Documenter,
    Utilities,
    Writers

using Compat


type Context{I <: IO} <: IO
    io::I
    in_header::Bool
    footnotes::Dict{Compat.String, Int}
    depth::Int
    filename::String # currently active source file
end
Context(io) = Context{typeof(io)}(io, false, Dict(), 1, "")

_print(c::Context, args...) = Base.print(c.io, args...)
_println(c::Context, args...) = Base.println(c.io, args...)


const STYLE = joinpath(dirname(@__FILE__), "..", "..", "assets", "latex", "documenter.sty")

hastex() = (try; success(`latexmk -version`); catch; false; end)

const DOCUMENT_STRUCTURE = (
    "part",
    "chapter",
    "section",
    "subsection",
    "subsubsection",
    "paragraph",
    "subparagraph",
)

function render(doc::Documents.Document)
    mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            local file = replace("$(doc.user.sitename).tex", " ", "")
            open(file, "w") do io
                local context = Context(io)
                writeheader(context, doc)
                for (title, filename, depth) in files(doc.user.pages)
                    context.filename = filename
                    empty!(context.footnotes)
                    if 1 <= depth <= length(DOCUMENT_STRUCTURE)
                        local header_type = DOCUMENT_STRUCTURE[depth]
                        local header_text = "\n\\$(header_type){$(title)}\n"
                        if isempty(filename)
                            _println(context, header_text)
                        else
                            local path = normpath(filename)
                            local page = doc.internal.pages[path]
                            if get(page.globals.meta, :IgnorePage, :none) !== :latex
                                context.depth = depth + (isempty(title) ? 0 : 1)
                                context.depth > depth && _println(context, header_text)
                                latex(context, page, doc)
                            end
                        end
                    end
                end
                writefooter(context, doc)
            end
            cp(STYLE, "documenter.sty")
            if hastex()
                local outdir = joinpath(doc.user.root, doc.user.build)
                local pdf = replace("$(doc.user.sitename).pdf", " ", "")
                try
                    run(`latexmk -f -interaction=nonstopmode -view=none -lualatex -shell-escape $file`)
                catch err
                    Utilities.warn("failed to compile. Check generated LaTeX file.")
                    cp(file, joinpath(outdir, file); remove_destination = true)
                end
                cp(pdf, joinpath(outdir, pdf); remove_destination = true)
            else
                Utilities.warn("`latexmk` and `lualatex` required for PDF generation.")
            end
        end
    end
end

function writeheader(io::IO, doc::Documents.Document)
    local custom = joinpath(doc.user.root, doc.user.source, "assets", "custom.sty")
    isfile(custom) ? cp(custom, "custom.sty"; remove_destination = true) : touch("custom.sty")
    preamble =
        """
        \\documentclass{memoir}

        \\usepackage{./documenter}
        \\usepackage{./custom}

        \\title{$(doc.user.sitename)}
        \\author{$(doc.user.authors)}

        \\begin{document}

        \\frontmatter
        \\maketitle
        \\tableofcontents

        \\mainmatter

        """
    _println(io, preamble)
end

function writefooter(io::IO, doc::Documents.Document)
    _println(io, "\n\\end{document}")
end

function latex(io::IO, page::Documents.Page, doc::Documents.Document)
    for element in page.elements
        latex(io, page.mapping[element], page, doc)
    end
end

function latex(io::IO, vec::Vector, page, doc)
    for each in vec
        latex(io, each, page, doc)
    end
end

function latex(io::IO, anchor::Anchors.Anchor, page, doc)
    local id = string(hash(string(anchor.id, "-", anchor.nth)))
    _println(io, "\n\\hypertarget{", id, "}{}\n")
    latex(io, anchor.object, page, doc)
end


## Documentation Nodes.

function latex(io::IO, node::Documents.DocsNodes, page, doc)
    for node in node.nodes
        latex(io, node, page, doc)
    end
end

function latex(io::IO, node::Documents.DocsNode, page, doc)
    local id = string(hash(string(node.anchor.id)))
    # Docstring header based on the name of the binding and it's category.
    _println(io, "\\hypertarget{", id, "}{} ")
    _print(io, "\\hyperlink{", id, "}{\\texttt{")
    latexesc(io, string(node.object.binding))
    _print(io, "}} ")
    _println(io, " -- {", Utilities.doccat(node.object), ".}\n")
    # # Body. May contain several concatenated docstrings.
    _println(io, "\\begin{adjustwidth}{2em}{0pt}")
    latexdoc(io, node.docstr, page, doc)
    _println(io, "\n\\end{adjustwidth}")
end

function latexdoc(io::IO, md::Markdown.MD, page, doc)
    if haskey(md.meta, :results)
        # The `:results` field contains a vector of `Docs.DocStr` objects associated with
        # each markdown object. The `DocStr` contains data such as file and line info that
        # we need for generating correct scurce links.
        for (markdown, result) in zip(md.content, md.meta[:results])
            latex(io, Writers.MarkdownWriter.dropheaders(markdown), page, doc)
            # When a source link is available then print the link.
            Utilities.unwrap(Utilities.url(doc.internal.remote, doc.user.repo, result)) do url
                link = "\\href{$url}{\\texttt{source}}"
                _println(io, "\n", link, "\n")
            end
        end
    else
        # Docstrings with no `:results` metadata won't contain source locations so we don't
        # try to print them out. Just print the basic docstring.
        render(io, mime, dropheaders(md), page, doc)
    end
end

function latexdoc(io::IO, other, page, doc)
    # TODO: properly support non-markdown docstrings at some point.
    latex(io, other, page, doc)
end


## Index, Contents, and Eval Nodes.

function latex(io::IO, index::Documents.IndexNode, page, doc)
    _println(io, "\\begin{itemize}")
    for (object, _, page, mod, cat) in index.elements
        local id = string(hash(string(Utilities.slugify(object))))
        local text = string(object.binding)
        _print(io, "\\item \\hyperlink{")
        _print(io, id, "}{\\texttt{")
        latexesc(io, text)
        _println(io, "}}")
    end
    _println(io, "\\end{itemize}\n")
end

function latex(io::IO, contents::Documents.ContentsNode, page, doc)
    local depth = 1
    local needs_end = false
    _println(io, "\\begin{itemize}")
    for (count, path, anchor) in contents.elements
        local header = anchor.object
        local level = Utilities.header_level(header)
        local id = string(hash(string(anchor.id, "-", anchor.nth)))
        level < depth && _println(io, "\\end{itemize}")
        level > depth && (_println(io, "\\begin{itemize}"); needs_end = true)
        _print(io, "\\item \\hyperlink{", id, "}{")
        latexinline(io, header.text)
        _println(io, "}")
        depth = level
    end
    needs_end && _println(io, "\\end{itemize}")
    _println(io, "\\end{itemize}")
    _println(io)
end

function latex(io::IO, node::Documents.EvalNode, page, doc)
    node.result === nothing ? nothing : latex(io, node.result, page, doc)
end


## Basic Nodes. AKA: any other content that hasn't been handled yet.

latex(io::IO, str::AbstractString, page, doc) = _print(io, str)

function latex(io::IO, other, page, doc)
    _println(io)
    latex(io, other)
    _println(io)
end

latex(io::IO, md::Markdown.MD) = latex(io, md.content)

function latex(io::IO, content::Vector)
    for c in content
        latex(io, c)
    end
end

function latex{N}(io::IO, h::Markdown.Header{N})
    local tag = DOCUMENT_STRUCTURE[min(io.depth + N - 1, length(DOCUMENT_STRUCTURE))]
    _print(io, "\\", tag, "{")
    io.in_header = true
    latexinline(io, h.text)
    io.in_header = false
    _println(io, "}\n")
end

# Whitelisted lexers.
const LEXER = Set([
    "julia",
    "jlcon",
])

function latex(io::IO, code::Markdown.Code)
    language = if isempty(code.language)
          "none"
    elseif first(split(code.language)) == "jldoctest"
        # When the doctests are not being run, Markdown.Code blocks will have jldoctest as
        # the language attribute. The check here to determine if it is a REPL-type or
        # script-type doctest should match the corresponding one in DocChecks.jl. This makes
        # sure that doctests get highlighted the same way independent of whether they're
        # being run or not.
        ismatch(r"^julia> "m, code.code) ? "julia-repl" : "julia"
    else
        code.language
    end
    # the julia-repl is called "jlcon" in Pygments
    language = (language == "julia-repl") ? "jlcon" : language
    if language in LEXER
        _print(io, "\n\\begin{minted}")
        _println(io, "{", language, "}")
        _println(io, code.code)
        _println(io, "\\end{minted}\n")
    else
        _println(io, "\n\\begin{lstlisting}")
        _println(io, code.code)
        _println(io, "\\end{lstlisting}\n")
    end
end

function latexinline(io::IO, code::Markdown.Code)
    _print(io, "\\texttt{")
    latexesc(io, code.code)
    _print(io, "}")
end

function latex(io::IO, md::Markdown.Paragraph)
    for md in md.content
        latexinline(io, md)
    end
    _println(io, "\n")
end

function latex(io::IO, md::Markdown.BlockQuote)
    wrapblock(io, "quote") do
        latex(io, md.content)
    end
end

if isdefined(Markdown, :Admonition)
    function latex(io::IO, md::Markdown.Admonition)
        wrapblock(io, "quote") do
            wrapinline(io, "textbf") do
                _print(io, md.title)
            end
            _println(io, "\n")
            latex(io, md.content)
        end
    end
end

if isdefined(Markdown, :Footnote)
    function latex(io::IO, f::Markdown.Footnote)
        local id = get(io.footnotes, f.id, 1)
        _print(io, "\\footnotetext[", id, "]{")
        latex(io, f.text)
        _println(io, "}")
    end
end

if isdefined(Base.Markdown, :isordered)
    function latex(io::IO, md::Markdown.List)
        # `\begin{itemize}` is used here for both ordered and unordered lists since providing
        # custom starting numbers for enumerated lists is simpler to do by manually assigning
        # each number to `\item` ourselves rather than using `\setcounter{enumi}{<start>}`.
        #
        # For an ordered list starting at 5 the following will be generated:
        #
        # \begin{itemize}
        #   \item[5. ] ...
        #   \item[6. ] ...
        #   ...
        # \end{itemize}
        #
        pad = ndigits(md.ordered + length(md.items)) + 2
        fmt = n -> (isordered(md) ? "[$(rpad("$(n + md.ordered - 1).", pad))]" : "")
        wrapblock(io, "itemize") do
            for (n, item) in enumerate(md.items)
                _print(io, "\\item$(fmt(n)) ")
                latex(io, item)
                n < length(md.items) && _println(io)
            end
        end
    end
else
    function latex(io::IO, md::Markdown.List)
        env = md.ordered ? "enumerate" : "itemize"
        wrapblock(io, env) do
            for item in md.items
                _print(io, "\\item ")
                latexinline(io, item)
                _println(io)
            end
        end
    end
end

function latex(io::IO, hr::Markdown.HorizontalRule)
    _println(io, "{\\rule{\\textwidth}{1pt}}")
end

# This (equation*, split) math env seems to be the only way to correctly
# render all the equations in the Julia manual.
function latex(io::IO, math::Markdown.LaTeX)
    _print(io, "\\begin{equation*}\n\\begin{split}")
    _print(io, math.formula)
    _println(io, "\\end{split}\\end{equation*}")
end

function latex(io::IO, md::Markdown.Table)
    _println(io, "\n\\begin{table}[h]")
    _print(io, "\n\\begin{tabulary}{\\linewidth}")
    _println(io, "{|", uppercase(join(md.align, '|')), "|}")
    for (i, row) in enumerate(md.rows)
        i === 1 && _println(io, "\\hline")
        for (j, cell) in enumerate(row)
            j === 1 || _print(io, " & ")
            latexinline(io, cell)
        end
        _println(io, " \\\\")
        _println(io, "\\hline")
    end
    _println(io, "\\end{tabulary}\n")
    _println(io, "\\end{table}\n")
end

function latex(io::IO, raw::Documents.RawNode)
    raw.name === :latex ? _println(io, "\n", raw.text, "\n") : nothing
end

# Inline Elements.

function latexinline(io::IO, md::Vector)
    for c in md
        latexinline(io, c)
    end
end

function latexinline(io::IO, md::AbstractString)
    latexesc(io, md)
end

function latexinline(io::IO, md::Markdown.Bold)
    wrapinline(io, "textbf") do
        latexinline(io, md.text)
    end
end

function latexinline(io::IO, md::Markdown.Italic)
    wrapinline(io, "emph") do
        latexinline(io, md.text)
    end
end

function latexinline(io::IO, md::Markdown.Image)
    wrapblock(io, "figure") do
        _println(io, "\\centering")
        url = if Utilities.isabsurl(md.url)
            Utilities.warn("Images with absolute URLs not supported in LaTeX output.\n     in $(io.filename)\n     url: $(md.url)")
            # We nevertheless output an \includegraphics with the URL. The LaTeX build will
            # then give an error, indicating to the user that something wrong. Only the
            # warning would be drowned by all the output from LaTeX.
            md.url
        elseif startswith(md.url, '/')
            # URLs starting with a / are assumed to be relative to the document's root
            normpath(lstrip(md.url, '/'))
        else
            normpath(joinpath(dirname(io.filename), md.url))
        end
        wrapinline(io, "includegraphics") do
            _print(io, url)
        end
        _println(io)
        wrapinline(io, "caption") do
            latexinline(io, md.alt)
        end
        _println(io)
    end
end

if isdefined(Markdown, :Footnote)
    function latexinline(io::IO, f::Markdown.Footnote)
        local id = get!(io.footnotes, f.id, length(io.footnotes) + 1)
        _print(io, "\\footnotemark[", id, "]")
    end
end

function latexinline(io::IO, md::Markdown.Link)
    if io.in_header
        latexinline(io, md.text)
    else
        if contains(md.url, ".md#")
            file, target = split(md.url, ".md#"; limit = 2)
            local id = string(hash(target))
            wrapinline(io, "hyperlink") do
                _print(io, id)
            end
            _print(io, "{")
            latexinline(io, md.text)
            _print(io, "}")
        else
            wrapinline(io, "href") do
                latexesc(io, md.url)
            end
            _print(io, "{")
            latexinline(io, md.text)
            _print(io, "}")
        end
    end
end

function latexinline(io, math::Markdown.LaTeX)
    # Handle MathJax and TeX inconsistency since the first wants `\LaTeX` wrapped
    # in math delims, whereas actual TeX fails when that is done.
    math.formula == "\\LaTeX" ? _print(io, math.formula) : _print(io, "\\(", math.formula, "\\)")
end

function latexinline(io, hr::Markdown.HorizontalRule)
    _println(io, "\\rule{\\textwidth}{1pt}}")
end


# Metadata Nodes get dropped from the final output for every format but are needed throughout
# rest of the build and so we just leave them in place and print a blank line in their place.
latex(io::IO, node::Documents.MetaNode, page, doc) = _println(io, "\n")

# Utilities.

const _latexescape_chars = Dict{Char, AbstractString}(
    '~' => "{\\textasciitilde}",
    '^' => "{\\textasciicircum}",
    '\\' => "{\\textbackslash}",
    '\'' => "{\\textquotesingle}",
    '"' => "{\\textquotedbl}",
    '_' => "{\\_}",
)
for ch in "&%\$#_{}"
    _latexescape_chars[ch] = "\\$ch"
end

function latexesc(io, s::AbstractString)
    for ch in s
        _print(io, get(_latexescape_chars, ch, ch))
    end
end

latexesc(s) = sprint(latexesc, s)

function wrapblock(f, io, env)
    _println(io, "\\begin{", env, "}")
    f()
    _println(io, "\\end{", env, "}")
end

function wrapinline(f, io, cmd)
    _print(io, "\\", cmd, "{")
    f()
    _print(io, "}")
end

if isdefined(Markdown, :isordered)
    isordered(x) = Markdown.isordered(x)
else
    isordered(list::Markdown.List) = false
end


function files!(out::Vector, v::Vector, depth)
    for each in v
        files!(out, each, depth + 1)
    end
    return out
end

files!(out, s::AbstractString, depth) = push!(out, ("", s, depth))

function files!{S <: AbstractString, T <: AbstractString}(out, p::Pair{S, T}, depth)
    push!(out, (p.first, p.second, depth))
end

function files!{S <: AbstractString, V}(out, p::Pair{S, V}, depth)
    push!(out, (p.first, "", depth))
    files!(out, p.second, depth)
end

files(v::Vector) = files!(Tuple{Compat.String, Compat.String, Int}[], v, 0)

end
