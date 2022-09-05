"""
Defines node "expanders" that transform nodes from the parsed markdown files.
"""
module Expanders

import ..Documenter:
    Anchors,
    Documents,
    Documenter,
    Utilities

import .Documents:
    MethodNode,
    DocsNode,
    DocsNodes,
    EvalNode,
    MetaNode

import .Utilities: Selectors, @docerror

import Markdown, REPL
import Base64: stringmime
import IOCapture

function expand(doc::Documents.Document)
    priority_pages = filter(doc.user.expandfirst) do src
        if src in keys(doc.blueprint.pages)
            return true
        else
            @warn "$(src) in expandfirst does not exist"
            return false
        end
    end
    normal_pages = filter(src -> !(src in priority_pages), keys(doc.blueprint.pages))
    normal_pages = sort([src for src in normal_pages])
    @debug "pages" keys(doc.blueprint.pages) priority_pages normal_pages
    for src in Iterators.flatten([priority_pages, normal_pages])
        page = doc.blueprint.pages[src]
        @debug "Running ExpanderPipeline on $src"
        empty!(page.globals.meta)
        for element in page.elements
            Selectors.dispatch(ExpanderPipeline, element, page, doc)
        end
        pagecheck(page)
    end
end

# run some checks after expanding the page
function pagecheck(page)
    # make sure there is no "continued code" lingering around
    if haskey(page.globals.meta, :ContinuedCode) && !isempty(page.globals.meta[:ContinuedCode])
        @warn "code from a continued @example block unused in $(Utilities.locrepr(page.source))."
    end
end

# Draft output code block
function create_draft_result(x; blocktype="code")
    content = []
    push!(content, Markdown.Code("julia", x.code))
    push!(content, Dict{MIME,Any}(MIME"text/plain"() => "<< $(blocktype)-block not executed in draft mode >>"))
    return Documents.MultiOutput(content)
end


# Expander Pipeline.
# ------------------

"""
The default node expander "pipeline", which consists of the following expanders:

- [`TrackHeaders`](@ref)
- [`MetaBlocks`](@ref)
- [`DocsBlocks`](@ref)
- [`AutoDocsBlocks`](@ref)
- [`EvalBlocks`](@ref)
- [`IndexBlocks`](@ref)
- [`ContentsBlocks`](@ref)
- [`ExampleBlocks`](@ref)
- [`SetupBlocks`](@ref)
- [`REPLBlocks`](@ref)

"""
abstract type ExpanderPipeline <: Selectors.AbstractSelector end

"""
Tracks all `Markdown.Header` nodes found in the parsed markdown files and stores an
[`Anchors.Anchor`](@ref) object for each one.
"""
abstract type TrackHeaders <: ExpanderPipeline end

"""
Parses each code block where the language is `@meta` and evaluates the key/value pairs found
within the block, i.e.

````markdown
```@meta
CurrentModule = Documenter
DocTestSetup  = quote
    using Documenter
end
```
````
"""
abstract type MetaBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@docs` and evaluates the expressions found
within the block. Replaces the block with the docstrings associated with each expression.

````markdown
```@docs
Documenter
makedocs
deploydocs
```
````
"""
abstract type DocsBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@autodocs` and replaces it with all the
docstrings that match the provided key/value pairs `Modules = ...` and `Order = ...`.

````markdown
```@autodocs
Modules = [Foo, Bar]
Order   = [:function, :type]
```
````
"""
abstract type AutoDocsBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@eval` and evaluates it's content. Replaces
the block with the value resulting from the evaluation. This can be useful for inserting
generated content into a document such as plots.

````markdown
```@eval
using PyPlot
x = linspace(-π, π)
y = sin(x)
plot(x, y, color = "red")
savefig("plot.svg")
Markdown.parse("![Plot](plot.svg)")
```
````
"""
abstract type EvalBlocks <: ExpanderPipeline end

abstract type RawBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@index` and replaces it with an index of all
docstrings spliced into the document. The pages that are included can be set using a
key/value pair `Pages = [...]` such as

````markdown
```@index
Pages = ["foo.md", "bar.md"]
```
````
"""
abstract type IndexBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@contents` and replaces it with a nested list
of all `Header` nodes in the generated document. The pages and depth of the list can be set
using `Pages = [...]` and `Depth = N` where `N` is and integer.

````markdown
```@contents
Pages = ["foo.md", "bar.md"]
Depth = 1
```
````
The default `Depth` value is `2`.
"""
abstract type ContentsBlocks <: ExpanderPipeline end

"""
Parses each code block where the language is `@example` and evaluates the parsed Julia code
found within. The resulting value is then inserted into the final document after the source
code.

````markdown
```@example
a = 1
b = 2
a + b
```
````
"""
abstract type ExampleBlocks <: ExpanderPipeline end

"""
Similar to the [`ExampleBlocks`](@ref) expander, but inserts a Julia REPL prompt before each
toplevel expression in the final document.
"""
abstract type REPLBlocks <: ExpanderPipeline end

"""
Similar to the [`ExampleBlocks`](@ref) expander, but hides all output in the final document.
"""
abstract type SetupBlocks <: ExpanderPipeline end

Selectors.order(::Type{TrackHeaders})   = 1.0
Selectors.order(::Type{MetaBlocks})     = 2.0
Selectors.order(::Type{DocsBlocks})     = 3.0
Selectors.order(::Type{AutoDocsBlocks}) = 4.0
Selectors.order(::Type{EvalBlocks})     = 5.0
Selectors.order(::Type{IndexBlocks})    = 6.0
Selectors.order(::Type{ContentsBlocks}) = 7.0
Selectors.order(::Type{ExampleBlocks})  = 8.0
Selectors.order(::Type{REPLBlocks})     = 9.0
Selectors.order(::Type{SetupBlocks})    = 10.0
Selectors.order(::Type{RawBlocks})      = 11.0

Selectors.matcher(::Type{TrackHeaders},   node, page, doc) = isa(node, Markdown.Header)
Selectors.matcher(::Type{MetaBlocks},     node, page, doc) = iscode(node, "@meta")
Selectors.matcher(::Type{DocsBlocks},     node, page, doc) = iscode(node, "@docs")
Selectors.matcher(::Type{AutoDocsBlocks}, node, page, doc) = iscode(node, "@autodocs")
Selectors.matcher(::Type{EvalBlocks},     node, page, doc) = iscode(node, "@eval")
Selectors.matcher(::Type{IndexBlocks},    node, page, doc) = iscode(node, "@index")
Selectors.matcher(::Type{ContentsBlocks}, node, page, doc) = iscode(node, "@contents")
Selectors.matcher(::Type{ExampleBlocks},  node, page, doc) = iscode(node, r"^@example")
Selectors.matcher(::Type{REPLBlocks},     node, page, doc) = iscode(node, r"^@repl")
Selectors.matcher(::Type{SetupBlocks},    node, page, doc) = iscode(node, r"^@setup")
Selectors.matcher(::Type{RawBlocks},      node, page, doc) = iscode(node, r"^@raw")

# Default Expander.

Selectors.runner(::Type{ExpanderPipeline}, x, page, doc) = page.mapping[x] = x

# Track Headers.
# --------------

function Selectors.runner(::Type{TrackHeaders}, header, page, doc)
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
end

# @meta
# -----

function Selectors.runner(::Type{MetaBlocks}, x, page, doc)
    meta = page.globals.meta
    lines = Utilities.find_block_in_file(x.code, page.source)
    @debug "Evaluating @meta block:\n$(x.code)"
    for (ex, str) in Utilities.parseblock(x.code, doc, page)
        if Utilities.isassign(ex)
            try
                meta[ex.args[1]] = Core.eval(Main, ex.args[2])
            catch err
                @docerror(doc, :meta_block,
                    """
                    failed to evaluate `$(strip(str))` in `@meta` block in $(Utilities.locrepr(page.source, lines))
                    ```$(x.language)
                    $(x.code)
                    ```
                    """, exception = err)
            end
        end
    end
    page.mapping[x] = MetaNode(copy(meta))
end

# @docs
# -----

function Selectors.runner(::Type{DocsBlocks}, x, page, doc)
    nodes  = Union{DocsNode,Markdown.Admonition}[]
    curmod = get(page.globals.meta, :CurrentModule, Main)
    lines = Utilities.find_block_in_file(x.code, page.source)
    @debug "Evaluating @docs block:\n$(x.code)"
    for (ex, str) in Utilities.parseblock(x.code, doc, page)
        admonition = Markdown.Admonition("warning", "Missing docstring.",
            Utilities.mdparse("Missing docstring for `$(strip(str))`. Check Documenter's build log for details.", mode=:blocks))
        binding = try
            Documenter.DocSystem.binding(curmod, ex)
        catch err
            @docerror(doc, :docs_block,
                """
                unable to get the binding for '$(strip(str))' in `@docs` block in $(Utilities.locrepr(page.source, lines)) from expression '$(repr(ex))' in module $(curmod)
                ```$(x.language)
                $(x.code)
                ```
                """,
                exception = err)
            push!(nodes, admonition)
            continue
        end
        # Undefined `Bindings` get discarded.
        if !Documenter.DocSystem.iskeyword(binding) && !Documenter.DocSystem.defined(binding)
            @docerror(doc, :docs_block,
                """
                undefined binding '$(binding)' in `@docs` block in $(Utilities.locrepr(page.source, lines))
                ```$(x.language)
                $(x.code)
                ```
                """)
            push!(nodes, admonition)
            continue
        end
        typesig = Core.eval(curmod, Documenter.DocSystem.signature(ex, str))

        object = Utilities.Object(binding, typesig)
        # We can't include the same object more than once in a document.
        if haskey(doc.internal.objects, object)
            @docerror(doc, :docs_block,
                """
                duplicate docs found for '$(strip(str))' in `@docs` block in $(Utilities.locrepr(page.source, lines))
                ```$(x.language)
                $(x.code)
                ```
                """)
            push!(nodes, admonition)
            continue
        end

        # Find the docs matching `binding` and `typesig`. Only search within the provided modules.
        docs = Documenter.DocSystem.getdocs(binding, typesig; modules = doc.blueprint.modules)

        # Include only docstrings from user-provided modules if provided.
        if !isempty(doc.blueprint.modules)
            filter!(d -> d.data[:module] in doc.blueprint.modules, docs)
        end

        # Check that we aren't printing an empty docs list. Skip block when empty.
        if isempty(docs)
            @docerror(doc, :docs_block,
                """
                no docs found for '$(strip(str))' in `@docs` block in $(Utilities.locrepr(page.source, lines))
                ```$(x.language)
                $(x.code)
                ```
                """)
            push!(nodes, admonition)
            continue
        end

        # Concatenate found docstrings into a single `MD` object.
        docstr = Markdown.MD(map(Documenter.DocSystem.parsedoc, docs))
        docstr.meta[:results] = docs

        # If the first element of the docstring is a code block, make it Julia by default.
        doc.user.highlightsig && highlightsig!(docstr)

        # Generate a unique name to be used in anchors and links for the docstring.
        slug = Utilities.slugify(object)
        anchor = Anchors.add!(doc.internal.docs, object, slug, page.build)
        docsnode = DocsNode(docstr, anchor, object, page)

        # Track the order of insertion of objects per-binding.
        push!(get!(doc.internal.bindings, binding, Utilities.Object[]), object)

        doc.internal.objects[object] = docsnode
        push!(nodes, docsnode)
    end
    page.mapping[x] = DocsNodes(nodes)
end

# @autodocs
# ---------

const AUTODOCS_DEFAULT_ORDER = [:module, :constant, :type, :function, :macro]

function Selectors.runner(::Type{AutoDocsBlocks}, x, page, doc)
    curmod = get(page.globals.meta, :CurrentModule, Main)
    fields = Dict{Symbol, Any}()
    lines = Utilities.find_block_in_file(x.code, page.source)
    @debug "Evaluating @autodocs block:\n$(x.code)"
    for (ex, str) in Utilities.parseblock(x.code, doc, page)
        if Utilities.isassign(ex)
            try
                if ex.args[1] == :Filter
                    fields[ex.args[1]] = Core.eval(Main, ex.args[2])
                else
                    fields[ex.args[1]] = Core.eval(curmod, ex.args[2])
                end
            catch err
                @docerror(doc, :autodocs_block,
                    """
                    failed to evaluate `$(strip(str))` in `@autodocs` block in $(Utilities.locrepr(page.source, lines))
                    ```$(x.language)
                    $(x.code)
                    ```
                    """, exception = err)
            end
        end
    end
    if haskey(fields, :Modules)
        # Gather and filter docstrings.
        modules = fields[:Modules]
        order = get(fields, :Order, AUTODOCS_DEFAULT_ORDER)
        pages = map(normpath, get(fields, :Pages, []))
        public = get(fields, :Public, true)
        private = get(fields, :Private, true)
        filterfunc = get(fields, :Filter, x -> true)
        results = []
        for mod in modules
            for (binding, multidoc) in Documenter.DocSystem.getmeta(mod)
                # Which bindings should be included?
                isexported = Base.isexported(mod, binding.var)
                included = (isexported && public) || (!isexported && private)
                # What category does the binding belong to?
                category = try
                    Documenter.DocSystem.category(binding)
                catch err
                    isa(err, UndefVarError) || rethrow(err)
                    @docerror(doc, :autodocs_block,
                    """
                    @autodocs ($(Utilities.locrepr(page.source, lines))) encountered a bad docstring binding '$(binding)'
                    ```$(x.language)
                    $(x.code)
                    ```
                    This is likely due to a bug in the Julia docsystem relating to the handling of
                    docstrings attached to methods of callable objects. See:

                      https://github.com/JuliaLang/julia/issues/45174

                    As a workaround, the docstrings for the functor methods could be included in the docstring
                    of the type definition. This error can also be ignored by disabling strict checking for
                    :autodocs_block in the makedocs call with e.g.

                      strict = Documenter.except(:autodocs_block)

                    However, the relevant docstrings will then not be included by the @autodocs block.
                    """, exception = err)
                    continue # skip this docstring
                end
                if category in order && included
                    # filter the elements after category/order has been evaluated
                    # to ensure that e.g. when `Order = [:type]` is given, the filter
                    # function really receives only types
                    filtered = Base.invokelatest(filterfunc, Core.eval(binding.mod, binding.var))
                    if filtered
                        for (typesig, docstr) in multidoc.docs
                            path = normpath(docstr.data[:path])
                            object = Utilities.Object(binding, typesig)
                            if isempty(pages)
                                push!(results, (mod, path, category, object, isexported, docstr))
                            else
                                for p in pages
                                    if endswith(path, p)
                                        push!(results, (mod, p, category, object, isexported, docstr))
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        # Sort docstrings.
        modulemap = Documents.precedence(modules)
        pagesmap = Documents.precedence(pages)
        ordermap = Documents.precedence(order)
        comparison = function (a, b)
            local t
            (t = Documents._compare(modulemap, 1, a, b)) == 0 || return t < 0 # module
            (t = Documents._compare(pagesmap,  2, a, b)) == 0 || return t < 0 # page
            (t = Documents._compare(ordermap,  3, a, b)) == 0 || return t < 0 # category
            string(a[4]) < string(b[4])                                       # name
        end
        sort!(results; lt = comparison)

        # Finalise docstrings.
        nodes = DocsNode[]
        for (mod, path, category, object, isexported, docstr) in results
            if haskey(doc.internal.objects, object)
                @docerror(doc, :autodocs_block,
                    """
                    duplicate docs found for '$(object.binding)' in $(Utilities.locrepr(page.source, lines))
                    ```$(x.language)
                    $(x.code)
                    ```
                    """)
                continue
            end
            markdown = Markdown.MD(Documenter.DocSystem.parsedoc(docstr))
            markdown.meta[:results] = [docstr]
            doc.user.highlightsig && highlightsig!(markdown)
            slug = Utilities.slugify(object)
            anchor = Anchors.add!(doc.internal.docs, object, slug, page.build)
            docsnode = DocsNode(markdown, anchor, object, page)

            # Track the order of insertion of objects per-binding.
            push!(get!(doc.internal.bindings, object.binding, Utilities.Object[]), object)

            doc.internal.objects[object] = docsnode
            push!(nodes, docsnode)
        end
        page.mapping[x] = DocsNodes(nodes)
    else
        @docerror(doc, :autodocs_block,
            """
            '@autodocs' missing 'Modules = ...' in $(Utilities.locrepr(page.source, lines))
            ```$(x.language)
            $(x.code)
            ```
            """)
        page.mapping[x] = x
    end
end

# @eval
# -----

function Selectors.runner(::Type{EvalBlocks}, x, page, doc)
    # Bail early if in draft mode
    if Utilities.is_draft(doc, page)
        @debug "Skipping evaluation of @eval block in draft mode:\n$(x.code)"
        page.mapping[x] = create_draft_result(x; blocktype="@eval")
        return
    end
    sandbox = Module(:EvalBlockSandbox)
    lines = Utilities.find_block_in_file(x.code, page.source)
    linenumbernode = LineNumberNode(lines === nothing ? 0 : lines.first,
                                    basename(page.source))
    @debug "Evaluating @eval block:\n$(x.code)"
    cd(page.workdir) do
        result = nothing
        for (ex, str) in Utilities.parseblock(x.code, doc, page; keywords = false,
                                              linenumbernode = linenumbernode)
            try
                result = Core.eval(sandbox, ex)
            catch err
                @docerror(doc, :eval_block,
                    """
                    failed to evaluate `@eval` block in $(Utilities.locrepr(page.source))
                    ```$(x.language)
                    $(x.code)
                    ```
                    """, exception = err)
            end
        end
        result = if isa(result, Nothing) || isa(result, Markdown.MD)
            result
        else
            # TODO: we could handle the cases where the user provides some of the Markdown library
            # objects, like Paragraph.
            @warn """
            Invalid type of object in @eval in $(Utilities.locrepr(page.source))
            ```$(x.language)
            $(x.code)
            ```
            Evaluate to `$(typeof(result))`, should be one of
             - Nothing
             - Markdown.MD
            Falling back to code block representation.

            If you are seeing this warning after upgrading Documenter and this used to work,
            please open an issue on the Documenter issue tracker.
            """
            Markdown.Code("", sprint(show, MIME"text/plain"(), result))
        end
        page.mapping[x] = EvalNode(x, result)
    end
end

# @index
# ------

function Selectors.runner(::Type{IndexBlocks}, x, page, doc)
    node = Documents.buildnode(Documents.IndexNode, x, doc, page)
    push!(doc.internal.indexnodes, node)
    page.mapping[x] = node
end

# @contents
# ---------

function Selectors.runner(::Type{ContentsBlocks}, x, page, doc)
    node = Documents.buildnode(Documents.ContentsNode, x, doc, page)
    push!(doc.internal.contentsnodes, node)
    page.mapping[x] = node
end

# @example
# --------

# Find if there is any format with color output
function _any_color_fmt(doc)
    idx = findfirst(x -> x isa Documenter.HTML, doc.user.format)
    idx === nothing && return false
    return doc.user.format[idx].ansicolor
end

function Selectors.runner(::Type{ExampleBlocks}, x, page, doc)
    matched = match(r"^@example(?:\s+([^\s;]+))?\s*(;.*)?$", x.language)
    matched === nothing && error("invalid '@example' syntax: $(x.language)")
    name, kwargs = matched.captures

    # Bail early if in draft mode
    if Utilities.is_draft(doc, page)
        @debug "Skipping evaluation of @example block in draft mode:\n$(x.code)"
        page.mapping[x] = create_draft_result(x; blocktype="@example")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Utilities.get_sandbox_module!(page.globals.meta, "atexample", name)
    sym = nameof(mod)
    lines = Utilities.find_block_in_file(x.code, page.source)

    # "parse" keyword arguments to example
    continued = false
    ansicolor = _any_color_fmt(doc)
    if kwargs !== nothing
        continued = occursin(r"\bcontinued\s*=\s*true\b", kwargs)
        matched = match(r"\bansicolor\s*=\s*(true|false)\b", kwargs)
        if matched !== nothing
            ansicolor = matched[1] == "true"
        end
    end

    @debug "Evaluating @example block:\n$(x.code)"
    # Evaluate the code block. We redirect stdout/stderr to `buffer`.
    result, buffer = nothing, IOBuffer()
    if !continued # run the code
        # check if there is any code wating
        if haskey(page.globals.meta, :ContinuedCode) && haskey(page.globals.meta[:ContinuedCode], sym)
            code = page.globals.meta[:ContinuedCode][sym] * '\n' * x.code
            delete!(page.globals.meta[:ContinuedCode], sym)
        else
            code = x.code
        end
        linenumbernode = LineNumberNode(lines === nothing ? 0 : lines.first,
                                        basename(page.source))
        for (ex, str) in Utilities.parseblock(code, doc, page; keywords = false,
                                              linenumbernode = linenumbernode)
            c = IOCapture.capture(rethrow = InterruptException, color = ansicolor) do
                cd(page.workdir) do
                    Core.eval(mod, ex)
                end
            end
            Core.eval(mod, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
            result = c.value
            print(buffer, c.output)
            if c.error
                @docerror(doc, :example_block,
                    """
                    failed to run `@example` block in $(Utilities.locrepr(page.source, lines))
                    ```$(x.language)
                    $(x.code)
                    ```
                    """, value = c.value)
                page.mapping[x] = x
                return
            end
        end
    else # store the continued code
        CC = get!(page.globals.meta, :ContinuedCode, Dict())
        CC[sym] = get(CC, sym, "") * '\n' * x.code
    end
    # Splice the input and output into the document.
    content = []
    input   = droplines(x.code)

    # Generate different  in different formats and let each writer select
    output = Base.invokelatest(Utilities.display_dict, result, context = :color => ansicolor)
    # Remove references to gensym'd module from text/plain
    m = MIME"text/plain"()
    if haskey(output, m)
        output[m] = remove_sandbox_from_output(output[m], mod)
    end

    # Only add content when there's actually something to add.
    isempty(input) || push!(content, Markdown.Code("julia", input))
    if result === nothing
        stdouterr = Documenter.DocTests.sanitise(buffer)
        stdouterr = remove_sandbox_from_output(stdouterr, mod)
        isempty(stdouterr) || push!(content, Dict{MIME,Any}(MIME"text/plain"() => stdouterr))
    elseif !isempty(output)
        push!(content, output)
    end
    # ... and finally map the original code block to the newly generated ones.
    page.mapping[x] = Documents.MultiOutput(content)
end

# Replace references to gensym'd module with Main
function remove_sandbox_from_output(str, mod::Module)
    replace(str, Regex(("(Main\\.)?$(nameof(mod))")) => "Main")
end

# @repl
# -----

function Selectors.runner(::Type{REPLBlocks}, x, page, doc)
    matched = match(r"^@repl(?:\s+([^\s;]+))?\s*(;.*)?$", x.language)
    matched === nothing && error("invalid '@repl' syntax: $(x.language)")
    name, kwargs = matched.captures

    # Bail early if in draft mode
    if Utilities.is_draft(doc, page)
        @debug "Skipping evaluation of @repl block in draft mode:\n$(x.code)"
        page.mapping[x] = create_draft_result(x; blocktype="@repl")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Utilities.get_sandbox_module!(page.globals.meta, "atexample", name)

    # "parse" keyword arguments to repl
    ansicolor = _any_color_fmt(doc)
    if kwargs !== nothing
        matched = match(r"\bansicolor\s*=\s*(true|false)\b", kwargs)
        if matched !== nothing
            ansicolor = matched[1] == "true"
        end
    end

    multicodeblock = Markdown.Code[]
    linenumbernode = LineNumberNode(0, "REPL") # line unused, set to 0
    @debug "Evaluating @repl block:\n$(x.code)"
    for (ex, str) in Utilities.parseblock(x.code, doc, page; keywords = false,
                                          linenumbernode = linenumbernode)
        input  = droplines(str)
        # Use the REPL softscope for REPLBlocks,
        # see https://github.com/JuliaLang/julia/pull/33864
        ex = REPL.softscope!(ex)
        c = IOCapture.capture(rethrow = InterruptException, color = ansicolor) do
            cd(page.workdir) do
                Core.eval(mod, ex)
            end
        end
        Core.eval(mod, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
        result = c.value
        buf = IOContext(IOBuffer(), :color=>ansicolor)
        output = if !c.error
            hide = REPL.ends_with_semicolon(input)
            Documenter.DocTests.result_to_string(buf, hide ? nothing : c.value)
        else
            Documenter.DocTests.error_to_string(buf, c.value, [])
        end
        if !isempty(input)
            push!(multicodeblock, Markdown.Code("julia-repl", prepend_prompt(input)))
        end
        out = IOBuffer()
        print(out, c.output) # c.output is std(out|err)
        if isempty(input) || isempty(output)
            println(out)
        else
            println(out, output, "\n")
        end

        outstr = String(take!(out))
        # Replace references to gensym'd module with Main
        outstr = remove_sandbox_from_output(outstr, mod)
        push!(multicodeblock, Markdown.Code("documenter-ansi", rstrip(outstr)))
    end
    page.mapping[x] = Documents.MultiCodeBlock("julia-repl", multicodeblock)
end

# @setup
# ------

function Selectors.runner(::Type{SetupBlocks}, x, page, doc)
    matched = match(r"^@setup(?:\s+([^\s;]+))?\s*$", x.language)
    matched === nothing && error("invalid '@setup <name>' syntax: $(x.language)")
    name = matched[1]

    # Bail early if in draft mode
    if Utilities.is_draft(doc, page)
        @debug "Skipping evaluation of @setup block in draft mode:\n$(x.code)"
        page.mapping[x] = create_draft_result(x; blocktype="@setup")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Utilities.get_sandbox_module!(page.globals.meta, "atexample", name)

    @debug "Evaluating @setup block:\n$(x.code)"
    # Evaluate whole @setup block at once instead of piecewise
    page.mapping[x] =
    try
        cd(page.workdir) do
            include_string(mod, x.code)
        end
        Markdown.MD([])
    catch err
        @docerror(doc, :setup_block,
            """
            failed to run `@setup` block in $(Utilities.locrepr(page.source))
            ```$(x.language)
            $(x.code)
            ```
            """, exception=err)
        x
    end
    # ... and finally map the original code block to the newly generated ones.
    page.mapping[x] = Markdown.MD([])
end

# @raw
# ----

function Selectors.runner(::Type{RawBlocks}, x, page, doc)
    m = match(r"@raw[ ](.+)$", x.language)
    m === nothing && error("invalid '@raw <name>' syntax: $(x.language)")
    page.mapping[x] = Documents.RawNode(Symbol(m[1]), x.code)
end

# Utilities.
# ----------

iscode(x::Markdown.Code, r::Regex) = occursin(r, x.language)
iscode(x::Markdown.Code, lang)     = x.language == lang
iscode(x, lang)                    = false

const NAMEDHEADER_REGEX = r"^@id (.+)$"

function namedheader(h::Markdown.Header)
    if isa(h.text, Vector) && length(h.text) === 1 && isa(h.text[1], Markdown.Link)
        url = h.text[1].url
        occursin(NAMEDHEADER_REGEX, url)
    else
        false
    end
end

# Remove any `# hide` lines, leading/trailing blank lines, and trailing whitespace.
function droplines(code; skip = 0)
    buffer = IOBuffer()
    for line in split(code, r"\r?\n")[(skip + 1):end]
        occursin(r"^(.*)#\s*hide$", line) && continue
        println(buffer, rstrip(line))
    end
    strip(String(take!(buffer)), '\n')
end

function prepend_prompt(input)
    prompt  = "julia> "
    padding = " "^length(prompt)
    out = IOBuffer()
    for (n, line) in enumerate(split(input, '\n'))
        line = rstrip(line)
        println(out, n == 1 ? prompt : padding, line)
    end
    rstrip(String(take!(out)))
end

highlightsig!(x) = nothing
function highlightsig!(md::Markdown.MD)
    isempty(md.content) || highlightsig!(first(md.content))
end
function highlightsig!(code::Markdown.Code)
    if isempty(code.language)
        code.language = "julia"
    end
end

end
