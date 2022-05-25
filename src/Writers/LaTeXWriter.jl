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
    Documenter.LaTeX(; kwargs...)

Output format specifier that results in LaTeX/PDF output.
Used together with [`makedocs`](@ref Documenter.makedocs), e.g.

```julia
makedocs(
    format = Documenter.LaTeX()
)
```

The `makedocs` argument `sitename` will be used for the `\\title` field in the tex document.
The `authors` argument should also be specified and will be used for the `\\authors` field
in the tex document. Finally, a version number can be specified with the `version` option to
`LaTeX`, which will be printed in the document and also appended to the output PDF file name.

# Keyword arguments

**`platform`** sets the platform where the tex-file is compiled, either `"native"` (default),
`"tectonic"`, `"docker"`, or "none" which doesn't compile the tex. The option `tectonic`
requires a `tectonic` executable to be available in `PATH` or to be pased as the `tectonic`
keyword.

**`version`** specifies the version number that gets printed on the title page of the manual.
It defaults to the value in the `TRAVIS_TAG` environment variable (although this behaviour is
considered to be deprecated), or to an empty string if `TRAVIS_TAG` is unset.

**`tectonic`** path to a `tectonic` executable used for compilation.

See [Other Output Formats](@ref) for more information.
"""
struct LaTeX <: Documenter.Writer
    platform::String
    version::String
    tectonic::Union{Cmd,String,Nothing}
    function LaTeX(;
            platform = "native",
            version  = get(ENV, "TRAVIS_TAG", ""),
            tectonic = nothing)
        platform ∈ ("native", "tectonic", "docker", "none") || throw(ArgumentError("unknown platform: $platform"))
        return new(platform, string(version), tectonic)
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

import ANSIColoredPrinters

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
const DEFAULT_PREAMBLE_PATH = joinpath(dirname(@__FILE__), "..", "..", "assets", "latex", "preamble.tex")

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

# https://github.com/JuliaLang/julia/pull/32851
function mktempdir(args...; kwargs...)
    if VERSION < v"1.3.0-alpha.112"
        return Base.mktempdir(args...; kwargs...)
    else
        return Base.mktempdir(args...; cleanup=false, kwargs...)
    end
end

function render(doc::Documents.Document, settings::LaTeX=LaTeX())
    @info "LaTeXWriter: creating the LaTeX file."
    Base.mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            fileprefix = doc.user.sitename
            if occursin(Base.VERSION_REGEX, settings.version)
                v = VersionNumber(settings.version)
                fileprefix *= "-$(v.major).$(v.minor).$(v.patch)"
            end
            fileprefix = replace(fileprefix, " " => "")

            open("$(fileprefix).tex", "w") do io
                context = Context(io)
                writeheader(context, doc, settings)
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

            # compile .tex
            status = compile_tex(doc, settings, fileprefix)

            # Debug: if DOCUMENTER_LATEX_DEBUG environment variable is set, copy the LaTeX
            # source files over to a directory under doc.user.root.
            if haskey(ENV, "DOCUMENTER_LATEX_DEBUG")
                dst = isempty(ENV["DOCUMENTER_LATEX_DEBUG"]) ? mktempdir(doc.user.root) :
                    joinpath(doc.user.root, ENV["DOCUMENTER_LATEX_DEBUG"])
                sources = cp(pwd(), dst, force=true)
                @info "LaTeX sources copied for debugging to $(sources)"
            end

            # If the build was successful, copy the PDF or the LaTeX source to the .build directory
            if status && (settings.platform != "none")
                pdffile = "$(fileprefix).pdf"
                cp(pdffile, joinpath(doc.user.root, doc.user.build, pdffile); force = true)
            elseif status && (settings.platform == "none")
                cp(pwd(), joinpath(doc.user.root, doc.user.build); force = true)
            else
                error("Compiling the .tex file failed. See logs for more information.")
            end
        end
    end
end

const DOCKER_IMAGE_TAG = "0.1"

function compile_tex(doc::Documents.Document, settings::LaTeX, fileprefix::String)
    if settings.platform == "native"
        Sys.which("latexmk") === nothing && (@error "LaTeXWriter: latexmk command not found."; return false)
        @info "LaTeXWriter: using latexmk to compile tex."
        try
            piperun(`latexmk -f -interaction=nonstopmode -view=none -lualatex -shell-escape $(fileprefix).tex`, clearlogs = true)
            return true
        catch err
            logs = cp(pwd(), mktempdir(); force=true)
            @error "LaTeXWriter: failed to compile tex with latexmk. " *
                   "Logs and partial output can be found in $(Utilities.locrepr(logs))." exception = err
            return false
        end
    elseif settings.platform == "tectonic"
        @info "LaTeXWriter: using tectonic to compile tex."
        tectonic = isnothing(settings.tectonic) ? Sys.which("tectonic") : settings.tectonic
        isnothing(tectonic) && (@error "LaTeXWriter: tectonic command not found."; return false)
        try
            piperun(`$(tectonic) -X compile --keep-logs -Z shell-escape $(fileprefix).tex`, clearlogs = true)
            return true
        catch err
            logs = cp(pwd(), mktempdir(); force=true)
            @error "LaTeXWriter: failed to compile tex with tectonic. " *
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
            latexmk -f -interaction=nonstopmode -view=none -lualatex -shell-escape $(fileprefix).tex
            """
        try
            piperun(`docker run -itd -u zeptodoctor --name latex-container -v $(pwd()):/mnt/ --rm juliadocs/documenter-latex:$(DOCKER_IMAGE_TAG)`, clearlogs = true)
            piperun(`docker exec -u zeptodoctor latex-container bash -c $(script)`)
            piperun(`docker cp latex-container:/home/zeptodoctor/build/$(fileprefix).pdf .`)
            return true
        catch err
            logs = cp(pwd(), mktempdir(); force=true)
            @error "LaTeXWriter: failed to compile tex with docker. " *
                   "Logs and partial output can be found in $(Utilities.locrepr(logs))." exception = err
            return false
        finally
            try; piperun(`docker stop latex-container`); catch; end
        end
    elseif settings.platform == "none"
        @info "Skipping compiling tex file."
        return true
    end
end

function piperun(cmd; clearlogs = false)
    verbose = "--verbose" in ARGS || get(ENV, "DOCUMENTER_VERBOSE", "false") == "true"
    run(verbose ? cmd : pipeline(
        cmd,
        stdout = "LaTeXWriter.stdout",
        stderr = "LaTeXWriter.stderr",
        append = !clearlogs,
    ))
end

function writeheader(io::IO, doc::Documents.Document, settings::LaTeX)
    custom = joinpath(doc.user.root, doc.user.source, "assets", "custom.sty")
    isfile(custom) ? cp(custom, "custom.sty"; force = true) : touch("custom.sty")

    custom_preamble_file = joinpath(doc.user.root, doc.user.source, "assets", "preamble.tex")
    if isfile(custom_preamble_file)
        # copy custom preamble.
        cp(custom_preamble_file, "preamble.tex"; force = true)
    else # no custom preamble.tex, use default.
        cp(DEFAULT_PREAMBLE_PATH, "preamble.tex"; force = true)
    end
    preamble =
        """
        % Useful variables
        \\newcommand{\\DocMainTitle}{$(doc.user.sitename)}
        \\newcommand{\\DocVersion}{$(settings.version)}
        \\newcommand{\\DocAuthors}{$(doc.user.authors)}
        \\newcommand{\\JuliaVersion}{$(VERSION)}

        % ---- Insert preamble
        \\input{preamble.tex}
        """
    # output preamble
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
            latex(io, Utilities.dropheaders(markdown), page, doc)
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
        render(io, mime, Utilities.dropheaders(md), page, doc)
    end
end

function latexdoc(io::IO, other, page, doc)
    # TODO: properly support non-markdown docstrings at some point.
    latex(io, other, page, doc)
end


## Index, Contents, and Eval Nodes.

function latex(io::IO, index::Documents.IndexNode, page, doc)
    # Having an empty itemize block in LaTeX throws an error, so we bail early
    # in that situation:
    isempty(index.elements) && (_println(io); return)

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
    # Having an empty itemize block in LaTeX throws an error, so we bail early
    # in that situation:
    isempty(contents.elements) && (_println(io); return)

    depth = 1
    _println(io, "\\begin{itemize}")
    for (count, path, anchor) in contents.elements
        header = anchor.object
        level = Utilities.header_level(header)
        id = string(hash(string(anchor.id, "-", anchor.nth)))
        # If we're changing depth, we need to make sure we always print the
        # correct number of \begin{itemize} and \end{itemize} statements.
        if level > depth
            for k in 1:(level - depth)
                # if we jump by more than one level deeper we need to put empty
                # \items in -- otherwise LaTeX will complain
                (k >= 2) && _println(io, "\\item ~")
                _println(io, "\\begin{itemize}")
                depth += 1
            end
        elseif level < depth
            for _ in 1:(depth - level)
                _println(io, "\\end{itemize}")
                depth -= 1
            end
        end
        # Print the corresponding \item statement
        _print(io, "\\item \\hyperlink{", id, "}{")
        latexinline(io, header.text)
        _println(io, "}")
    end
    # print any remaining missing \end{itemize} statements
    for _ = 1:depth; _println(io, "\\end{itemize}"); end
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
        \\includegraphics[max width=\\linewidth]{$(filename)}
        \\end{figure}
        """)
    elseif haskey(d, MIME"image/jpeg"())
        write("$(filename).jpeg", base64decode(d[MIME"image/jpeg"()]))
        _println(io, """
        \\begin{figure}[H]
        \\centering
        \\includegraphics[max width=\\linewidth]{$(filename)}
        \\end{figure}
        """)
    elseif haskey(d, MIME"text/latex"())
        # If it has a latex MIME, just write it out directly.
        _print(io, d[MIME"text/latex"()])
    elseif haskey(d, MIME"text/markdown"())
        latex(io, Markdown.parse(d[MIME"text/markdown"()]))
    elseif haskey(d, MIME"text/plain"())
        text = d[MIME"text/plain"()]
        out = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(IOBuffer(text)))
        latex(io, Markdown.Code(out))
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
    language = Utilities.codelang(code.language)
    language = isempty(language) ? "none" :
        (language == "julia-repl") ? "jlcon" : # the julia-repl is called "jlcon" in Pygments
        language
    text = IOBuffer(code.code)
    code.code = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(text))
    escape = '⊻' ∈ code.code
    if language in LEXER
        _print(io, "\n\\begin{minted}")
        if escape
            _print(io, "[escapeinside=\\#\\%]")
        end
        _println(io, "{", language, "}")
        if escape
            _print_code_escapes_minted(io, code.code)
        else
            _print(io, code.code)
        end
        _println(io, "\n\\end{minted}\n")
    else
        _print(io, "\n\\begin{lstlisting}")
        if escape
            _println(io, "[escapeinside=\\%\\%]")
            _print_code_escapes_lstlisting(io, code.code)
        else
            _println(io)
            _print(io, code.code)
        end
        _println(io, "\n\\end{lstlisting}\n")
    end
end

function latex(io::IO, mcb::Documents.MultiCodeBlock)
    latex(io, Documents.join_multiblock(mcb))
end

function _print_code_escapes_minted(io, s::AbstractString)
    for ch in s
        ch === '#' ? _print(io, "##%") :
        ch === '%' ? _print(io, "#%%") : # Note: "#\\%%" results in pygmentize error...
        ch === '⊻' ? _print(io, "#\\unicodeveebar%") :
                     _print(io, ch)
    end
end
function _print_code_escapes_lstlisting(io, s::AbstractString)
    for ch in s
        ch === '%' ? _print(io, "%\\%%") :
        ch === '⊻' ? _print(io, "%\\unicodeveebar%") :
                     _print(io, ch)
    end
end

function latexinline(io::IO, code::Markdown.Code)
    _print(io, "\\texttt{")
    _print_code_escapes_inline(io, code.code)
    _print(io, "}")
end

function _print_code_escapes_inline(io, s::AbstractString)
    for ch in s
        ch === '⊻' ? _print(io, "\\unicodeveebar{}") :
                     latexesc(io, ch)
    end
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
            latexinline(io, md.title)
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

# This (equation*, split) math env seems to be the only way to correctly render all the
# equations in the Julia manual. However, if the equation is already wrapped in
# align/align*, then there is no need to further wrap it (in fact, it will break).
function latex(io::IO, math::Markdown.LaTeX)
    if occursin(r"^\\begin\{align\*?\}", math.formula)
        _print(io, math.formula)
    else
        _print(io, "\\begin{equation*}\n\\begin{split}")
        _print(io, math.formula)
        _println(io, "\\end{split}\\end{equation*}")
    end
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
        wrapinline(io, "includegraphics[max width=\\linewidth]") do
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
        else
            wrapinline(io, "href") do
                latexesc(io, md.url)
            end
        end
        _print(io, "{")
        latexinline(io, md.text)
        _print(io, "}")
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
)
for ch in "&%\$#_{}"
    _latexescape_chars[ch] = "\\$ch"
end

latexesc(io, ch::AbstractChar) = _print(io, get(_latexescape_chars, ch, ch))

function latexesc(io, s::AbstractString)
    for ch in s
        latexesc(io, ch)
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

function files!(out, p::Pair{<:AbstractString,<:Any}, depth)
    # Hack time. Because of Julia's typing, something like
    # `"Introduction" => "index.md"` may get typed as a `Pair{String,Any}`!
    if p[2] isa AbstractString
        push!(out, (p.first, p.second, depth))
    else
        push!(out, (p.first, "", depth))
        files!(out, p.second, depth)
    end
    return out
end

files(v::Vector) = files!(Tuple{String, String, Int}[], v, 0)

end
