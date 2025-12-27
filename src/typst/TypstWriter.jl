"""
A module for rendering `Document` objects to Typst and PDF.

# Keywords

[`TypstWriter`](@ref) uses the following additional keyword arguments that can be passed to
[`makedocs`](@ref Documenter.makedocs): `authors`, `sitename`.

**`sitename`** is the site's title displayed in the title bar and at the top of the
navigation menu. It goes into the Typst document title.

**`authors`** can be used to specify the authors. It goes into the Typst document metadata.

"""
module TypstWriter
import ...Documenter: Documenter
using Dates: Dates
using MarkdownAST: MarkdownAST, Node
using Typst_jll: typst as typst_exe

# ============================================================================
# Path handling and anchor identification
# ============================================================================

"""
    escape_for_typst_string(s::String) -> String

Escape special characters for use inside Typst string literals.
Only backslash and double quote need to be escaped.

# Examples
```julia
escape_for_typst_string("test")                    # => "test"
escape_for_typst_string("test\"quote\"")           # => "test\\\"quote\\\""
escape_for_typst_string("C:\\\\path\\\\file.txt")  # => "C:\\\\\\\\path\\\\\\\\file.txt"
```
"""
function escape_for_typst_string(s::String)
    s = replace(s, "\\" => "\\\\")  # Backslash first
    s = replace(s, "\"" => "\\\"")  # Then double quote
    return s
end

"""
    remove_build_prefix(doc::Document, path::AbstractString) -> String

Remove the build directory prefix from a path.

# Examples
```julia
remove_build_prefix(doc, "build-typst/man/guide.md")  # => "man/guide.md"
remove_build_prefix(doc, "man/guide.md")              # => "man/guide.md"
```
"""
function remove_build_prefix(doc::Documenter.Document, path::AbstractString)
    build_prefix = doc.user.build * "/"
    if startswith(path, build_prefix)
        return path[length(build_prefix)+1:end]
    end
    return path
end

"""
    make_label_id(doc::Document, file::AbstractString, label::AbstractString) -> String

Generate a Typst label ID using the label() function syntax.
Returns the raw string (already escaped) ready to use in #label("...").

# Format
- Remove build prefix from file
- Combine as "file#label" (or just "label" if file is empty)
- Escape quotes and backslashes
- Returns string ready for: #label("...") and #link(label("..."))

# Examples
```julia
make_label_id(doc, "build-typst/man/guide.md", "Installation")
# => "man/guide.md#Installation"

make_label_id(doc, "build-typst/api.md", "Documenter.makedocs")
# => "api.md#Documenter.makedocs"

make_label_id(doc, "build-typst/cpp.md", "C++")
# => "cpp.md#C++"
```
"""
function make_label_id(doc::Documenter.Document, file::AbstractString, label::AbstractString)
    # Normalize path separators
    normalized_file = replace(file, "\\" => "/")
    
    # Remove build prefix
    path = remove_build_prefix(doc, normalized_file)
    
    # Combine file#label (or just label if path is empty)
    full_id = isempty(path) ? label : "$path#$label"
    
    # Escape for Typst string literal
    return escape_for_typst_string(full_id)
end

# ============================================================================

"""
    Documenter.Typst(; kwargs...)

Output format specifier that results in Typst/PDF output.
Used together with [`makedocs`](@ref Documenter.makedocs), e.g.

```julia
makedocs(
    format = Documenter.Typst()
)
```

The `makedocs` argument `sitename` will be used for the document title.
The `authors` argument should also be specified and will be used for the document metadata.
A version number can be specified with the `version` option to `Typst`, which will be 
printed in the document and also appended to the output PDF file name.

# Keyword arguments

- **`platform`** sets the platform where the Typst file is compiled. Available options:
    - `"typst"` (default): Uses Typst_jll, a Julia binary wrapper that automatically 
      provides the Typst compiler across all platforms.
    - `"native"`: Uses the system-installed `typst` executable found in `PATH`, or 
      a custom path specified via the `typst` keyword argument.
    - `"docker"`: Uses Docker to compile the Typst file. Requires `docker` to be 
      available in `PATH`.
    - `"none"`: Skips compilation and only generates the `.typ` source file in the 
      build directory.

- **`version`** specifies the version number printed on the title page of the manual.
  Defaults to the value in the `TRAVIS_TAG` environment variable (although this behaviour 
  is considered deprecated), or to an empty string if `TRAVIS_TAG` is unset.

- **`typst`** allows specifying a custom path to a `typst` executable. Only used when 
  `platform="native"`. Can be either a `String` path or a `Cmd` object.

See [Other Output Formats](@ref) for more information.
"""
struct Typst <: Documenter.Writer
    platform::String
    version::String
    typst::Union{Cmd,String,Nothing}
    function Typst(;
        platform="typst",
        version=get(ENV, "TRAVIS_TAG", ""),
        typst=nothing)
        platform ∈ ("native", "typst", "docker", "none") || throw(ArgumentError("unknown platform: $platform"))
        return new(platform, string(version), typst)
    end
end

import ..Documenter:
    Documenter,
    Builder,
    Expanders,
    writer_supports_ansicolor

import Markdown

import ANSIColoredPrinters

# Implement the writer interface for ANSI color support
writer_supports_ansicolor(::Typst) = false

# ============================================================================
# Rendering state and context
# ============================================================================

"""
    RenderState

Immutable global state built once at the start of rendering.
Contains lookup tables and cached values that don't change during the rendering process.
"""
struct RenderState
    lowercase_anchors::Dict{String,String}  # lowercase key -> original label
    build_path::String  # Pre-normalized build path (for performance)
end

"""
    Context{I<:IO}

Mutable rendering context that changes as we traverse the document.
Implements the IO interface for convenient printing.
"""
mutable struct Context{I<:IO} <: IO
    io::I
    doc::Documenter.Document
    state::RenderState
    
    # Current file state
    filename::String  # Currently active source file
    depth::Int        # Current heading depth
    in_header::Bool   # Are we inside a header?
    in_block::Bool    # Are we inside a block container (admonition, blockquote, etc)?
    
    # Per-page state (reset for each page)
    footnote_defs::Dict{String,Node}  # Footnote id -> definition node
end

function Context(io::I, doc::Documenter.Document, state::RenderState) where I<:IO
    Context{I}(io, doc, state, "", 1, false, false, Dict())
end

_print(c::Context, args...) = Base.print(c.io, args...)
_println(c::Context, args...) = Base.println(c.io, args...)

# ============================================================================
# Path utilities using RenderState
# ============================================================================

"""
    with_build_prefix(state::RenderState, relative_path::AbstractString) -> String

Add build prefix to relative paths using cached build_path from RenderState.
Optimized to avoid repeated normalization of the build path.
"""
function with_build_prefix(state::RenderState, relative_path::AbstractString)
    rel_path = replace(relative_path, "\\" => "/")
    return state.build_path * "/" * rel_path
end

# ============================================================================

"""
    collect_footnotes!(defs::Dict{String,Node}, node::Node) -> Dict{String,Node}

Recursively collect all footnote definitions from an AST.

Handles both regular AST nodes and special cases like `DocsNode`, which contains
separate AST trees in its `mdasts` field that need to be scanned independently.
"""
function collect_footnotes!(defs::Dict{String,Node}, node::Node)
    if node.element isa MarkdownAST.FootnoteDefinition
        defs[node.element.id] = node
    end
    
    # Special handling for DocsNode which contains separate ASTs in .mdasts
    # These ASTs are not in node.children, so we must scan them explicitly
    if node.element isa Documenter.DocsNode
        for docstringast in node.element.mdasts
            collect_footnotes!(defs, docstringast)
        end
    end
    
    for child in node.children
        collect_footnotes!(defs, child)
    end
    return defs
end


const STYLE = joinpath(dirname(@__FILE__), "..", "..", "assets", "typst", "documenter.typ")

const DOCUMENT_STRUCTURE = (
    "part",
    "chapter",
    "section",
    "subsection",
    "subsubsection",
    "paragraph",
    "subparagraph",
)

"""
    build_anchor_lookup(doc::Document) -> Dict{String,String}

Build a case-insensitive anchor lookup map.

Returns a dictionary mapping lowercase keys (file#label) to original anchor labels.
This allows case-insensitive matching of anchor references while preserving the
original case for label generation.

# Implementation
Iterates through all anchors in doc.internal.headers.map and creates entries
using normalized paths and anchor labels (which include -nth suffixes for uniqueness).

Optimized to minimize function calls and string operations.
"""
function build_anchor_lookup(doc::Documenter.Document)
    lookup = Dict{String, String}()
    
    for (_, filedict) in doc.internal.headers.map
        for (file, anchors) in filedict
            # Normalize file path once per file
            normalized_file = replace(file, "\\" => "/")
            for anchor in anchors
                # Get label once per anchor
                label = Documenter.anchor_label(anchor)
                # Build key directly without intermediate allocations
                key = normalized_file * "#" * lowercase(label)
                lookup[key] = label
            end
        end
    end
    
    return lookup
end

function render(doc::Documenter.Document, settings::Typst=Typst())
    @info "TypstWriter: creating the Typst file."
    mktempdir() do path
        cp(joinpath(doc.user.root, doc.user.build), joinpath(path, "build"))
        cd(joinpath(path, "build")) do
            fileprefix = typst_fileprefix(doc, settings)
            open("$(fileprefix).typ", "w") do io
                # Build global rendering state with cached build path
                build_path = replace(doc.user.build, "\\" => "/")
                state = RenderState(build_anchor_lookup(doc), build_path)
                context = Context(io, doc, state)
                
                writeheader(context, doc, settings)
                for (title, filename, depth) in files(doc.user.pages)
                    context.filename = filename
                    empty!(context.footnote_defs)
                    if 1 <= depth <= length(DOCUMENT_STRUCTURE)
                        header_text = "#extended_heading(level: $(depth), within-block: false,  [$(title)])\n"
                        if isempty(filename)
                            _println(context, header_text)
                        else
                            path = normpath(filename)
                            page = doc.blueprint.pages[path]
                            if get(page.globals.meta, :IgnorePage, :none) !== :Typst
                                # Pre-scan to collect footnote definitions
                                collect_footnotes!(context.footnote_defs, page.mdast)
                                
                                context.depth = depth + (isempty(title) ? 0 : 1)
                                context.depth > depth && _println(context, header_text)
                                typst_toplevel(context, page.mdast.children)
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

# ============================================================================
# Typst compilation backends
# ============================================================================

"""
Abstract base type for Typst compilation backends.
Each concrete type implements a specific way to compile .typ files to PDF.
"""
abstract type TypstCompiler end

"""Native system typst executable."""
struct NativeCompiler <: TypstCompiler
    typst_cmd::Cmd
end

"""Typst_jll Julia binary wrapper."""
struct TypstJllCompiler <: TypstCompiler end

"""Docker-based compilation."""
struct DockerCompiler <: TypstCompiler
    image_tag::String
end

"""No-op compiler (only generates .typ source)."""
struct NoOpCompiler <: TypstCompiler end

"""
    get_compiler(settings::Typst) -> TypstCompiler

Factory function to create the appropriate compiler based on settings.
"""
function get_compiler(settings::Typst)
    if settings.platform == "native"
        cmd = settings.typst === nothing ? `typst` : settings.typst
        return NativeCompiler(cmd)
    elseif settings.platform == "typst"
        return TypstJllCompiler()
    elseif settings.platform == "docker"
        return DockerCompiler(DOCKER_IMAGE_TAG)
    elseif settings.platform == "none"
        return NoOpCompiler()
    else
        error("Unknown platform: $(settings.platform)")
    end
end

"""
    compile(compiler::TypstCompiler, fileprefix::String) -> Bool

Compile the .typ file using the given compiler backend.
Returns true on success, throws on failure.
"""
function compile(c::NativeCompiler, fileprefix::String)
    Sys.which("typst") === nothing && error("typst command not found")
    @info "TypstWriter: using native typst."
    piperun(`$(c.typst_cmd) compile $(fileprefix).typ`, clearlogs=true)
    return true
end

function compile(c::TypstJllCompiler, fileprefix::String)
    @info "TypstWriter: using typst (via Typst_jll)."
    piperun(`$(typst_exe()) compile $(fileprefix).typ`, clearlogs=true)
    return true
end

function compile(c::DockerCompiler, fileprefix::String)
    Sys.which("docker") === nothing && error("docker command not found")
    @info "TypstWriter: using docker to compile typ."
    
    script = """
        mkdir /home/zeptodoctor/build
        cd /home/zeptodoctor/build
        cp -r /mnt/. .
        typst compile $(fileprefix).typ
        """
    
    try
        piperun(`docker run -itd -u zeptodoctor --name typst-container -v $(pwd()):/mnt/ --rm juliadocs/documenter-Typst:$(c.image_tag)`, clearlogs=true)
        piperun(`docker exec -u zeptodoctor typst-container bash -c $(script)`)
        piperun(`docker cp typst-container:/home/zeptodoctor/build/$(fileprefix).pdf .`)
        return true
    finally
        try
            piperun(`docker stop typst-container`)
        catch
        end
    end
end

function compile(::NoOpCompiler, ::String)
    @info "TypstWriter: skipping compilation (platform=none)."
    return true
end

"""
    compile_typ(doc::Document, settings::Typst, fileprefix::String) -> Bool

Main entry point for Typst compilation. 
Selects the appropriate compiler and handles errors uniformly.
"""
function compile_typ(::Documenter.Document, settings::Typst, fileprefix::String)
    compiler = get_compiler(settings)
    
    try
        return compile(compiler, fileprefix)
    catch err
        logs = cp(pwd(), mktempdir(; cleanup=false); force=true)
        @error "TypstWriter: compilation failed. " *
               "Logs and partial output can be found in $(Documenter.locrepr(logs))." exception = err
        return false
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

# Main typst rendering dispatch
typst(io::Context, node::Node) = typst(io, node, node.element)
typst(io::Context, node::Node, e) = error("$(typeof(e)) not implemented: $e")

# Render children
function typst(io::Context, children)
    @assert eltype(children) <: MarkdownAST.Node
    for node in children
        typst(io, node)
    end
end

# Render children at top level (with extra spacing for certain elements)
function typst_toplevel(io::Context, children)
    @assert eltype(children) <: MarkdownAST.Node
    for node in children
        otherelement = !isa(node.element, NoExtraTopLevelNewlines)
        otherelement && _println(io)
        typst(io, node)
        otherelement && _println(io)
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

function typst(io::Context, node::Node, ah::Documenter.AnchoredHeader)
    anchor = ah.anchor
    label_id = make_label_id(io.doc, anchor.file, Documenter.anchor_label(anchor))
    if istoplevel(node)
        typst_toplevel(io, node.children)
    else
        typst(io, node.children)
    end
    _println(io, " #label(\"", label_id, "\")\n")
end

## Documentation Nodes.

function typst(io::Context, node::Node, ::Documenter.DocsNodesBlock)
    if istoplevel(node)
        typst_toplevel(io, node.children)
    else
        typst(io, node.children)
    end
end

function typst(io::Context, node::Node, docs::Documenter.DocsNode)
    node, ast = docs, node
    label_id = make_label_id(io.doc, node.anchor.file, Documenter.anchor_label(node.anchor))
    # Docstring header based on the name of the binding and it's category.
    _print(io, "#raw(\"")
    typstescstr(io, string(node.object.binding))
    _print(io, "\", block: false) #label(\"", label_id, "\")")
    _println(io, " -- ", Documenter.doccat(node.object), ".\n")
    # Body. May contain several concatenated docstrings.
    _println(io, "#grid(columns: (2em, 1fr), [], [")
    typstdoc(io, ast)
    _println(io, "])")
end

"""
    typstdoc(io::Context, node::Node)

Render the body of a docstring node, including all concatenated docstrings and source links.

The `node.element.results` field contains a vector of `Docs.DocStr` objects associated with
each markdown object, providing metadata such as file and line info needed for generating
correct source links.
"""
function typstdoc(io::Context, node::Node)
    @assert node.element isa Documenter.DocsNode
    for (docstringast, result) in zip(node.element.mdasts, node.element.results)
        _println(io)
        typst(io, docstringast.children)
        _println(io)
        # When a source link is available then print the link.
        url = Documenter.source_url(io.doc, result)
        if url !== nothing
            link = "#link(\"$url\")[`source`]"
            _println(io, "\n", link, "\n")
        end
    end
end

## Index, Contents, and Eval Nodes.

function typst(io::Context, ::Node, index::Documenter.IndexNode)
    # Having an empty itemize block in Typst throws an error, so we bail early
    # in that situation:
    isempty(index.elements) && (_println(io); return)

    _println(io, "\n")
    for (object, doc, _, _, _) in index.elements
        # doc is a DocsNode with an anchor field!
        label_id = make_label_id(io.doc, doc.anchor.file, Documenter.anchor_label(doc.anchor))
        text = string(object.binding)
        _print(io, "- #link(label(\"")
        _print(io, label_id, "\"))[#raw(\"")
        typstescstr(io, text)
        _println(io, "\", block: false)]")
    end
    _println(io, "\n")
end

function typst(io::Context, ::Node, contents::Documenter.ContentsNode)
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
        label_id = make_label_id(io.doc, anchor.file, Documenter.anchor_label(anchor))
        _print(io, repeat(" ", 2 * (level - 1)), "- #link(label(\"", label_id, "\"))[")
        typst(io, header.children)
        _println(io, "]")
    end
end

function typst(io::Context, node::Node, evalnode::Documenter.EvalNode)
    if evalnode.result !== nothing
        typst_toplevel(io, evalnode.result.children)
    end
end

# Select the "best" representation for Typst output.
using Base64: base64decode
typst(io::Context, node::Node, ::Documenter.MultiOutput) = typst(io, node.children)
function typst(io::Context, node::Node, moe::Documenter.MultiOutputElement)
    Base.invokelatest(typst, io, node, moe.element)
end
function typst(io::Context, ::Node, d::Dict{MIME,Any})
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
        typst(io, ast.children)
    elseif haskey(d, MIME"text/plain"())
        text = d[MIME"text/plain"()]
        out = repr(MIME"text/plain"(), ANSIColoredPrinters.PlainTextPrinter(IOBuffer(text)))
        # We set a "fake" language as text/plain so that the writer knows how to
        # deal with it.
        codeblock = MarkdownAST.CodeBlock("text/plain", out)
        typst(io, MarkdownAST.Node(codeblock))
    else
        error("this should never happen.")
    end
    return nothing
end


## Basic Nodes. AKA: any other content that hasn't been handled yet.

function typst(io::Context, node::Node, heading::MarkdownAST.Heading)
    N = heading.level
    # Use io.in_block to determine if we're inside a container
    _print(io, "#extended_heading(level: $(min(io.depth + N - 1, length(DOCUMENT_STRUCTURE))), within-block: $(string(io.in_block)), [")
    io.in_header = true
    typst(io, node.children)
    io.in_header = false
    _println(io, "])")
end

function typst(io::Context, ::Node, code::MarkdownAST.CodeBlock)
    # Check for native Typst math BEFORE calling codelang
    # because codelang only extracts the first word
    if code.info == "math typst"
        # Render a native Typst math block
        _println(io)
        _println(io, "\$")
        _println(io, code.code)
        _println(io, "\$")
        _println(io)
        return
    end
    
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

typst(io::Context, node::Node, ::Documenter.MultiCodeBlock) = typst(io, node, join_multiblock(node))
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

function typst(io::Context, ::Node, code::MarkdownAST.Code)
    _print(io, " #raw(\"")
    typstescstr(io, code.code)
    _print(io, "\", block: false) ")
end

function typst(io::Context, node::Node, ::MarkdownAST.Paragraph)
    typst(io, node.children)
    _println(io, "\n")
end

function typst(io::Context, node::Node, ::MarkdownAST.BlockQuote)
    _println(io, "#quote(block: true)[")
    old_in_block = io.in_block
    io.in_block = true
    typst(io, node.children)
    io.in_block = old_in_block
    _println(io, "]")
end

function typst(io::Context, node::Node, md::MarkdownAST.Admonition)
    type = "default"
    if md.category in ("danger", "warning", "note", "info", "tip", "compat")
        type = md.category
    end

    _println(io, "#admonition(type: \"$type\", title: \"$(md.title)\")[")
    old_in_block = io.in_block
    io.in_block = true
    typst(io, node.children)
    io.in_block = old_in_block
    _println(io, "]")
    return
end

"""
    typst(::Context, ::Node, ::MarkdownAST.FootnoteDefinition)

No-op for footnote definitions.

Footnote definitions are collected during the pre-scan phase and rendered inline at
FootnoteLink sites, so we don't output anything here to avoid duplication.
"""
function typst(::Context, ::Node, ::MarkdownAST.FootnoteDefinition)
    return nothing
end

function typst(io::Context, node::Node, list::MarkdownAST.List)
    symbol = list.type === :ordered ? '+' : '-'
    _println(io)
    for item in node.children
        _print(io, symbol, " ")
        typst(io, item.children)
        _println(io)
    end
end

function typst(io::Context, ::Node, ::MarkdownAST.ThematicBreak)
    _println(io, "#line(length: 100%)")
end

function typst(io::Context, ::Node, math::MarkdownAST.DisplayMath)
    _println(io)
    escaped_math = escape_for_typst_string(math.math)
    _print(io, "#mitex(\"")
    _print(io, escaped_math)
    _println(io, "\")")
    _println(io)
end

function typst(io::Context, node::Node, table::MarkdownAST.Table)
    rows = MarkdownAST.tablerows(node)
    cols = length(table.spec)
    _println(io, "#align(center)[")
    _println(io, "#table(")
    _println(io, "columns: (", repeat("auto,", cols), "),")
    _println(io, "align: (x, y) => ($(join(string.(table.spec), ",")),).at(x),")
    old_in_block = io.in_block
    io.in_block = true
    for (i, row) in enumerate(rows)
        for (j, cell) in enumerate(row.children)
            _print(io, " [")
            typst(io, cell.children)
            _print(io, "],")
        end
        _println(io)
    end
    io.in_block = old_in_block
    _println(io, ")]")
end

function typst(io::Context, ::Node, raw::Documenter.RawNode)
    raw.name === :typst || raw.name === :typ ? _println(io, "\n", raw.text, "\n") : nothing
end

# Inline Elements.

function typst(io::Context, ::Node, e::MarkdownAST.Text)
    typstesc(io, e.text)
end

function typst(io::Context, node::Node, ::MarkdownAST.Strong)
    _print(io, "#strong([")
    typst(io, node.children)
    _print(io, "])")
end

function typst(io::Context, node::Node, ::MarkdownAST.Emph)
    _print(io, "#emph([")
    typst(io, node.children)
    _print(io, "])")
end

"""
    typst(io::Context, node::Node, image::MarkdownAST.Image)

Render a Markdown image as a Typst figure with centered alignment.

# Accessibility Notes

This implementation does NOT generate the `alt` parameter for figures because:
1. The caption already provides an accessible description that screen readers will read
2. In Markdown `![text](url)`, the text becomes the caption - duplicating it to `alt` causes redundancy
3. Per W3C guidelines, figures with descriptive captions don't need separate alt text
4. The `image.title` field is also unused because Julia's Markdown parser doesn't support
   the `![alt](url "title")` syntax, and even if it did, HTML's title attribute is a hover
   tooltip with no equivalent in PDF
"""
function typst(io::Context, node::Node, image::MarkdownAST.Image)
    _println(io, "#align(center)[")
    _println(io, "#figure(")
    _println(io, "image(")
    
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
    old_in_block = io.in_block
    io.in_block = true
    typst(io, node.children)
    io.in_block = old_in_block
    _println(io, "])]")
end

function typst(io::Context, node::Node, image::Documenter.LocalImage)
    # LocalImage is similar to MarkdownAST.Image but uses .path instead of .destination
    _println(io, "#align(center)[")
    _println(io, "#figure(")
    _println(io, "image(")
    
    # Normalize path (convert backslashes to forward slashes for Typst)
    url = replace(image.path, "\\" => "/")
    
    _print(io, "\"", url, "\", ")
    _println(io, "width: 100%, fit: \"contain\"),")
    _println(io, "caption: [")
    old_in_block = io.in_block
    io.in_block = true
    typst(io, node.children)
    io.in_block = old_in_block
    _println(io, "])]")
end

function typst(io::Context, ::Node, f::MarkdownAST.FootnoteLink)
    # Look up the footnote definition
    if haskey(io.footnote_defs, f.id)
        def_node = io.footnote_defs[f.id]
        _print(io, "#footnote[")
        old_in_block = io.in_block
        io.in_block = true
        # Render the footnote content inline
        # If the content is a single paragraph, render its children directly to avoid extra newlines
        if length(def_node.children) == 1 && first(def_node.children).element isa MarkdownAST.Paragraph
            typst(io, first(def_node.children).children)
        else
            typst(io, def_node.children)
        end
        io.in_block = old_in_block
        _print(io, "]")
    else
        # Footnote definition not found - output a warning marker
        @warn "Footnote definition not found for [^$(f.id)] in $(Documenter.locrepr(io.filename))"
        _print(io, "#footnote[Missing footnote: $(f.id)]")
    end
end

# PageLink - internal cross-reference links resolved by Documenter
function typst(io::Context, node::Node, link::Documenter.PageLink)
    # PageLink represents a resolved @ref link or # same-file reference
    if link.fragment !== nothing && !isempty(link.fragment)
        # pagekey is relative path without build prefix, need to add it
        pagekey = Documenter.pagekey(io.doc, link.page)
        full_path = with_build_prefix(io.state, pagekey)
        
        # Case-insensitive lookup: link.fragment might be lowercase, but we need actual case
        # The lowercase_anchors map key includes full build path: "build_path#lowercase_label"
        lookup_key = full_path * "#" * lowercase(link.fragment)
        anchor_label = get(io.state.lowercase_anchors, lookup_key, link.fragment)
        
        # Generate label ID using the new approach
        label_id = make_label_id(io.doc, full_path, anchor_label)
        _print(io, "#link(label(\"", label_id, "\"))[")
    else
        # Link to a page without fragment - just render the text
        _print(io, "[")
    end
    typst(io, node.children)
    _print(io, "]")
end

"""
    typst(io::Context, node::Node, link::MarkdownAST.Link)

Render a Markdown link as a Typst link or label reference.

# Behavior

Properly resolved internal links should already be converted to `PageLink` by the
cross-reference pipeline. If we encounter a `MarkdownAST.Link` with `.md#` or `#` patterns,
it's likely an external link or a manual override by the user, which we handle as best-effort.

# Link Title Handling

This implementation intentionally ignores the `link.title` field because:
1. In HTML, the title attribute is a hover tooltip, not an accessibility feature
2. W3C guidelines recommend against relying on title for conveying important information
3. PDF/Typst has no hover mechanism, and `link()` doesn't support an `alt` parameter
4. Screen readers inconsistently support the title attribute, and keyboard users can't access it
5. Link text itself should be descriptive for proper accessibility

If the title contains important context, it should be incorporated into the link text or
surrounding prose instead.
"""
function typst(io::Context, node::Node, link::MarkdownAST.Link)
    if io.in_header
        typst(io, node.children)
    else
        # Check if it's an external URL first (before checking for .md#)
        # Use Documenter's isabsurl() which matches ^[[:alpha:]+-.]+://
        is_external_url = Documenter.isabsurl(link.destination)
        
        if !is_external_url && occursin(".md#", link.destination)
            # Cross-file reference: other.md#section or path/other.md#section
            file, target = split(link.destination, ".md#"; limit=2)
            file = file * ".md"  # Add back the .md extension
            # Convert to full path with build prefix
            full_path = with_build_prefix(io.state, file)
            # Generate label ID
            label_id = make_label_id(io.doc, full_path, target)
            _print(io, "#link(label(\"", label_id, "\"))")
        elseif !is_external_url && startswith(link.destination, "#")
            # Same-file reference: #anchor-slug
            fragment = lstrip(link.destination, '#')
            # io.filename is relative path, need to add build prefix
            full_path = with_build_prefix(io.state, io.filename)
            # Case-insensitive lookup with full build path
            lookup_key = full_path * "#" * lowercase(fragment)
            anchor_label = get(io.state.lowercase_anchors, lookup_key, fragment)
            # Generate label ID
            label_id = make_label_id(io.doc, full_path, anchor_label)
            _print(io, "#link(label(\"", label_id, "\"))")
        else
            # External link or other format
            _print(io, "#link(\"", link.destination, "\")")
        end
        _print(io, "[")
        typst(io, node.children)
        _print(io, "]")
    end
end

function typst(io::Context, ::Node, math::MarkdownAST.InlineMath)
    escaped_math = escape_for_typst_string(math.math)
    _print(io, "#mi(\"", escaped_math, "\")")
end

# Metadata Nodes get dropped from the final output for every format but are needed throughout
# rest of the build and so we just leave them in place and print a blank line in their place.
typst(io::Context, ::Node, ::Documenter.MetaNode) = _println(io, "\n")

# In the original AST, SetupNodes were just mapped to empty Markdown.MD() objects.
typst(::Context, ::Node, ::Documenter.SetupNode) = nothing

function typst(io::Context, ::Node, value::MarkdownAST.JuliaValue)
    @warn """
    Unexpected Julia interpolation of type $(typeof(value.ref)) in the Markdown.
    """ value = value.ref
    typstesc(io, string(value.ref))
end

# Line breaks and soft breaks
# Note: SoftBreak and Backslash nodes don't appear in Julia's standard Markdown conversions.
# - SoftBreak: represents a soft line break (single newline in source)
# - Backslash: represents a literal backslash character (\\) after escaping
# We implement them for completeness in case they're encountered from other Markdown parsers.
typst(io::Context, ::Node, ::MarkdownAST.LineBreak) = _println(io, "#linebreak()")
typst(io::Context, ::Node, ::MarkdownAST.SoftBreak) = _print(io, "#linebreak(weak: true)")  # Weak break - may or may not break
typst(io::Context, ::Node, ::MarkdownAST.Backslash) = _print(io, "\\\\")  # Literal backslash: need \\ in Typst to display \

const _typstescape_chars = Dict{Char,AbstractString}()
for ch in "@#*_\$/`<>"
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

# ============================================================================
# Page structure helpers
# ============================================================================

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
    files!(out, isnothing(v[2]) ? v[3] : v[2] => v[3], depth)
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
