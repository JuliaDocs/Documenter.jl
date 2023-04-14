"""
A module for rendering `Document` objects to Typst and PDF.

# Keywords

[`TypstWriter`](@ref) uses the following additional keyword arguments that can be passed to
[`makedocs`](@ref Documenter.makedocs): `authors`, `sitename`.

**`sitename`** is the site's title displayed in the title bar and at the top of the
navigation menu. It goes into the `\\title` Typst command.

**`authors`** can be used to specify the authors of. It goes into the `\\author` Typst command.

"""
module TypstWriter
import ...Documenter: Documenter
using Dates: Dates
using MarkdownAST: MarkdownAST, Node

"""
    Documenter.Typst(; kwargs...)

Output format specifier that results in Typst/PDF output.
Used together with [`makedocs`](@ref Documenter.makedocs), e.g.

```julia
makedocs(
    format = Documenter.Typst()
)
```

The `makedocs` argument `sitename` will be used for the `\\title` field in the tex document.
The `authors` argument should also be specified and will be used for the `\\authors` field
in the tex document. Finally, a version number can be specified with the `version` option to
`Typst`, which will be printed in the document and also appended to the output PDF file name.

# Keyword arguments

**`platform`** sets the platform where the tex-file is compiled, either `"native"` (default),
`"typst"`, `"docker"`, or "none" which doesn't compile the tex. The option `typst`
requires a `typst` executable to be available in `PATH` or to be passed as the `typst`
keyword.

**`version`** specifies the version number that gets printed on the title page of the manual.
It defaults to the value in the `TRAVIS_TAG` environment variable (although this behaviour is
considered to be deprecated), or to an empty string if `TRAVIS_TAG` is unset.

**`typst`** path to a `typst` executable used for compilation.

See [Other Output Formats](@ref) for more information.
"""
struct Typst <: Documenter.Writer
    platform::String
    version::String
    typst::Union{Cmd,String,Nothing}
    function Typst(;
        platform="native",
        version=get(ENV, "TRAVIS_TAG", ""),
        typst=nothing)
        platform ∈ ("native", "typst", "docker", "none") || throw(ArgumentError("unknown platform: $platform"))
        return new(platform, string(version), typst)
    end
end

import ...Documenter:
    Anchors,
    Builder,
    Expanders,
    Documenter

import Markdown

import ANSIColoredPrinters

mutable struct Context{I<:IO} <: IO
    io::I
    in_header::Bool
    footnotes::Dict{String,Int}
    depth::Int
    filename::String # currently active source file
    doc::Documenter.Document
end
Context(io, doc) = Context{typeof(io)}(io, false, Dict(), 1, "", doc)

_print(c::Context, args...) = Base.print(c.io, args...)
_println(c::Context, args...) = Base.println(c.io, args...)

# Labels in the TeX file are hashes of plain text labels.
# To keep the plain text label (for debugging), say _hash(x) = x
_hash(x) = string(hash(x))


const STYLE = joinpath(dirname(@__FILE__), "..", "..", "assets", "typst", "documenter.typ")

hastypst() = (
    try
        success(`typst --version`)
    catch
        false
    end
)

const DOCUMENT_STRUCTURE = (
    "part",
    "chapter",
    "section",
    "subsection",
    "subsubsection",
    "paragraph",
    "subparagraph",
)

function render(doc::Documenter.Document, settings::Typst=Typst())
    @info "TypstWriter: creating the Typst file."
    mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            fileprefix = typst_fileprefix(doc, settings)
            open("$(fileprefix).typ", "w") do io
                context = Context(io, doc)
                writeheader(context, doc, settings)
                for (title, filename, depth) in files(doc.user.pages)
                    context.filename = filename
                    empty!(context.footnotes)
                    if 1 <= depth <= length(DOCUMENT_STRUCTURE)
                        header_text = "#extended_heading(level: $(depth), within-block: false,  [$(title)])\n"
                        if isempty(filename)
                            _println(context, header_text)
                        else
                            path = normpath(filename)
                            page = doc.blueprint.pages[path]
                            if get(page.globals.meta, :IgnorePage, :none) !== :Typst
                                context.depth = depth + (isempty(title) ? 0 : 1)
                                context.depth > depth && _println(context, header_text)
                                typst(context, page.mdast.children; toplevel=true)
                            end
                        end
                    end
                end
                writefooter(context, doc)
            end
            cp(STYLE, "documenter.typ")

            # compile .typ
            status = compile_typ(doc, settings, fileprefix)

            # Debug: if DOCUMENTER_TYPST_DEBUG environment variable is set, copy the Typst
            # source files over to a directory under doc.user.root.
            if haskey(ENV, "DOCUMENTER_TYPST_DEBUG")
                dst = isempty(ENV["DOCUMENTER_TYPST_DEBUG"]) ? mktempdir(doc.user.root; cleanup=false) :
                      joinpath(doc.user.root, ENV["DOCUMENTER_TYPST_DEBUG"])
                sources = cp(pwd(), dst, force=true)
                @info "Typst sources copied for debugging to $(sources)"
            end

            # If the build was successful, copy the PDF or the Typst source to the .build directory
            if status && (settings.platform != "none")
                pdffile = "$(fileprefix).pdf"
                cp(pdffile, joinpath(doc.user.root, doc.user.build, pdffile); force=true)
            elseif status && (settings.platform == "none")
                cp(pwd(), joinpath(doc.user.root, doc.user.build); force=true)
            else
                error("Compiling the .typ file failed. See logs for more information.")
            end
        end
    end
end

function typst_fileprefix(doc::Documenter.Document, settings::Typst)
    fileprefix = doc.user.sitename
    if occursin(Base.VERSION_REGEX, settings.version)
        v = VersionNumber(settings.version)
        fileprefix *= "-$(v.major).$(v.minor).$(v.patch)"
    end
    return replace(fileprefix, " " => "")
end

const DOCKER_IMAGE_TAG = "0.1"

function compile_typ(doc::Documenter.Document, settings::Typst, fileprefix::String)
    if settings.platform == "native"
        # Use native typst
        Sys.which("typst") === nothing && (@error "TypstWriter: typst command not found."; return false)
        @info "TypstWriter: compile typ."
        try
            piperun(`typst.local compile $(fileprefix).typ`, clearlogs=true)
            return true
        catch err
            logs = cp(pwd(), mktempdir(; cleanup=false); force=true)
            @error "TypstWriter: failed to compile. " *
                   "Logs and partial output can be found in $(Documenter.locrepr(logs))." exception = err
            return false
        end
    elseif settings.platform == "typst"
        # TODO: Use Typst_jll
    elseif settings.platform == "docker"
        Sys.which("docker") === nothing && (@error "TypstWriter: docker command not found."; return false)
        @info "TypstWriter: using docker to compile typ."
        script = """
            mkdir /home/zeptodoctor/build
            cd /home/zeptodoctor/build
            cp -r /mnt/. .
            typst compile $(fileprefix).typ
            """
        try
            piperun(`docker run -itd -u zeptodoctor --name typst-container -v $(pwd()):/mnt/ --rm juliadocs/documenter-Typst:$(DOCKER_IMAGE_TAG)`, clearlogs=true)
            piperun(`docker exec -u zeptodoctor typst-container bash -c $(script)`)
            piperun(`docker cp typst-container:/home/zeptodoctor/build/$(fileprefix).pdf .`)
            return true
        catch err
            logs = cp(pwd(), mktempdir(; cleanup=false); force=true)
            @error "TypstWriter: failed to compile typ with docker. " *
                   "Logs and partial output can be found in $(Documenter.locrepr(logs))." exception = err
            return false
        finally
            try
                piperun(`docker stop Typst-container`)
            catch
            end
        end
    elseif settings.platform == "none"
        @info "Skipping compiling typ file."
        return true
    end
end

function piperun(cmd; clearlogs=false)
    verbose = "--verbose" in ARGS || get(ENV, "DOCUMENTER_VERBOSE", "false") == "true"
    run(verbose ? cmd : pipeline(
        cmd,
        stdout="TypstWriter.stdout",
        stderr="TypstWriter.stderr",
        append=!clearlogs,
    ))
end

function writeheader(io::IO, doc::Documenter.Document, settings::Typst)
    custom = joinpath(doc.user.root, doc.user.source, "assets", "custom.typ")
    isfile(custom) ? cp(custom, "custom.typ"; force=true) : touch("custom.typ")

    preamble = """
               // Import templates

               #import("documenter.typ"): *
               #import("custom.typ"): *

               // Useful variables

               #show: doc => documenter(
                   title: [$(doc.user.sitename)],
                   date: [$(Dates.format(Dates.now(), "u d, Y"))],
                   version: [$(settings.version)],
                   authors: [$(doc.user.authors)],
                   julia-version: [$(VERSION)],
                   doc
               )
               """

    # output preamble
    _println(io, preamble)
end

function writefooter(io::IO, doc::Documenter.Document)
end

# A few of the nodes are printed differently depending on whether they appear
# as the top-level blocks of a page, or somewhere deeper in the AST.
istoplevel(n::Node) = !isnothing(n.parent) && isa(n.parent.element, MarkdownAST.Document)

typst(io::Context, node::Node; toplevel=false, inblock=false) = typst(io, node, node.element; toplevel=toplevel, inblock=inblock)
typst(io::Context, node::Node, e; toplevel=false, inblock=false) = error("$(typeof(e)) not implemented: $e")

function typst(io::Context, children; toplevel=false, inblock=false)
    @assert eltype(children) <: MarkdownAST.Node
    for node in children
        otherelement = !isa(node.element, NoExtraTopLevelNewlines)
        toplevel && otherelement && _println(io)
        typst(io, node; toplevel=toplevel, inblock=inblock)
        toplevel && otherelement && _println(io)
    end
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

function typst(io::Context, node::Node, ah::Documenter.AnchoredHeader; toplevel=false, inblock=false)
    anchor = ah.anchor
    # typst(io::IO, anchor::Anchors.Anchor, page, doc)
    id = _hash(basename(io.filename) * "#" * Anchors.label(anchor))
    typst(io, node.children; toplevel=istoplevel(node), inblock=inblock)
    _println(io, " <", id, ">\n")
end

## Documentation Nodes.

function typst(io::Context, node::Node, ::Documenter.DocsNodesBlock; toplevel=false, inblock=false)
    typst(io, node.children; toplevel=istoplevel(node), inblock=inblock)
end

function typst(io::Context, node::Node, docs::Documenter.DocsNode; toplevel=false, inblock=false)
    node, ast = docs, node
    # typst(io::IO, node::Documenter.DocsNode, page, doc)
    id = _hash(basename(io.filename) * "#" * Anchors.label(node.anchor))
    # Docstring header based on the name of the binding and it's category.
    _print(io, "#raw(\"")
    typstescstr(io, string(node.object.binding))
    _print(io, "\", block: false) <", id, ">")
    _println(io, " -- ", Documenter.doccat(node.object), ".\n")
    # Body. May contain several concatenated docstrings.
    _println(io, "#grid(columns: (2em, 1fr), [], [")
    typstdoc(io, ast; inblock=inblock)
    _println(io, "])")
end

function typstdoc(io::IO, node::Node; inblock=inblock)
    @assert node.element isa Documenter.DocsNode
    # The `:results` field contains a vector of `Docs.DocStr` objects associated with
    # each markdown object. The `DocStr` contains data such as file and line info that
    # we need for generating correct source links.
    for (docstringast, result) in zip(node.element.mdasts, node.element.results)
        _println(io)
        typst(io, docstringast.children; inblock=inblock)
        _println(io)
        # When a source link is available then print the link.
        url = Documenter.source_url(io.doc.user.remote, result)
        if url !== nothing
            link = "#link(\"$url\")[`source`]"
            _println(io, "\n", link, "\n")
        end
    end
end

## Index, Contents, and Eval Nodes.

function typst(io::Context, node::Node, index::Documenter.IndexNode; toplevel=false, inblock=false)
    # Having an empty itemize block in Typst throws an error, so we bail early
    # in that situation:
    isempty(index.elements) && (_println(io); return)

    _println(io, "\n")
    for (object, _, page, mod, cat) in index.elements
        id = _hash(basename(io.filename) * "#" * string(Documenter.slugify(object)))
        text = string(object.binding)
        _print(io, "#link(<")
        _print(io, id, ">)[#raw(\"")
        typstescstr(io, text)
        _println(io, "\", block: false)]")
    end
    _println(io, "\n")
end

function typst(io::Context, node::Node, contents::Documenter.ContentsNode; toplevel=false, inblock=false)
    # Having an empty itemize block in LaTeX throws an error, so we bail early
    # in that situation:
    isempty(contents.elements) && (_println(io); return)

    depth = 1
    for (count, path, anchor) in contents.elements
        @assert length(anchor.node.children) == 1
        header = first(anchor.node.children)
        level = header.element.level
        # Filter out header levels smaller than the requested mindepth
        level = level - contents.mindepth + 1
        level < 1 && continue

        if level > depth
            for k in 1:(level-depth)
                # if we jump by more than one level deeper we need to put empty bullets to take that level
                (k >= 2) && _println(io, repeat(" ", 2 * (depth + k - 1)), "-")
                depth += 1
            end
        end

        # Print the corresponding item
        id = _hash(basename(anchor.file) * "#" * Anchors.label(anchor))
        _print(io, repeat(" ", 2 * (level - 1)), "- #link(<", id, ">)[")
        typst(io, header.children; inblock=inblock)
        _println(io, "]")
    end
end

function typst(io::Context, node::Node, evalnode::Documenter.EvalNode; toplevel=false, inblock=false)
    if evalnode.result !== nothing
        typst(io, evalnode.result.children; toplevel=true, inblock=inblock)
    end
end

# Select the "best" representation for Typst output.
using Base64: base64decode
typst(io::Context, node::Node, ::Documenter.MultiOutput; toplevel=false, inblock=false) = typst(io, node.children; inblock=inblock)
function typst(io::Context, node::Node, moe::Documenter.MultiOutputElement; toplevel=false, inblock=false)
    Base.invokelatest(typst, io, node, moe.element; inblock=inblock)
end
function typst(io::Context, ::Node, d::Dict{MIME,Any}; toplevel=false, inblock=false)
    filename = String(rand('a':'z', 7))
    if haskey(d, MIME"image/png"())
        write("$(filename).png", base64decode(d[MIME"image/png"()]))
        _println(io, "#figure(image($(filename).png, width: 100%))")
    elseif haskey(d, MIME"image/jpeg"())
        write("$(filename).jpeg", base64decode(d[MIME"image/jpeg"()]))
        _println(io, "#figure(image($(filename).jpeg, width: 100%))")
    elseif haskey(d, MIME"text/markdown"())
        md = Markdown.parse(d[MIME"text/markdown"()])
        ast = MarkdownAST.convert(MarkdownAST.Node, md)
        typst(io, ast.children; inblock=inblock)
    elseif haskey(d, MIME"text/plain"())
        text = d[MIME"text/plain"()]
        out = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(IOBuffer(text)))
        # We set a "fake" language as text/plain so that the writer knows how to
        # deal with it.
        codeblock = MarkdownAST.CodeBlock("text/plain", out)
        typst(io, MarkdownAST.Node(codeblock); inblock=inblock)
    else
        error("this should never happen.")
    end
    return nothing
end


## Basic Nodes. AKA: any other content that hasn't been handled yet.

function typst(io::Context, node::Node, heading::MarkdownAST.Heading; toplevel=false, inblock=false)
    N = heading.level
    _print(io, "#extended_heading(level: $(min(io.depth + N - 1, length(DOCUMENT_STRUCTURE))), within-block: $(string(inblock)), [")
    io.in_header = true
    typst(io, node.children; inblock=inblock)
    io.in_header = false
    _println(io, "])")
end

# Whitelisted lexers.
const LEXER = Set([
    "julia",
    "jlcon",
    "text",
])

function typst(io::Context, node::Node, code::MarkdownAST.CodeBlock; toplevel=false, inblock=false)
    language = Documenter.codelang(code.info)
    if language == "julia-repl" || language == "@repl"
        language = "julia"
    elseif language == "text/plain" || isempty(language)
        language = "text"
    end
    text = IOBuffer(code.code)
    code_code = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(text))
    _println(io)
    _print(io, "#raw(\"")
    typstescstr(io, code_code)
    _println(io, "\", block: true, lang: \"$(language)\")")
    return
end

typst(io::Context, node::Node, mcb::Documenter.MultiCodeBlock; toplevel=false, inblock=false) = typst(io, node, join_multiblock(node); inblock=inblock)
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

function typst(io::Context, node::Node, code::MarkdownAST.Code; toplevel=false, inblock=false)
    _print(io, " #raw(\"")
    typstescstr(io, code.code)
    _print(io, "\", block: false) ")
end

function typst(io::Context, node::Node, ::MarkdownAST.Paragraph; toplevel=false, inblock=false)
    typst(io, node.children; inblock=inblock)
    _println(io, "\n")
end

#TODO: improve quote
function typst(io::Context, node::Node, ::MarkdownAST.BlockQuote; toplevel=false, inblock=false)
    _print(io, "#[")
    typst(io, node.children; inblock=true)
    _print(io, "]")
end

function typst(io::Context, node::Node, md::MarkdownAST.Admonition; toplevel=false, inblock=false)
    type = "default"
    if md.category in ("danger", "warning", "note", "info", "tip", "compat")
        type = md.category
    end

    _println(io, "#admonition(type: \"$type\", title: \"$(md.title)\")[")
    typst(io, node.children; inblock=true)
    _println(io, "]")
    return
end

# TODO: footnote
function typst(io::Context, node::Node, f::MarkdownAST.FootnoteDefinition; toplevel=false, inblock=false)
    id = get(io.footnotes, f.id, 1)
    # _print(io, "\\footnotetext[", id, "]{")
    # typst(io, node.children; inblock=inblock)
    # _println(io, "}")
end

function typst(io::Context, node::Node, list::MarkdownAST.List; toplevel=false, inblock=false)
    symbol = list.type === :ordered ? '+' : '-'
    _println(io)
    for item in node.children
        _print(io, symbol, " ")
        typst(io, item.children; inblock=inblock)
        _println(io)
    end
end

function typst(io::Context, node::Node, e::MarkdownAST.ThematicBreak; toplevel=false, inblock=false)
    _println(io, "#line(length: 1pt)")
end

#TODO: Math
function typst(io::Context, node::Node, math::MarkdownAST.DisplayMath; toplevel=false, inblock=false)
    # if occursin(r"^\\begin\{align\*?\}", math.math)
    #     _print(io, math.math)
    # else
    #     _print(io, "\\begin{equation*}\n\\begin{split}")
    #     _print(io, math.math)
    #     _println(io, "\\end{split}\\end{equation*}")
    # end
    _print(io, " `", math.math, "` ")
end

function typst(io::Context, node::Node, table::MarkdownAST.Table; toplevel=false, inblock=false)
    rows = MarkdownAST.tablerows(node)
    cols = length(table.spec)
    _println(io, "#align(center)[")
    _println(io, "#table(")
    _println(io, "columns: (", repeat("auto,", cols), "),")
    _println(io, "align: (x, y) => ($(join(string.(table.spec), ",")),).at(x),")
    for (i, row) in enumerate(rows)
        for (j, cell) in enumerate(row.children)
            _print(io, " [")
            typst(io, cell.children; toplevel=false, inblock=true)
            _print(io, "],")
        end
        _println(io)
    end
    _println(io, ")]")
end

function typst(io::Context, node::Node, raw::Documenter.RawNode; toplevel=false, inblock=false)
    raw.name === :typ || raw.name === :typc ? _println(io, "\n", raw.text, "\n") : nothing
end

# Inline Elements.

function typst(io::Context, node::Node, e::MarkdownAST.Text; toplevel=false, inblock=false)
    typstesc(io, e.text)
end

function typst(io::Context, node::Node, e::MarkdownAST.Strong; toplevel=false, inblock=false)
    _print(io, "#strong([")
    typst(io, node.children; inblock=inblock)
    _print(io, "])")
end

function typst(io::Context, node::Node, e::MarkdownAST.Emph; toplevel=false, inblock=false)
    _print(io, "#emph([")
    typst(io, node.children; inblock=inblock)
    _print(io, "])")
end

#TODO: Images
function typst(io::Context, node::Node, image::MarkdownAST.Image; toplevel=false, inblock=false)
    _println(io, "#align(center)[")
    _println(io, "#figure(")
    _println(io, "image(")
    
    # TODO: also print the .title field somehow
    url = if Documenter.isabsurl(image.destination)
        @warn "images with absolute URLs not supported in Typst output in $(Documenter.locrepr(io.filename))" url = image.destination
        image.destination
    elseif startswith(image.destination, '/')
        # URLs starting with a / are assumed to be relative to the document's root
        normpath(lstrip(image.destination, '/'))
    else
        normpath(joinpath(dirname(io.filename), image.destination))
    end

    url = replace(url, "\\" => "/")

    _print(io, "\"", url, "\", ")
    _println(io, "width: 100%, fit: \"contain\"),")
    _println(io, "caption: [")
    typst(io, node.children; inblock=true, toplevel=false)
    _println(io, "])]")
end

# TODO: footnote link
function typst(io::Context, node::Node, f::MarkdownAST.FootnoteLink; toplevel=false, inblock=false)
    # id = get!(io.footnotes, f.id, length(io.footnotes) + 1)
    # _print(io, "\\footnotemark[", id, "]")
end

function typst(io::Context, node::Node, link::MarkdownAST.Link; toplevel=false, inblock=false)
    # TODO: handle the .title attribute
    if io.in_header
        typst(io, node.children; inblock=inblock)
    else
        if occursin(".md#", link.destination)
            file, target = split(link.destination, ".md#"; limit=2)
            id = _hash(basename(file * ".md") * "#" * target)
            _print(io, "#link(<", id, ">)")
        elseif startswith("#", link.destination)
            id = _hash(basename(io.filename) * "#" * target)
            _print(io, "#link(<", id, ">)")
        else    
            _print(io, "#link(\"", link.destination, "\")")
        end
        _print(io, "[")
        typst(io, node.children; inblock=inblock)
        _print(io, "] ") # Add an extra space to avoid "]." issues
    end
end

# TODO: Math
function typst(io::Context, node::Node, math::MarkdownAST.InlineMath; toplevel=false, inblock=false)
    _print(io, " `", math.math, "` ")
end

# Metadata Nodes get dropped from the final output for every format but are needed throughout
# rest of the build and so we just leave them in place and print a blank line in their place.
typst(io::Context, node::Node, ::Documenter.MetaNode; toplevel=false, inblock=false) = _println(io, "\n")

# In the original AST, SetupNodes were just mapped to empty Markdown.MD() objects.
typst(io::Context, node::Node, ::Documenter.SetupNode; toplevel=false, inblock=false) = nothing

function typst(io::Context, node::Node, value::MarkdownAST.JuliaValue; toplevel=false, inblock=false)
    @warn """
    Unexpected Julia interpolation of type $(typeof(value.ref)) in the Markdown.
    """ value = value.ref
    typstesc(io, string(value.ref))
end

# TODO: Implement SoftBreak, Backslash (but they don't appear in standard library Markdown conversions)
typst(io::Context, node::Node, ::MarkdownAST.LineBreak; toplevel=false, inblock=false) = _println(io, "#linebreak()")

const _typstescape_chars = Dict{Char,AbstractString}()
for ch in "@#*_\$/"
    _typstescape_chars[ch] = "\\$ch"
end

const _typstescape_chars_in_string = Dict{Char,AbstractString}()
for ch in "\"\\"
    _typstescape_chars_in_string[ch] = "\\$ch"
end

# Escape characters in contents
typstesc(io, ch::AbstractChar) = _print(io, get(_typstescape_chars, ch, ch))

function typstesc(io, s::AbstractString)
    for ch in s
        typstesc(io, ch)
    end
end

typstesc(s) = sprint(typstesc, s)

# Escape characters in string literals
typstescstr(io, ch::AbstractChar) = _print(io, get(_typstescape_chars_in_string, ch, ch))

function typstescstr(io, s::AbstractString)
    for ch in s
        typstescstr(io, ch)
    end
end

typstescstr(s) = sprint(typstescstr, s)

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

files(v::Vector) = files!(Tuple{String,String,Int}[], v, 0)

end
