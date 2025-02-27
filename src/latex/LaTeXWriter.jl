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
using MarkdownAST: MarkdownAST, Node

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
requires a `tectonic` executable to be available in `PATH` or to be passed as the `tectonic`
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
    tectonic::Union{Cmd, String, Nothing}
    function LaTeX(;
            platform = "native",
            version = get(ENV, "TRAVIS_TAG", ""),
            tectonic = nothing
        )
        platform ∈ ("native", "tectonic", "docker", "none") || throw(ArgumentError("unknown platform: $platform"))
        return new(platform, string(version), tectonic)
    end
end

import ..Documenter
import Markdown
import ANSIColoredPrinters

mutable struct Context{I <: IO} <: IO
    io::I
    in_header::Bool
    footnotes::Dict{String, Int}
    depth::Int
    filename::String # currently active source file
    doc::Documenter.Document
end
Context(io, doc) = Context{typeof(io)}(io, false, Dict(), 1, "", doc)

_print(c::Context, args...) = Base.print(c.io, args...)
_println(c::Context, args...) = Base.println(c.io, args...)
_print(io, args...) = Base.print(io, args...)

# Labels in the TeX file are hashes of plain text labels.
# To keep the plain text label (for debugging), say _hash(x) = x
_hash(x) = string(hash(x))


const STYLE = joinpath(dirname(@__FILE__), "..", "..", "assets", "latex", "documenter.sty")
const DEFAULT_PREAMBLE_PATH = joinpath(dirname(@__FILE__), "..", "..", "assets", "latex", "preamble.tex")

function hastex()
    try
        return success(`latexmk -version`)
    catch
        return false
    end
end

const DOCUMENT_STRUCTURE = (
    "part",
    "chapter",
    "section",
    "subsection",
    "subsubsection",
    "paragraph",
    "subparagraph",
)

function render(doc::Documenter.Document, settings::LaTeX = LaTeX())
    if isempty(doc.user.sitename) # otherwise, the latex compiler will terminate with a cryptic "There's no line here to end" error
        error(
            """
            LaTeXWriter needs a non-empty `sitename` passed to `makedocs`, otherwise the LaTeX build will error!  
            Please pass e.g. `sitename = "Some Site Name"` as a keyword argument to `makedocs`.
            """
        )
    end

    @info "LaTeXWriter: creating the LaTeX file."
    mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            fileprefix = latex_fileprefix(doc, settings)
            open("$(fileprefix).tex", "w") do io
                context = Context(io, doc)
                writeheader(context, doc, settings)
                for (title, filename, depth) in files(doc.user.pages)
                    context.filename = filename
                    empty!(context.footnotes)
                    if 1 <= depth <= length(DOCUMENT_STRUCTURE)
                        header_type = DOCUMENT_STRUCTURE[depth]
                        title_text = latexesc("$title")
                        header_text = "\n\\$(header_type){$title_text}\n"
                        if isempty(filename)
                            _println(context, header_text)
                        else
                            path = normpath(filename)
                            page = doc.blueprint.pages[path]
                            if get(page.globals.meta, :IgnorePage, :none) !== :latex
                                context.depth = depth + (isempty(title) ? 0 : 1)
                                context.depth > depth && _println(context, header_text)
                                latex(context, page.mdast.children; toplevel = true)
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
                dst = isempty(ENV["DOCUMENTER_LATEX_DEBUG"]) ? mktempdir(doc.user.root; cleanup = false) :
                    joinpath(doc.user.root, ENV["DOCUMENTER_LATEX_DEBUG"])
                sources = cp(pwd(), dst, force = true)
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
    return
end

function latex_fileprefix(doc::Documenter.Document, settings::LaTeX)
    fileprefix = doc.user.sitename
    if occursin(Base.VERSION_REGEX, settings.version)
        v = VersionNumber(settings.version)
        fileprefix *= "-$(v.major).$(v.minor).$(v.patch)"
    end
    return replace(fileprefix, " " => "")
end

const DOCKER_IMAGE_TAG = "0.1"

function compile_tex(doc::Documenter.Document, settings::LaTeX, fileprefix::String)
    if settings.platform == "native"
        Sys.which("latexmk") === nothing && (@error "LaTeXWriter: latexmk command not found."; return false)
        @info "LaTeXWriter: using latexmk to compile tex."
        try
            piperun(`latexmk -f -interaction=batchmode -halt-on-error -view=none -lualatex -shell-escape $(fileprefix).tex`, clearlogs = true)
            return true
        catch err
            logs = cp(pwd(), mktempdir(; cleanup = false); force = true)
            @error "LaTeXWriter: failed to compile tex with latexmk. " *
                "Logs and partial output can be found in $(Documenter.locrepr(logs))" exception = err
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
            logs = cp(pwd(), mktempdir(; cleanup = false); force = true)
            @error "LaTeXWriter: failed to compile tex with tectonic. " *
                "Logs and partial output can be found in $(Documenter.locrepr(logs))" exception = err
            return false
        end
    elseif settings.platform == "docker"
        Sys.which("docker") === nothing && (@error "LaTeXWriter: docker command not found."; return false)
        @info "LaTeXWriter: using docker to compile tex."
        script = """
        mkdir /home/zeptodoctor/build
        cd /home/zeptodoctor/build
        cp -r /mnt/. .
        latexmk -f -interaction=batchmode -halt-on-error -view=none -lualatex -shell-escape $(fileprefix).tex
        """
        try
            piperun(`docker run -itd -u zeptodoctor --name latex-container -v $(pwd()):/mnt/ --rm juliadocs/documenter-latex:$(DOCKER_IMAGE_TAG)`, clearlogs = true)
            piperun(`docker exec -u zeptodoctor latex-container bash -c $(script)`)
            piperun(`docker cp latex-container:/home/zeptodoctor/build/$(fileprefix).pdf .`)
            return true
        catch err
            logs = cp(pwd(), mktempdir(; cleanup = false); force = true)
            @error "LaTeXWriter: failed to compile tex with docker. " *
                "Logs and partial output can be found in $(Documenter.locrepr(logs))" exception = err
            return false
        finally
            try
                piperun(`docker stop latex-container`)
            catch
            end
        end
    elseif settings.platform == "none"
        @info "Skipping compiling tex file."
        return true
    end
end

function piperun(cmd; clearlogs = false)
    verbose = "--verbose" in ARGS || get(ENV, "DOCUMENTER_VERBOSE", "false") == "true"
    if verbose
        cmd = pipeline(
            cmd,
            stdout = "LaTeXWriter.stdout", stderr = "LaTeXWriter.stderr",
            append = !clearlogs,
        )
    end
    return run(cmd)
end

function writeheader(io::IO, doc::Documenter.Document, settings::LaTeX)
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
    return
end

function writefooter(io::IO, doc::Documenter.Document)
    _println(io, "\n\\end{document}")
    return
end

# A few of the nodes are printed differently depending on whether they appear
# as the top-level blocks of a page, or somewhere deeper in the AST.
istoplevel(n::Node) = !isnothing(n.parent) && isa(n.parent.element, MarkdownAST.Document)

latex(io::Context, node::Node) = latex(io, node, node.element)
latex(io::Context, node::Node, e) = error("$(typeof(e)) not implemented: $e")

function latex(io::Context, children; toplevel = false)
    @assert eltype(children) <: MarkdownAST.Node
    for node in children
        otherelement = !isa(node.element, NoExtraTopLevelNewlines)
        toplevel && otherelement && _println(io)
        latex(io, node)
        toplevel && otherelement && _println(io)
    end
    return
end
const NoExtraTopLevelNewlines = Union{
    Documenter.AnchoredHeader,
    Documenter.ContentsNode,
    Documenter.DocsNode,
    Documenter.DocsNodesBlock,
    Documenter.EvalNode,
    Documenter.IndexNode,
    Documenter.MetaNode,
}

function latex(io::Context, node::Node, ah::Documenter.AnchoredHeader)
    anchor = ah.anchor
    # latex(io::IO, anchor::Anchor, page, doc)
    id = _hash(Documenter.anchor_label(anchor))
    latex(io, node.children; toplevel = istoplevel(node))
    _println(io, "\n\\label{", id, "}{}\n")
    return
end

## Documentation Nodes.

function latex(io::Context, node::Node, ::Documenter.DocsNodesBlock)
    return latex(io, node.children; toplevel = istoplevel(node))
end

function latex(io::Context, node::Node, docs::Documenter.DocsNode)
    node, ast = docs, node
    # latex(io::IO, node::Documenter.DocsNode, page, doc)
    id = _hash(Documenter.anchor_label(node.anchor))
    # Docstring header based on the name of the binding and it's category.
    _print(io, "\\hypertarget{", id, "}{\\texttt{")
    latexesc(io, string(node.object.binding))
    _print(io, "}} ")
    _println(io, " -- {", Documenter.doccat(node.object), ".}\n")
    # # Body. May contain several concatenated docstrings.
    _println(io, "\\begin{adjustwidth}{2em}{0pt}")
    latexdoc(io, ast)
    _println(io, "\n\\end{adjustwidth}")
    return
end

function latexdoc(io::IO, node::Node)
    @assert node.element isa Documenter.DocsNode
    # The `:results` field contains a vector of `Docs.DocStr` objects associated with
    # each markdown object. The `DocStr` contains data such as file and line info that
    # we need for generating correct source links.
    for (docstringast, result) in zip(node.element.mdasts, node.element.results)
        _println(io)
        latex(io, docstringast.children)
        _println(io)
        # When a source link is available then print the link.
        url = Documenter.source_url(io.doc, result)
        if url !== nothing
            link = "\\href{$url}{\\texttt{source}}"
            _println(io, "\n", link, "\n")
        end
    end
    return
end

## Index, Contents, and Eval Nodes.

function latex(io::Context, node::Node, index::Documenter.IndexNode)
    # Having an empty itemize block in LaTeX throws an error, so we bail early
    # in that situation:
    isempty(index.elements) && (_println(io); return)

    _println(io, "\\begin{itemize}")
    for (object, _, page, mod, cat) in index.elements
        id = _hash(string(Documenter.slugify(object)))
        text = string(object.binding)
        _print(io, "\\item \\hyperlinkref{")
        _print(io, id, "}{\\texttt{")
        latexesc(io, text)
        _println(io, "}}")
    end
    _println(io, "\\end{itemize}\n")
    return
end

function latex(io::Context, node::Node, contents::Documenter.ContentsNode)
    # Having an empty itemize block in LaTeX throws an error, so we bail early
    # in that situation:
    isempty(contents.elements) && (_println(io); return)

    depth = 1
    _println(io, "\\begin{itemize}")
    for (count, path, anchor) in contents.elements
        @assert length(anchor.node.children) == 1
        header = first(anchor.node.children)
        level = header.element.level
        # Filter out header levels smaller than the requested mindepth
        level = level - contents.mindepth + 1
        level < 1 && continue
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
        id = _hash(Documenter.anchor_label(anchor))
        _print(io, "\\item \\hyperlinkref{", id, "}{")
        latex(io, header.children)
        _println(io, "}")
    end
    # print any remaining missing \end{itemize} statements
    for _ in 1:depth
        _println(io, "\\end{itemize}")
    end
    _println(io)
    return
end

function latex(io::Context, node::Node, evalnode::Documenter.EvalNode)
    if evalnode.result !== nothing
        latex(io, evalnode.result.children, toplevel = true)
    end
    return
end

# Select the "best" representation for LaTeX output.
using Base64: base64decode
latex(io::Context, node::Node, ::Documenter.MultiOutput) = latex(io, node.children)
function latex(io::Context, node::Node, moe::Documenter.MultiOutputElement)
    return Base.invokelatest(latex, io, node, moe.element)
end
function latex(io::Context, ::Node, d::Dict{MIME, Any})
    filename = String(rand('a':'z', 7))
    if haskey(d, MIME"image/png"())
        write("$(filename).png", base64decode(d[MIME"image/png"()]))
        _println(
            io, """
            \\begin{figure}[H]
            \\centering
            \\includegraphics[max width=\\linewidth]{$(filename)}
            \\end{figure}
            """
        )
    elseif haskey(d, MIME"image/jpeg"())
        write("$(filename).jpeg", base64decode(d[MIME"image/jpeg"()]))
        _println(
            io, """
            \\begin{figure}[H]
            \\centering
            \\includegraphics[max width=\\linewidth]{$(filename)}
            \\end{figure}
            """
        )
    elseif haskey(d, MIME"text/latex"())
        # If it has a latex MIME, just write it out directly.
        content = d[MIME("text/latex")]
        if startswith(content, "\\begin{tabular}")
            # This is a hacky fix for the printing of DataFrames (or any type
            # that produces a {tabular} environment). The biggest problem is
            # that tables with may columns will run off the page. An ideal fix
            # would be for the printing to omit some columns, but we don't have
            # the luxury here. So instead we just rescale everything until it
            # fits. This might make the rows too small, but it's arguably better
            # than having them go off the page.
            _println(io, "\\begin{table}[h]\n\\centering")
            _println(io, "\\adjustbox{max width=\\linewidth}{")
            _print(io, content)
            _println(io, "}\\end{table}")
        else
            _print(io, content)
        end
    elseif haskey(d, MIME"text/markdown"())
        md = Markdown.parse(d[MIME"text/markdown"()])
        ast = MarkdownAST.convert(MarkdownAST.Node, md)
        latex(io, ast.children)
    elseif haskey(d, MIME"text/plain"())
        text = d[MIME"text/plain"()]
        out = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(IOBuffer(text)))
        # We set a "fake" language as text/plain so that the writer knows how to
        # deal with it.
        codeblock = MarkdownAST.CodeBlock("text/plain", out)
        latex(io, MarkdownAST.Node(codeblock))
    else
        error("this should never happen.")
    end
    return nothing
end


## Basic Nodes. AKA: any other content that hasn't been handled yet.

function latex(io::Context, node::Node, heading::MarkdownAST.Heading)
    N = heading.level
    # latex(io::IO, h::Markdown.Header{N}) where N
    tag = DOCUMENT_STRUCTURE[min(io.depth + N - 1, length(DOCUMENT_STRUCTURE))]
    _print(io, "\\", tag, "{")
    io.in_header = true
    latex(io, node.children)
    io.in_header = false
    # {sub}pagragraphs need an explicit `\indent` after them
    # to ensure the following text is on a new line. Others
    if endswith(tag, "paragraph")
        _println(io, "}\\indent\n")
    else
        _println(io, "}\n")
    end
    return
end

# Whitelisted lexers.
const LEXER = Set(
    [
        "julia",
        "jlcon",
        "text",
    ]
)

function latex(io::Context, node::Node, code::MarkdownAST.CodeBlock)
    language = Documenter.codelang(code.info)
    if language == "julia-repl"
        language = "jlcon"  # the julia-repl is called "jlcon" in Pygments
    elseif !(language in LEXER) && language != "text/plain"
        # For all others, like ```python or ```markdown, render as text.
        language = "text"
    end
    text = IOBuffer(code.code)
    code_code = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(text))
    escape = '⊻' ∈ code_code
    _print(io, "\n\\begin{minted}")
    if escape
        _print(io, "[escapeinside=\\#\\%")
    end
    if language == "text/plain"
        _print(io, escape ? "," : "[")
        # Special-case the formatting of code outputs from Julia.
        _println(io, "xleftmargin=-\\fboxsep,xrightmargin=-\\fboxsep,bgcolor=white,frame=single]{text}")
    else
        _println(io, escape ? "]{" : "{", language, "}")
    end
    if escape
        _print_code_escapes_minted(io, code_code)
    else
        _print(io, code_code)
    end
    _println(io, "\n\\end{minted}\n")
    return
end

latex(io::Context, node::Node, mcb::Documenter.MultiCodeBlock) = latex(io, node, join_multiblock(node))
function join_multiblock(node::Node)
    @assert node.element isa Documenter.MultiCodeBlock
    io = IOBuffer()
    codeblocks = [n.element::MarkdownAST.CodeBlock for n in node.children]
    for (i, thing) in enumerate(codeblocks)
        print(io, thing.code)
        if i != length(codeblocks)
            println(io)
            if findnext(x -> x.info == node.element.language, codeblocks, i + 1) == i + 1
                println(io)
            end
        end
    end
    return MarkdownAST.CodeBlock(node.element.language, String(take!(io)))
end

function _print_code_escapes_minted(io, s::AbstractString)
    for ch in s
        ch === '#' ? _print(io, "##%") :
            ch === '%' ? _print(io, "#%%") : # Note: "#\\%%" results in pygmentize error...
            ch === '⊻' ? _print(io, "#\\unicodeveebar%") :
            _print(io, ch)
    end
    return
end

function latex(io::Context, node::Node, code::MarkdownAST.Code)
    _print(io, "\\texttt{")
    _print_code_escapes_inline(io, code.code)
    _print(io, "}")
    return
end

function _print_code_escapes_inline(io, s::AbstractString)
    for ch in s
        ch === '⊻' ? _print(io, "\\unicodeveebar{}") : latexesc(io, ch)
    end
    return
end

function latex(io::Context, node::Node, ::MarkdownAST.Paragraph)
    latex(io, node.children)
    _println(io, "\n")
    return
end

function latex(io::Context, node::Node, ::MarkdownAST.BlockQuote)
    wrapblock(io, "quote") do
        latex(io, node.children)
    end
    return
end

function latex(io::Context, node::Node, md::MarkdownAST.Admonition)
    color = "admonition-default"
    if md.category in ("danger", "warning", "note", "info", "tip", "compat", "todo")
        color = "admonition-$(md.category)"
    end
    _print(io, "\\begin{tcolorbox}[toptitle=-1mm,bottomtitle=1mm,")
    _print(io, "colback=$(color)!50!white,colframe=$(color),")
    _print(io, "title=\\textbf{")
    latexesc(io, md.title)
    _println(io, "}]")
    latex(io, node.children)
    _println(io, "\\end{tcolorbox}")
    return
end

function latex(io::Context, node::Node, f::MarkdownAST.FootnoteDefinition)
    id = get(io.footnotes, f.id, 1)
    _print(io, "\\footnotetext[", id, "]{")
    latex(io, node.children)
    _println(io, "}")
    return
end

function latex(io::Context, node::Node, list::MarkdownAST.List)
    # TODO: MarkdownAST doesn't support lists starting at arbitrary numbers
    isordered = (list.type === :ordered)
    ordered = (list.type === :bullet) ? -1 : 1
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
    pad = ndigits(ordered + length(node.children)) + 2
    fmt = n -> (isordered ? "[$(rpad("$(n + ordered - 1).", pad))]" : "")
    wrapblock(io, "itemize") do
        for (n, item) in enumerate(node.children)
            _print(io, "\\item$(fmt(n)) ")
            latex(io, item.children)
            n < length(node.children) && _println(io)
        end
    end
    return
end

function latex(io::Context, node::Node, e::MarkdownAST.ThematicBreak)
    _println(io, "{\\rule{\\textwidth}{1pt}}")
    return
end

# This (equation*, split) math env seems to be the only way to correctly render all the
# equations in the Julia manual. However, if the equation is already wrapped in
# align/align*, then there is no need to further wrap it (in fact, it will break).
function latex(io::Context, node::Node, math::MarkdownAST.DisplayMath)
    if occursin(r"^\\begin\{align\*?\}", math.math)
        _print(io, math.math)
    else
        _print(io, "\\begin{equation*}\n\\begin{split}")
        _print(io, math.math)
        _println(io, "\\end{split}\\end{equation*}")
    end
    return
end

function latex(io::Context, node::Node, table::MarkdownAST.Table)
    rows = MarkdownAST.tablerows(node)
    _println(io, "\n\\begin{table}[h]\n\\centering")
    _print(io, "\\begin{tabulary}{\\linewidth}")
    _println(io, "{", uppercase(join(spec_to_align.(table.spec), ' ')), "}")
    _println(io, "\\toprule")
    for (i, row) in enumerate(rows)
        for (j, cell) in enumerate(row.children)
            j === 1 || _print(io, " & ")
            latex(io, cell.children)
        end
        _println(io, " \\\\")
        if i === 1
            _println(io, "\\toprule")
        end
    end
    _println(io, "\\bottomrule")
    _println(io, "\\end{tabulary}\n")
    _println(io, "\\end{table}\n")
    return
end
spec_to_align(spec::Symbol) = Symbol(first(String(spec)))

function latex(io::Context, node::Node, raw::Documenter.RawNode)
    raw.name === :latex && _println(io, "\n", raw.text, "\n")
    return
end

# Inline Elements.

function latex(io::Context, node::Node, e::MarkdownAST.Text)
    return latexesc(io, e.text)
end

function latex(io::Context, node::Node, e::MarkdownAST.Strong)
    wrapinline(io, "textbf") do
        latex(io, node.children)
    end
    return
end

function latex(io::Context, node::Node, e::MarkdownAST.Emph)
    wrapinline(io, "emph") do
        latex(io, node.children)
    end
    return
end

function latex(io::Context, node::Node, image::Documenter.LocalImage)
    # TODO: also print the .title field somehow
    wrapblock(io, "figure") do
        _println(io, "\\centering")
        wrapinline(io, "includegraphics[max width=\\linewidth]") do
            _print(io, image.path)
        end
        _println(io)
        wrapinline(io, "caption") do
            latex(io, node.children)
        end
        _println(io)
    end
    return
end

function latex(io::Context, node::Node, image::MarkdownAST.Image)
    # TODO: also print the .title field somehow
    wrapblock(io, "figure") do
        _println(io, "\\centering")
        @warn "images with absolute URLs not supported in LaTeX output in $(Documenter.locrepr(io.filename))" url = image.destination
        # We nevertheless output an \includegraphics with the URL. The LaTeX build will
        # then give an error, indicating to the user that something wrong.
        url = replace(image.destination, "\\" => "/") # use / on Windows too.
        wrapinline(io, "includegraphics[max width=\\linewidth]") do
            _print(io, url)
        end
        _println(io)
        wrapinline(io, "caption") do
            latex(io, node.children)
        end
        _println(io)
    end
    return
end

function latex(io::Context, node::Node, f::MarkdownAST.FootnoteLink)
    id = get!(io.footnotes, f.id, length(io.footnotes) + 1)
    _print(io, "\\footnotemark[", id, "]")
    return
end

function latex(io::Context, node::Node, link::Documenter.PageLink)
    # If we're in a header, we don't want to print any \hyperlinkref commands,
    # so we handle this here.
    if io.in_header
        latex(io, node.children)
        return
    end
    # This branch is the normal case, when we're not in a header.
    # TODO: this link handling does not seem correct
    if !isempty(link.fragment)
        id = _hash(link.fragment)
        wrapinline(io, "hyperlinkref") do
            _print(io, id)
        end
    else
        wrapinline(io, "href") do
            path = Documenter.pagekey(io.doc, link.page)
            latexesc(io, path)
        end
    end
    _print(io, "{")
    latex(io, node.children)
    _print(io, "}")
    return
end

function latex(io::Context, node::Node, link::Documenter.LocalLink)
    # If we're in a header, we don't want to print any \hyperlinkref commands,
    # so we handle this here.
    if io.in_header
        latex(io, node.children)
        return
    end
    # This branch is the normal case, when we're not in a header.
    # TODO: this link handling does not seem correct
    wrapinline(io, "href") do
        href = isempty(link.fragment) ? link.path : "$(link.path)#($(link.fragment))"
        latexesc(io, href)
    end
    _print(io, "{")
    latex(io, node.children)
    _print(io, "}")
    return
end

function latex(io::Context, node::Node, link::MarkdownAST.Link)
    # If we're in a header, we don't want to print any \hyperlinkref commands,
    # so we handle this here.
    if io.in_header
        latex(io, node.children)
        return
    end
    # This branch is the normal case, when we're not in a header.
    # TODO: handle the .title attribute
    wrapinline(io, "href") do
        latexesc(io, link.destination)
    end
    _print(io, "{")
    latex(io, node.children)
    _print(io, "}")
    return
end

function latex(io::Context, node::Node, math::MarkdownAST.InlineMath)
    # Handle MathJax and TeX inconsistency since the first wants `\LaTeX` wrapped
    # in math delims, whereas actual TeX fails when that is done.
    math.math == "\\LaTeX" ? _print(io, math.math) : _print(io, "\\(", math.math, "\\)")
    return
end

# Metadata Nodes get dropped from the final output for every format but are needed throughout
# rest of the build and so we just leave them in place and print a blank line in their place.
latex(io::Context, node::Node, ::Documenter.MetaNode) = _println(io, "\n")

# In the original AST, SetupNodes were just mapped to empty Markdown.MD() objects.
latex(io::Context, node::Node, ::Documenter.SetupNode) = nothing

function latex(io::Context, node::Node, value::MarkdownAST.JuliaValue)
    @warn(
        """
        Unexpected Julia interpolation in the Markdown. This probably means that you
        have an unbalanced or un-escaped \$ in the text.

        To write the dollar sign, escape it with `\\\$`

        We don't have the file or line number available, but we got given the value:

        `$(value.ref)` which is of type `$(typeof(value.ref))`
        """
    )
    return latexesc(io, string(value.ref))
end

# TODO: Implement SoftBreak, Backslash (but they don't appear in standard library Markdown conversions)
latex(io::Context, node::Node, ::MarkdownAST.LineBreak) = _println(io, "\\\\")

# Documenter.

const _latexescape_chars = Dict{Char, AbstractString}(
    '~' => "{\\textasciitilde}",
    '\u00A0' => "~",  # nonbreaking space
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
    return
end

latexesc(s) = sprint(latexesc, s)

function wrapblock(f, io, env)
    _println(io, "\\begin{", env, "}")
    f()
    _println(io, "\\end{", env, "}")
    return
end

function wrapinline(f, io, cmd)
    _print(io, "\\", cmd, "{")
    f()
    _print(io, "}")
    return
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
    return
end

files!(out, s::AbstractString, depth) = push!(out, ("", s, depth))

function files!(out, p::Pair{<:AbstractString, <:Any}, depth)
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
