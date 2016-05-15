"""
Defines node "expanders" that transform nodes from the parsed markdown files.
"""
module Expanders

import ..Documenter:

    Anchors,
    Builder,
    Documents,
    Formats,
    Documenter,
    Utilities

using Compat

# Basic driver definitions.
# -------------------------

const CURLY_BRACKET_SYNTAX = r"^{([a-z]+)(.*)}"

const CURLY_NAMES = Set([
    "meta",
    "docs",
    "autodocs",
    "eval",
    "index",
    "contents",
    "example",
    "repl"
])

function deprecate_syntax!(element::Markdown.Code)
    if ismatch(CURLY_BRACKET_SYNTAX, element.code)
        m = match(CURLY_BRACKET_SYNTAX, element.code)
        name, id = m[1], m[2]
        if name in CURLY_NAMES
            _id = lstrip(id)
            new_syntax = string("@", name, isempty(_id) ? "" : " $_id")
            warn(
                """
                syntax '{$name$id}' is deprecated. Use the following syntax instead:

                    ```$new_syntax
                    ...
                    ```

                """
            )
            lines = split(element.code, '\n', limit = 2)[2:end]
            element.code = join(split(element.code, '\n', limit = 2)[2:end])
            element.language = new_syntax
        end
    end
    nothing
end
deprecate_syntax!(other) = nothing

"""
    expand(ex, doc)

Expands each node of a [`Documents.Document`](@ref) using the expanders provided by `ex`.
"""
function expand(ex::Builder.ExpandTemplates, doc::Documents.Document)
    for (src, page) in doc.internal.pages
        empty!(page.globals.meta)
        for element in page.elements
            deprecate_syntax!(element)
            expand(ex.expanders, element, page, doc)
        end
    end
end

function expand(pipeline, elem, page, doc)
    expand(Builder.car(pipeline), elem, page, doc)::Bool && return
    expand(Builder.cdr(pipeline), elem, page, doc)
end
expand(::Builder.Expander, elem, page, doc) = false

# Default to mapping each element to itself.
expand(::Tuple{}, elem, page, doc) = (page.mapping[elem] = elem; true)

# Implementations.
# ----------------

const NAMEDHEADER_REGEX = r"^@id (.+)$"
const OLD_NAMEDHEADER_REGEX = r"^{ref#([^{}]+)}$"

function namedheader(h::Markdown.Header)
    if isa(h.text, Vector) && length(h.text) === 1 && isa(h.text[1], Markdown.Link)
        url = h.text[1].url
        if ismatch(OLD_NAMEDHEADER_REGEX, url)
            id = match(OLD_NAMEDHEADER_REGEX, url)[1]
            h.text[1].url = "@id $id"
            warn("syntax '", url, "' is deprecated. Use '@id ", id, "' instead.")
            true
        else
            ismatch(NAMEDHEADER_REGEX, url)
        end
    else
        false
    end
end

function expand(::Builder.TrackHeaders, header::Base.Markdown.Header, page, doc)
    # Get the header slug.
    text =
        if namedheader(header)
            url = header.text[1].url
            header.text = header.text[1].text
            match(NAMEDHEADER_REGEX, url)[1]
        else
            sprint(Markdown.plain, Markdown.Paragraph(header.text))
        end
    slug = Utilities.slugify(text)
    # Add the header to the document's header map.
    anchor = Anchors.add!(doc.internal.headers, header, slug, page.build)
    # Map the header element to the generated anchor and the current anchor count.
    page.mapping[header] = anchor
    return true
end

immutable MetaNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.MetaBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@meta" || return false
    meta = page.globals.meta
    for (ex, str) in Utilities.parseblock(x.code)
        Utilities.isassign(ex) && (meta[ex.args[1]] = eval(current_module(), ex.args[2]))
    end
    page.mapping[x] = MetaNode(copy(meta))
    return true
end

immutable DocsNode
    docstr :: Any
    anchor :: Anchors.Anchor
    object :: Utilities.Object
    page   :: Documents.Page
end
immutable DocsNodes
    nodes :: Vector{DocsNode}
end
function expand(::Builder.DocsBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@docs" || return false
    failed = false
    nodes  = DocsNode[]
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    for (ex, str) in Utilities.parseblock(x.code)
        # Find the documented object and it's docstring.
        object   = eval(curmod, Utilities.object(ex, str))
        docstr   = eval(curmod, Utilities.docs(ex, str))
        slug     = Utilities.slugify(object)

        # Remove docstrings that are not from the user-specified list of modules.
        filtered = Utilities.filterdocs(docstr, doc.user.modules)

        # Error Checking.
        let name = strip(str),
            nodocs = Utilities.nodocs(docstr),
            dupdoc = haskey(doc.internal.objects, object),
            nuldoc = isnull(filtered)

            nodocs && Utilities.warn(page.source, "No docs found for '$name'.")
            dupdoc && Utilities.warn(page.source, "Duplicate docs found for '$name'.")
            nuldoc && Utilities.warn(page.source, "No docs for '$object' from provided modules.")

            # When an warning is raise here we discard all found docs from the `{docs}` and
            # just map the element `x` back to itself and move on to the next element.
            (failed = failed || nodocs || dupdoc || nuldoc) && continue
        end

        # Update `doc` with new object and anchor.
        docstr   = get(filtered)
        anchor   = Anchors.add!(doc.internal.docs, object, slug, page.build)
        docsnode = DocsNode(docstr, anchor, object, page)
        doc.internal.objects[object] = docsnode
        push!(nodes, docsnode)
    end
    page.mapping[x] = failed ? x : DocsNodes(nodes)
    return true
end

function expand(::Builder.AutoDocsBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@autodocs" || return false
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    fields = Dict{Symbol, Any}()
    for (ex, str) in Utilities.parseblock(x.code)
        if Utilities.isassign(ex)
            fields[ex.args[1]] = eval(curmod, ex.args[2])
        end
    end
    if haskey(fields, :Modules)
        order = get(fields, :Order, [:module, :constant, :type, :function, :macro])
        block = IOBuffer()
        for mod in fields[:Modules]
            bindings = collect(keys(Documenter.DocChecks.allbindings(mod)))
            sorted   = Dict{Symbol, Vector{Utilities.Binding}}()
            for b in bindings
                category = Symbol(lowercase(Utilities.doccat(b, Union{})))
                push!(get!(sorted, category, Utilities.Binding[]), b)
            end
            for category in order
                for b in sort!(get(sorted, category, Utilities.Binding[]), by = string)
                    println(block, b)
                end
            end
        end
        x.language = "@docs"
        x.code = takebuf_string(block)
        expand(Builder.DocsBlocks(), x, page, doc)
    else
        Utilities.warn(page.source, "'@autodocs' missing 'Modules = ...'.")
        page.mapping[x] = x
    end
    return true
end

immutable EvalNode
    code   :: Base.Markdown.Code
    result :: Any
end
function expand(::Builder.EvalBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@eval" || return false
    sandbox = Module(:EvalBlockSandbox)
    cd(dirname(page.build)) do
        result = nothing
        for (ex, str) in Utilities.parseblock(x.code)
            result = eval(sandbox, ex)
        end
        page.mapping[x] = EvalNode(x, result)
    end
    return true
end

immutable IndexNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.IndexBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@index" || return false
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    dict   = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(x.code)
        Utilities.isassign(ex) && (dict[ex.args[1]] = eval(curmod, ex.args[2]))
    end
    page.mapping[x] = IndexNode(dict)
    return true
end

immutable ContentsNode
    dict :: Dict{Symbol, Any}
end
function expand(::Builder.ContentsBlocks, x::Base.Markdown.Code, page, doc)
    x.language == "@contents" || return false
    curmod = get(page.globals.meta, :CurrentModule, current_module())
    dict   = Dict{Symbol, Any}(:source => page.source, :build => page.build)
    for (ex, str) in Utilities.parseblock(x.code)
        Utilities.isassign(ex) && (dict[ex.args[1]] = eval(curmod, ex.args[2]))
    end
    page.mapping[x] = ContentsNode(dict)
    return true
end

function expand(::Builder.ExampleBlocks, x::Base.Markdown.Code, page, doc)
    # Match `{example}` and `{example <name>}` blocks.
    matched = Utilities.nullmatch(r"^@example[ ]?(.*)$", x.language)
    isnull(matched) && return false
    # The sandboxed module -- either a new one or a cached one from this page.
    name = Utilities.getmatch(matched, 1)
    sym  = isempty(name) ? gensym("ex-") : Symbol("ex-", name)
    mod  = get!(page.globals.meta, sym, Module(sym))::Module
    # Evaluate the code block. We redirect STDOUT/STDERR to `buffer`.
    result, buffer = nothing, IOBuffer()
    for (ex, str) in Utilities.parseblock(x.code)
        try
            result = Documenter.DocChecks.withoutput(buffer) do
                # Evaluate within the build folder. Defines REPL-like `ans` binding as well.
                cd(dirname(page.build)) do
                    eval(mod, :(ans = $(eval(mod, ex))))
                end
            end
        catch err
            # TODO: should errors be allowed to appear in the generated result?
            #       Currently we just bail out and leave the original code block as is.
            Utilities.warn(page.source, "failed to run code block.\n\n$err")
            page.mapping[x] = x
            return true
        end
    end
    # Splice the input and output into the document.
    content = []
    input   = droplines(x.code)
    output  = Documenter.DocChecks.result_to_string(buffer, result)
    # Only add content when there's actually something to add.
    isempty(input)  || push!(content, Markdown.Code("julia", input))
    isempty(output) || push!(content, Markdown.Code(output))
    # ... and finally map the original code block to the newly generated ones.
    page.mapping[x] = Markdown.MD(content)
    true
end

# Remove any `# hide` lines, leading/trailing blank lines, and trailing whitespace.
function droplines(code; skip = 0)
    buffer = IOBuffer()
    for line in split(code, '\n')[(skip + 1):end]
        ismatch(r"^(.*)# hide$", line) && continue
        println(buffer, rstrip(line))
    end
    strip(takebuf_string(buffer), '\n')
end

function expand(::Builder.REPLBlocks, x::Base.Markdown.Code, page, doc)
    matched = Utilities.nullmatch(r"^@repl[ ]?(.*)$", x.language)
    isnull(matched) && return false
    name = Utilities.getmatch(matched, 1)
    sym  = isempty(name) ? gensym("repl-") : Symbol("repl-", name)
    mod  = get!(page.globals.meta, sym, Module(sym))::Module
    code = split(x.code, '\n'; limit = 2)[end]
    result, out = nothing, IOBuffer()
    for (ex, str) in Utilities.parseblock(x.code)
        buffer = IOBuffer()
        input  = droplines(str)
        output =
            try
                result = Documenter.DocChecks.withoutput(buffer) do
                    cd(dirname(page.build)) do
                        eval(mod, :(ans = $(eval(mod, ex))))
                    end
                end
                hide = Documenter.DocChecks.ends_with_semicolon(input)
                Documenter.DocChecks.result_to_string(buffer, hide ? nothing : result)
            catch err
                # TODO: Pass the backtrace through? Needs filtering to remove line info from
                #       Documenter module and it's submodules.
                Documenter.DocChecks.error_to_string(buffer, err, [])
            end
        isempty(input) || println(out, prepend_prompt(input))
        if isempty(input) || isempty(output)
            println(out)
        else
            println(out, output, "\n")
        end
    end
    # Trailing whitespace in `"julia "` to avoid doctesting generated repl examples.
    page.mapping[x] = Base.Markdown.Code("julia ", rstrip(takebuf_string(out)))
    return true
end

function prepend_prompt(input)
    prompt  = "julia> "
    padding = " "^length(prompt)
    out = IOBuffer()
    for (n, line) in enumerate(split(input, '\n'))
        line = rstrip(line)
        println(out, n == 1 ? prompt : padding, line)
    end
    rstrip(takebuf_string(out))
end

end
