"""
Defines node "expanders" that transform nodes from the parsed markdown files.
"""
module Expanders

import ..Documenter:
    Anchors,
    Documenter

import .Documenter:
    MethodNode,
    DocsNode,
    DocsNodes,
    EvalNode,
    MetaNode

import .Documenter: Selectors, @docerror
using Documenter.MDFlatten

using MarkdownAST: MarkdownAST, Node
import Markdown, REPL
import Base64: stringmime
import IOCapture

function expand(doc::Documenter.Document)
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
        # We need to collect the child nodes here because we will end up changing the structure
        # of the tree in some cases.
        for node in collect(page.mdast.children)
            Selectors.dispatch(ExpanderPipeline, node, page, doc)
            expand_recursively(node, page, doc)
        end
        pagecheck(page)
    end
end

"""
Similar to `expand()`, but recursively calls itself on all descendants of `node`
and applies `NestedExpanderPipeline` instead of `ExpanderPipeline`.
"""
function expand_recursively(node, page, doc)
    if typeof(node.element) in (
        MarkdownAST.Admonition,
        MarkdownAST.BlockQuote,
        MarkdownAST.Item,
        MarkdownAST.List,
    )
        for child in node.children
            Selectors.dispatch(NestedExpanderPipeline, child, page, doc)
            expand_recursively(child, page, doc)
        end
    end
end

# run some checks after expanding the page
function pagecheck(page)
    # make sure there is no "continued code" lingering around
    if haskey(page.globals.meta, :ContinuedCode) && !isempty(page.globals.meta[:ContinuedCode])
        @warn "code from a continued @example block unused in $(Documenter.locrepr(page.source))."
    end
end

# Draft output code block
function create_draft_result!(node::Node; blocktype="code")
    @assert node.element isa MarkdownAST.CodeBlock
    codeblock = node.element
    codeblock.info = "julia"
    node.element = Documenter.MultiOutput(codeblock)
    push!(node.children, Node(codeblock))
    push!(node.children, Node(Documenter.MultiOutputElement(
        Dict{MIME,Any}(MIME"text/plain"() => "<< $(blocktype)-block not executed in draft mode >>")
    )))
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
The subset of [node expanders](@ref ExpanderPipeline) which also apply in nested contexts.

See also [`expand_recursively`](@ref).
"""
abstract type NestedExpanderPipeline <: ExpanderPipeline end

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
abstract type EvalBlocks <: NestedExpanderPipeline end

abstract type RawBlocks <: NestedExpanderPipeline end

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
abstract type ExampleBlocks <: NestedExpanderPipeline end

"""
Similar to the [`ExampleBlocks`](@ref) expander, but inserts a Julia REPL prompt before each
toplevel expression in the final document.
"""
abstract type REPLBlocks <: NestedExpanderPipeline end

"""
Similar to the [`ExampleBlocks`](@ref) expander, but hides all output in the final document.
"""
abstract type SetupBlocks <: NestedExpanderPipeline end

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

Selectors.matcher(::Type{TrackHeaders},   node, page, doc) = isa(node.element, MarkdownAST.Heading)
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

Selectors.runner(::Type{ExpanderPipeline}, node, page, doc) = nothing
Selectors.runner(::Type{NestedExpanderPipeline}, node, page, doc) = nothing

# Track Headers.
# --------------

function Selectors.runner(::Type{TrackHeaders}, node, page, doc)
    header = node.element
    # Get the header slug.
    text =
        if namedheader(node)
            # If the Header is wrappend in an [](@id) link, we remove the Link element from
            # the tree.
            link_node = first(node.children)
            MarkdownAST.unlink!(link_node)
            append!(node.children, link_node.children)
            match(NAMEDHEADER_REGEX, link_node.element.destination)[1]
        else
            # TODO: remove this hack (replace with mdflatten?)
            ast = MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.copy_tree(node)
            end
            md = convert(Markdown.MD, ast)
            sprint(Markdown.plain, Markdown.Paragraph(md.content[1].text))
        end
    slug = Documenter.slugify(text)
    # Add the header to the document's header map.
    anchor = Anchors.add!(doc.internal.headers, header, slug, page.build)
    # Create an AnchoredHeader node and push the
    ah = MarkdownAST.Node(Documenter.AnchoredHeader(anchor))
    anchor.node = ah
    MarkdownAST.insert_after!(node, ah)
    push!(ah.children, node)
end

# @meta
# -----

function Selectors.runner(::Type{MetaBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    meta = page.globals.meta
    lines = Documenter.find_block_in_file(x.code, page.source)
    @debug "Evaluating @meta block:\n$(x.code)"
    for (ex, str) in Documenter.parseblock(x.code, doc, page)
        if Documenter.isassign(ex)
            try
                meta[ex.args[1]] = Core.eval(Main, ex.args[2])
            catch err
                @docerror(doc, :meta_block,
                    """
                    failed to evaluate `$(strip(str))` in `@meta` block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = err)
            end
        end
    end
    node.element = MetaNode(x, copy(meta))
end

# @docs
# -----

function Selectors.runner(::Type{DocsBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    docsnodes = Node[]
    curmod = get(page.globals.meta, :CurrentModule, Main)
    lines = Documenter.find_block_in_file(x.code, page.source)
    @debug "Evaluating @docs block:\n$(x.code)"
    for (ex, str) in Documenter.parseblock(x.code, doc, page)
        admonition = first(Documenter.mdparse("""
        !!! warning "Missing docstring."

            Missing docstring for `$(strip(str))`. Check Documenter's build log for details.
        """, mode=:blocks))
        binding = try
            Documenter.DocSystem.binding(curmod, ex)
        catch err
            @docerror(doc, :docs_block,
                """
                unable to get the binding for '$(strip(str))' in `@docs` block in $(Documenter.locrepr(page.source, lines)) from expression '$(repr(ex))' in module $(curmod)
                ```$(x.info)
                $(x.code)
                ```
                """,
                exception = err)
            push!(docsnodes, admonition)
            continue
        end
        # Undefined `Bindings` get discarded.
        if !Documenter.DocSystem.iskeyword(binding) && !Documenter.DocSystem.defined(binding)
            @docerror(doc, :docs_block,
                """
                undefined binding '$(binding)' in `@docs` block in $(Documenter.locrepr(page.source, lines))
                ```$(x.info)
                $(x.code)
                ```
                """)
            push!(docsnodes, admonition)
            continue
        end
        typesig = Core.eval(curmod, Documenter.DocSystem.signature(ex, str))

        object = Documenter.Object(binding, typesig)
        # We can't include the same object more than once in a document.
        if haskey(doc.internal.objects, object)
            @docerror(doc, :docs_block,
                """
                duplicate docs found for '$(strip(str))' in `@docs` block in $(Documenter.locrepr(page.source, lines))
                ```$(x.info)
                $(x.code)
                ```
                """)
            push!(docsnodes, admonition)
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
                no docs found for '$(strip(str))' in `@docs` block in $(Documenter.locrepr(page.source, lines))
                ```$(x.info)
                $(x.code)
                ```
                """)
            push!(docsnodes, admonition)
            continue
        end

        # Concatenate found docstrings into a single `MD` object.
        docstr = map(Documenter.DocSystem.parsedoc, docs)
        docsnode = create_docsnode(docstr, docs, object, page, doc)

        # Track the order of insertion of objects per-binding.
        push!(get!(doc.internal.bindings, binding, Documenter.Object[]), object)

        doc.internal.objects[object] = docsnode.element
        push!(docsnodes, docsnode)
    end
    node.element = Documenter.DocsNodesBlock(x)
    for docsnode in docsnodes
        push!(node.children, docsnode)
    end
end

# @autodocs
# ---------

const AUTODOCS_DEFAULT_ORDER = [:module, :constant, :type, :function, :macro]

function Selectors.runner(::Type{AutoDocsBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    curmod = get(page.globals.meta, :CurrentModule, Main)
    fields = Dict{Symbol, Any}()
    lines = Documenter.find_block_in_file(x.code, page.source)
    @debug "Evaluating @autodocs block:\n$(x.code)"
    for (ex, str) in Documenter.parseblock(x.code, doc, page)
        if Documenter.isassign(ex)
            try
                if ex.args[1] == :Filter
                    fields[ex.args[1]] = Core.eval(Main, ex.args[2])
                else
                    fields[ex.args[1]] = Core.eval(curmod, ex.args[2])
                end
            catch err
                @docerror(doc, :autodocs_block,
                    """
                    failed to evaluate `$(strip(str))` in `@autodocs` block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
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
                    @autodocs ($(Documenter.locrepr(page.source, lines))) encountered a bad docstring binding '$(binding)'
                    ```$(x.info)
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
                            object = Documenter.Object(binding, typesig)
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
        modulemap = Documenter.precedence(modules)
        pagesmap = Documenter.precedence(pages)
        ordermap = Documenter.precedence(order)
        comparison = function (a, b)
            local t
            (t = Documenter._compare(modulemap, 1, a, b)) == 0 || return t < 0 # module
            (t = Documenter._compare(pagesmap,  2, a, b)) == 0 || return t < 0 # page
            (t = Documenter._compare(ordermap,  3, a, b)) == 0 || return t < 0 # category
            string(a[4]) < string(b[4])                                       # name
        end
        sort!(results; lt = comparison)

        # Finalise docstrings.
        docsnodes = Node[]
        for (mod, path, category, object, isexported, docstr) in results
            if haskey(doc.internal.objects, object)
                @docerror(doc, :autodocs_block,
                    """
                    duplicate docs found for '$(object.binding)' in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """)
                continue
            end
            markdown = Documenter.DocSystem.parsedoc(docstr)
            docsnode = create_docsnode([markdown], [docstr], object, page, doc)

            # Track the order of insertion of objects per-binding.
            push!(get!(doc.internal.bindings, object.binding, Documenter.Object[]), object)

            doc.internal.objects[object] = docsnode.element
            push!(docsnodes, docsnode)
        end
        node.element = Documenter.DocsNodesBlock(x)
        for docsnode in docsnodes
            push!(node.children, docsnode)
        end
    else
        @docerror(doc, :autodocs_block,
            """
            '@autodocs' missing 'Modules = ...' in $(Documenter.locrepr(page.source, lines))
            ```$(x.info)
            $(x.code)
            ```
            """)
    end
end

# @eval
# -----

function Selectors.runner(::Type{EvalBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @eval block in draft mode:\n$(x.code)"
        create_draft_result!(node; blocktype="@eval")
        return
    end
    sandbox = Module(:EvalBlockSandbox)
    lines = Documenter.find_block_in_file(x.code, page.source)
    linenumbernode = LineNumberNode(lines === nothing ? 0 : lines.first,
                                    basename(page.source))
    @debug "Evaluating @eval block:\n$(x.code)"
    cd(page.workdir) do
        result = nothing
        for (ex, str) in Documenter.parseblock(x.code, doc, page; keywords = false,
                                              linenumbernode = linenumbernode)
            try
                result = Core.eval(sandbox, ex)
            catch err
                bt = Documenter.remove_common_backtrace(catch_backtrace())
                @docerror(doc, :eval_block,
                    """
                    failed to evaluate `@eval` block in $(Documenter.locrepr(page.source))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = (err, bt))
            end
        end
        result = if isnothing(result)
            nothing
        elseif isa(result, Markdown.MD)
            convert(Node, result)
        else
            # TODO: we could handle the cases where the user provides some of the Markdown library
            # objects, like Paragraph.
            @warn """
            Invalid type of object in @eval in $(Documenter.locrepr(page.source))
            ```$(x.info)
            $(x.code)
            ```
            Evaluate to `$(typeof(result))`, should be one of
             - Nothing
             - Markdown.MD
            Falling back to code block representation.

            If you are seeing this warning after upgrading Documenter and this used to work,
            please open an issue on the Documenter issue tracker.
            """
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.CodeBlock("", sprint(show, MIME"text/plain"(), result))
            end
        end
        # TODO: make result a child node
        node.element = EvalNode(x, result)
    end
end

# @index
# ------

function Selectors.runner(::Type{IndexBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    indexnode = Documenter.buildnode(Documenter.IndexNode, x, doc, page)
    push!(doc.internal.indexnodes, indexnode)
    node.element = indexnode
end

# @contents
# ---------

function Selectors.runner(::Type{ContentsBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    contentsnode = Documenter.buildnode(Documenter.ContentsNode, x, doc, page)
    push!(doc.internal.contentsnodes, contentsnode)
    node.element = contentsnode
end

# @example
# --------

# Find if there is any format with color output
function _any_color_fmt(doc)
    idx = findfirst(x -> x isa Documenter.HTML, doc.user.format)
    idx === nothing && return false
    return doc.user.format[idx].ansicolor
end

function Selectors.runner(::Type{ExampleBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    matched = match(r"^@example(?:\s+([^\s;]+))?\s*(;.*)?$", x.info)
    matched === nothing && error("invalid '@example' syntax: $(x.info)")
    name, kwargs = matched.captures

    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @example block in draft mode:\n$(x.code)"
        create_draft_result!(node; blocktype="@example")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Documenter.get_sandbox_module!(page.globals.meta, "atexample", name)
    sym = nameof(mod)
    lines = Documenter.find_block_in_file(x.code, page.source)

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
        for (ex, str) in Documenter.parseblock(code, doc, page; keywords = false,
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
                bt = Documenter.remove_common_backtrace(c.backtrace)
                @docerror(doc, :example_block,
                    """
                    failed to run `@example` block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = (c.value, bt))
                page.mapping[x] = x
                return
            end
        end
    else # store the continued code
        CC = get!(page.globals.meta, :ContinuedCode, Dict())
        CC[sym] = get(CC, sym, "") * '\n' * x.code
    end
    # Splice the input and output into the document.
    content = Node[]
    input   = droplines(x.code)

    # Generate different  in different formats and let each writer select
    output = Base.invokelatest(Documenter.display_dict, result, context = :color => ansicolor)
    # Remove references to gensym'd module from text/plain
    m = MIME"text/plain"()
    if haskey(output, m)
        output[m] = remove_sandbox_from_output(output[m], mod)
    end

    # Only add content when there's actually something to add.
    isempty(input) || push!(content, Node(MarkdownAST.CodeBlock("julia", input)))
    if result === nothing
        stdouterr = Documenter.DocTests.sanitise(buffer)
        stdouterr = remove_sandbox_from_output(stdouterr, mod)
        isempty(stdouterr) || push!(content, Node(Documenter.MultiOutputElement(Dict{MIME,Any}(MIME"text/plain"() => stdouterr))))
    elseif !isempty(output)
        push!(content, Node(Documenter.MultiOutputElement(output)))
    end
    # ... and finally map the original code block to the newly generated ones.
    node.element = Documenter.MultiOutput(x)
    append!(node.children, content)
end

# Replace references to gensym'd module with Main
function remove_sandbox_from_output(str, mod::Module)
    replace(str, Regex(("(Main\\.)?$(nameof(mod))")) => "Main")
end

# @repl
# -----

function Selectors.runner(::Type{REPLBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    matched = match(r"^@repl(?:\s+([^\s;]+))?\s*(;.*)?$", x.info)
    matched === nothing && error("invalid '@repl' syntax: $(x.info)")
    name, kwargs = matched.captures

    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @repl block in draft mode:\n$(x.code)"
        create_draft_result!(node; blocktype="@repl")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Documenter.get_sandbox_module!(page.globals.meta, "atexample", name)

    # "parse" keyword arguments to repl
    ansicolor = _any_color_fmt(doc)
    if kwargs !== nothing
        matched = match(r"\bansicolor\s*=\s*(true|false)\b", kwargs)
        if matched !== nothing
            ansicolor = matched[1] == "true"
        end
    end

    multicodeblock = MarkdownAST.CodeBlock[]
    linenumbernode = LineNumberNode(0, "REPL") # line unused, set to 0
    @debug "Evaluating @repl block:\n$(x.code)"
    for (ex, str) in Documenter.parseblock(x.code, doc, page; keywords = false,
                                          linenumbernode = linenumbernode)
        input  = droplines(str)
        # Use the REPL softscope for REPLBlocks,
        # see https://github.com/JuliaLang/julia/pull/33864
        ex = REPL.softscope(ex)
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
            push!(multicodeblock, MarkdownAST.CodeBlock("julia-repl", prepend_prompt(input)))
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
        push!(multicodeblock, MarkdownAST.CodeBlock("documenter-ansi", rstrip(outstr)))
    end
    node.element = Documenter.MultiCodeBlock(x, "julia-repl", [])
    for element in multicodeblock
        push!(node.children, Node(element))
    end
end

# @setup
# ------

function Selectors.runner(::Type{SetupBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    matched = match(r"^@setup(?:\s+([^\s;]+))?\s*$", x.info)
    matched === nothing && error("invalid '@setup <name>' syntax: $(x.info)")
    name = matched[1]

    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @setup block in draft mode:\n$(x.code)"
        create_draft_result!(node; blocktype="@setup")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Documenter.get_sandbox_module!(page.globals.meta, "atexample", name)

    @debug "Evaluating @setup block:\n$(x.code)"
    # Evaluate whole @setup block at once instead of piecewise
    try
        cd(page.workdir) do
            include_string(mod, x.code)
        end
    catch err
        bt = Documenter.remove_common_backtrace(catch_backtrace())
        @docerror(doc, :setup_block,
            """
            failed to run `@setup` block in $(Documenter.locrepr(page.source))
            ```$(x.info)
            $(x.code)
            ```
            """, exception=(err, bt))
    end
    node.element = Documenter.SetupNode(x.info, x.code)
end

# @raw
# ----

function Selectors.runner(::Type{RawBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    m = match(r"@raw[ ](.+)$", x.info)
    m === nothing && error("invalid '@raw <name>' syntax: $(x.info)")
    node.element = Documenter.RawNode(Symbol(m[1]), x.code)
end

# Documenter.
# ----------

iscode(node::Node, lang) = iscode(node.element, lang)
iscode(x::MarkdownAST.CodeBlock, r::Regex) = occursin(r, x.info)
iscode(x::MarkdownAST.CodeBlock, lang) = x.info == lang
iscode(x, lang) = false

const NAMEDHEADER_REGEX = r"^@id (.+)$"

function namedheader(node::Node)
    @assert node.element isa MarkdownAST.Heading
    if length(node.children) == 1 && first(node.children).element isa MarkdownAST.Link
        url = first(node.children).element.destination
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

function create_docsnode(docstrings, results, object, page, doc)
    # Generate a unique name to be used in anchors and links for the docstring.
    slug = Documenter.slugify(object)
    anchor = Anchors.add!(doc.internal.docs, object, slug, page.build)
    docsnode = DocsNode(anchor, object, page)
    # Convert docstring to MarkdownAST, convert Heading elements, and push to DocsNode
    for (markdown, result) in zip(docstrings, results)
        # parsedoc() does this double MD wrapping..
        ast = convert(Node, markdown.content[1])
        doc.user.highlightsig && highlightsig!(ast)
        # The following 'for' corresponds to the old dropheaders() function
        for headingnode in ast.children
            headingnode.element isa MarkdownAST.Heading || continue
            boldnode = Node(MarkdownAST.Strong())
            for textnode in collect(headingnode.children)
                push!(boldnode.children, textnode)
            end
            headingnode.element = MarkdownAST.Paragraph()
            push!(headingnode.children, boldnode)
        end
        push!(docsnode.mdasts, ast)
        push!(docsnode.results, result)
        push!(docsnode.metas, markdown.meta)
    end
    return Node(docsnode)
end

function highlightsig!(node::Node)
    @assert node.element isa MarkdownAST.Document
    MarkdownAST.haschildren(node) || return
    node = first(node.children)
    if node.element isa MarkdownAST.CodeBlock && isempty(node.element.info)
        node.element.info = "julia"
    end
end

end
