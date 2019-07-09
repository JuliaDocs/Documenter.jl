"""
A module for rendering `Document` objects to LaTeX and PDF.

# Keywords

[`LaTeXWriter`](@ref) uses the following additional keyword arguments that can be passed to
[`makedocs`](@ref Documenter.makedocs): `authors`, `sitename`.

**`sitename`** is the site's title displayed in the title bar and at the top of the
navigation menu. It goes into the `\\title` LaTeX command.

**`authors`** can be used to specify the authors of. It goes into the `\\author` LaTeX command.

"""
module LaTeXWriter
import ...Documenter: Documenter

"""
    LaTeXWriter.LaTeX(; kwargs...)

Output format specifier that results in LaTeX/PDF output.
Used together with [`makedocs`](@ref Documenter.makedocs), e.g.

```julia
makedocs(
    format = LaTeX()
)
```

The `makedocs` argument `sitename` will be used for the `\\title` field in the tex document,
and if the build is for a release tag (i.e. when the `"TRAVIS_TAG"` environment variable is set)
the version number will be appended to the title.
The `makedocs` argument `authors` should also be specified, it will be used for the
`\\authors` field in the tex document.

# Keyword arguments

**`platform`** sets the platform where the tex-file is compiled, either `"native"` (default) or `"docker"`.
See [Other Output Formats](@ref) for more information.
"""
struct LaTeX <: Documenter.Writer
    platform::String
    function LaTeX(; platform = "native")
        platform ∈ ("native", "docker") || throw(ArgumentError("unknown platform: $platform"))
        return new(platform)
    end
end

import ...Documenter:
    Anchors,
    Builder,
    Documents,
    Expanders,
    Documenter,
    Utilities,
    Writers

import Markdown

mutable struct Context{I <: IO} <: IO
    io::I
    in_header::Bool
    footnotes::Dict{String, Int}
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

function render(doc::Documents.Document, settings::LaTeX=LaTeX())
    @info "LaTeXWriter: rendering PDF."
    mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            name = doc.user.sitename
            let tag = get(ENV, "TRAVIS_TAG", "")
                if occursin(Base.VERSION_REGEX, tag)
                    v = VersionNumber(tag)
                    name *= "-$(v.major).$(v.minor).$(v.patch)"
                end
            end
            name = replace(name, " " => "")
            texfile = name * ".tex"
            pdffile = name * ".pdf"
            open(texfile, "w") do io
                context = Context(io)
                writeheader(context, doc)
                for (title, filename, depth) in files(doc.user.pages)
                    context.filename = filename
                    empty!(context.footnotes)
                    if 1 <= depth <= length(DOCUMENT_STRUCTURE)
                        header_type = DOCUMENT_STRUCTURE[depth]
                        header_text = "\n\\$(header_type){$(title)}\n"
                        if isempty(filename)
                            _println(context, header_text)
                        else
                            path = normpath(filename)
                            page = doc.blueprint.pages[path]
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

            # compile .tex and copy over the .pdf file if compile_tex return true
            status = compile_tex(doc, settings, texfile)
            status && cp(pdffile, joinpath(doc.user.root, doc.user.build, pdffile); force = true)
        end
    end
end

const DOCKER_IMAGE_TAG = "0.1"

function compile_tex(doc::Documents.Document, settings::LaTeX, texfile::String)
    if settings.platform == "native"
        Sys.which("latexmk") === nothing && (@error "LaTeXWriter: latexmk command not found."; return false)
        @info "LaTeXWriter: using latexmk to compile tex."
        try
            piperun(`latexmk -f -interaction=nonstopmode -view=none -lualatex -shell-escape $texfile`)
            return true
        catch err
            logs = cp(pwd(), mktempdir(); force=true)
            @error "LaTeXWriter: failed to compile tex with latexmk. " *
                   "Logs and partial output can be found in $(Utilities.locrepr(logs))." exception = err
            return false
        end
    elseif settings.platform == "docker"
        Sys.which("docker") === nothing && (@error "LaTeXWriter: docker command not found."; return false)
        @info "LaTeXWriter: using docker to compile tex."
        script = """
            mkdir /home/zeptodoctor/build
            cd /home/zeptodoctor/build
            cp -r /mnt/. .
            latexmk -f -interaction=nonstopmode -view=none -lualatex -shell-escape $texfile
            """
        try
            piperun(`docker run -itd -u zeptodoctor --name latex-container -v $(pwd()):/mnt/ --rm juliadocs/documenter-latex:$(DOCKER_IMAGE_TAG)`)
            piperun(`docker exec -u zeptodoctor latex-container bash -c $(script)`)
            piperun(`docker cp latex-container:/home/zeptodoctor/build/. .`)
            return true
        catch err
            logs = cp(pwd(), mktempdir(); force=true)
            @error "LaTeXWriter: failed to compile tex with docker. " *
                   "Logs and partial output can be found in $(Utilities.locrepr(logs))." exception = err
            return false
        finally
            try; piperun(`docker stop latex-container`); catch; end
        end
    end
end

function piperun(cmd)
    verbose = "--verbose" in ARGS || get(ENV, "DOCUMENTER_VERBOSE", "false") == "true"
    run(pipeline(cmd, stdout = verbose ? stdout : "LaTeXWriter.stdout",
                      stderr = verbose ? stderr : "LaTeXWriter.stderr"))
end

function writeheader(io::IO, doc::Documents.Document)
    custom = joinpath(doc.user.root, doc.user.source, "assets", "custom.sty")
    isfile(custom) ? cp(custom, "custom.sty"; force = true) : touch("custom.sty")
    preamble =
        """
        \\documentclass{memoir}

        \\usepackage{./documenter}
        \\usepackage{./custom}

        \\title{
            {\\HUGE $(doc.user.sitename)}\\\\
            {\\Large $(get(ENV, "TRAVIS_TAG", ""))}
        }
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
    id = string(hash(string(anchor.id, "-", anchor.nth)))
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
    id = string(hash(string(node.anchor.id)))
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
            url = Utilities.url(doc.internal.remote, doc.user.repo, result)
            if url !== nothing
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
        id = string(hash(string(Utilities.slugify(object))))
        text = string(object.binding)
        _print(io, "\\item \\hyperlink{")
        _print(io, id, "}{\\texttt{")
        latexesc(io, text)
        _println(io, "}}")
    end
    _println(io, "\\end{itemize}\n")
end

function latex(io::IO, contents::Documents.ContentsNode, page, doc)
    depth = 1
    needs_end = false
    _println(io, "\\begin{itemize}")
    for (count, path, anchor) in contents.elements
        header = anchor.object
        level = Utilities.header_level(header)
        id = string(hash(string(anchor.id, "-", anchor.nth)))
        level < depth && (_println(io, "\\end{itemize}"); needs_end = false)
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

# Select the "best" representation for LaTeX output.
using Base64: base64decode
function latex(io::IO, mo::Documents.MultiOutput)
    foreach(x->Base.invokelatest(latex, io, x), mo.content)
end
function latex(io::IO, d::Dict{MIME,Any})
    filename = String(rand('a':'z', 7))
    if haskey(d, MIME"image/png"())
        write("$(filename).png", base64decode(d[MIME"image/png"()]))
        _println(io, """
        \\begin{figure}[H]
        \\centering
        \\includegraphics{$(filename)}
        \\end{figure}
        """)
    elseif haskey(d, MIME"image/jpeg"())
        write("$(filename).jpeg", base64decode(d[MIME"image/jpeg"()]))
        _println(io, """
        \\begin{figure}[H]
        \\centering
        \\includegraphics{$(filename)}
        \\end{figure}
        """)
    elseif haskey(d, MIME"text/latex"())
        latex(io, Utilities.mdparse(d[MIME"text/latex"()]; mode = :single))
    elseif haskey(d, MIME"text/markdown"())
        latex(io, Markdown.parse(d[MIME"text/markdown"()]))
    elseif haskey(d, MIME"text/plain"())
        latex(io, Markdown.Code(d[MIME"text/plain"()]))
    else
        error("this should never happen.")
    end
    return nothing
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

function latex(io::IO, h::Markdown.Header{N}) where N
    tag = DOCUMENT_STRUCTURE[min(io.depth + N - 1, length(DOCUMENT_STRUCTURE))]
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
    language = isempty(code.language) ? "none" : code.language
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

function latex(io::IO, md::Markdown.Admonition)
    wrapblock(io, "quote") do
        wrapinline(io, "textbf") do
            _print(io, md.title)
        end
        _println(io, "\n")
        latex(io, md.content)
    end
end

function latex(io::IO, f::Markdown.Footnote)
    id = get(io.footnotes, f.id, 1)
    _print(io, "\\footnotetext[", id, "]{")
    latex(io, f.text)
    _println(io, "}")
end

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
    fmt = n -> (Markdown.isordered(md) ? "[$(rpad("$(n + md.ordered - 1).", pad))]" : "")
    wrapblock(io, "itemize") do
        for (n, item) in enumerate(md.items)
            _print(io, "\\item$(fmt(n)) ")
            latex(io, item)
            n < length(md.items) && _println(io)
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
            @warn "images with absolute URLs not supported in LaTeX output in $(Utilities.locrepr(io.filename))" url = md.url
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
        url = replace(url, "\\" => "/") # use / on Windows too.
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

function latexinline(io::IO, f::Markdown.Footnote)
    id = get!(io.footnotes, f.id, length(io.footnotes) + 1)
    _print(io, "\\footnotemark[", id, "]")
end

function latexinline(io::IO, md::Markdown.Link)
    if io.in_header
        latexinline(io, md.text)
    else
        if occursin(".md#", md.url)
            file, target = split(md.url, ".md#"; limit = 2)
            id = string(hash(target))
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


function files!(out::Vector, v::Vector, depth)
    for each in v
        files!(out, each, depth + 1)
    end
    return out
end

# Tuples come from `hide(page)` with either
# (visible, nothing,    page,         children) or
# (visible, page.first, pages.second, children)
function files!(out::Vector, v::Tuple, depth)
    files!(out, v[2] == nothing ? v[3] : v[2] => v[3], depth)
    files!(out, v[4], depth)
end

files!(out, s::AbstractString, depth) = push!(out, ("", s, depth))

function files!(out, p::Pair{S, T}, depth) where {S <: AbstractString, T <: AbstractString}
    push!(out, (p.first, p.second, depth))
end

function files!(out, p::Pair{S, V}, depth) where {S <: AbstractString, V}
    push!(out, (p.first, "", depth))
    files!(out, p.second, depth)
end

files(v::Vector) = files!(Tuple{String, String, Int}[], v, 0)

end
