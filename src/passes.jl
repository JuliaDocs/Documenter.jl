
# handlers

function process!(doc::Document)
    for pass in doc.passes
        process!(doc, pass)
    end
end

function process!(doc, pass)
    for page in doc.pages
        # Start each page with a fresh environment.
        empty!(page.env)
        # The new content vector for this page.
        content = []
        for block in page.content
            for action in pass
                # When an `action` succeeds, ie. returns `true`, we stop trying new actions
                # from this `pass` on the current `block` and move on to the next `block`.
                # If the `action` returns `false` then we try the next `action` in the given
                # pass until we exhaust them all, then move onto the next block.
                process!(action, page, content, block) && break
            end
        end
        # doc is immutable, hence:
        empty!(page.content)
        append!(page.content, content)
    end
    doc
end

# basics

abstract AbstractAction

process!(::AbstractAction, ::Page, content, block) = false

immutable DefaultAction <: AbstractAction end

process!(::DefaultAction, ::Page, content, block) = (push!(content, block); true)


## pass 1, actions that are independant of others, ie. don't need data from previous passes.

immutable CleanBuildDirectory <: AbstractAction end
immutable MetadataBlock       <: AbstractAction end
immutable DocstringBlock      <: AbstractAction end
immutable SlugifyHeader       <: AbstractAction end

const PassOne = (
    CleanBuildDirectory(),
    MetadataBlock(),
    DocstringBlock(),
    SlugifyHeader(),
    DefaultAction(),
)


## pass 2, actions that need data about other nodes in the doc.

immutable MetadataNode         <: AbstractAction end
immutable TableOfContentsBlock <: AbstractAction end
immutable DocstringIndexBlock  <: AbstractAction end
immutable UpdateLinkURLs       <: AbstractAction end
immutable DocChecks            <: AbstractAction end

const PassTwo = (
    MetadataNode(),
    TableOfContentsBlock(),
    DocstringIndexBlock(),
    UpdateLinkURLs(),
    DocChecks(),
    DefaultAction(),
)


## pass 3, builddir setup, rendering docs.

immutable SetupBuildDirectory <: AbstractAction end
immutable Render             <: AbstractAction end

const PassThree = (
    SetupBuildDirectory(),
    Render(),
    DefaultAction(),
)


# procs

## remove old files from the build directory

function process!(::CleanBuildDirectory, page::Page, content, block)
    if page.root.clean
        dir = dirname(page.build)
        isdir(dir) && rm(dir, recursive = true)
    end
    false
end

## metadata code blocks and nodes

function process!(::MetadataBlock, page::Page, content, block::Markdown.Code)
    startswith(block.code, "{meta}") || return false # Try next processor.
    meta = Metadata(page)
    for (ex, str) in parseblock(block.code, skip = 1)
        if isexpr(ex, :(=), 2) && isa(ex.args[1], Symbol)
            name = ex.args[1]
            page.env[name] = meta.env[name] = eval(current_module(), ex.args[2])
        end
    end
    push!(content, meta)
    true # Move on to next block.
end

function process!(::MetadataNode, page::Page, content, block::Metadata)
    merge!(page.env, block.env)
    push!(content, block)
    true # Move on to next block.
end

## docstring code blocks

function process!(::DocstringBlock, page::Page, content, block::Markdown.Code)
    startswith(block.code, "{docs}") || return false # Try next processor.
    for (ex, str) in parseblock(block.code, skip = 1)
        # Find the documentation for the given expression `ex`.
        mod = get(page.env, :CurrentModule, current_module())
        doc = eval(mod, :(@doc $ex))
        obj = eval(mod, :($(Lapidary).@object $ex))
        # Error when no documentation is found.
        nodocs(doc) && error("no docs found for `$str` in `$(page.src)`.")
        # Register the found documentation with the document root.
        root = page.root
        haskey(root.docs, obj) && error("duplicate docs for `$str` in `$(page.src)`.")
        anchor = Anchor(obj, page)
        root.docs[obj] = (page, anchor)
        # Add anchor infront of docstring and push both into content vector.
        push!(content, anchor, DocStr(obj, doc, page))
    end
    true # Move on to next block.
end

## slugify headers

function process!(::SlugifyHeader, page::Page, content, block::Markdown.Header)
    anchor = Anchor(strip(replace(sprint(Markdown.plain, block), "#", "")), page)
    push!(page.headers, (anchor, block))
    push!(content, anchor, block)
    true # Move on the next block.
end

## table of contents block

function process!(::TableOfContentsBlock, page::Page, content, block::Markdown.Code)
    startswith(block.code, "{contents}") || return false # Try next processor.
    # Which level of header should we show until in the table of contents?
    depth = get(page.env, :ContentsDepth, 1)
    # In which order should the pages be displayed in in the table of contents?
    pages = getpages(page, :ContentsPages)
    # Once the `Page` objects are in the correct order for TOC we then build TOC itself.
    # A TOC is generated lazily when we actually render the final document. Just use a wrapper
    # to store it until then.
    push!(content, TableOfContents(pages, depth))
    true # Move on to the next block.
end

## docstring index block

function process!(::DocstringIndexBlock, page::Page, content, block::Markdown.Code)
    startswith(block.code, "{index}") || return false # Try next processor.
    # Which modules should be included in the docstring index? Empty vector is any module.
    modules = get(page.env, :IndexModules, Module[])
    # Which pages should be included?
    pages = getpages(page, :IndexPages)
    # As with the `TableOfContents` the `DocstringIndex` is lazy and only generated when
    # rendering it later on. We just store a wrapper type for now.
    push!(content, DocstringIndex(pages, modules))
    true # Move on to the next block.
end

## update link urls

function process!(::UpdateLinkURLs, page::Page, content, block)
    # walks over the entire block. Stopping at Links to update references.
    walk(page, block) do link
        isa(link, Markdown.Link) || return true
        if link.url == "{ref}"
            link.url = ""
            if isa(link.text[1], Markdown.Code)
                # Referencing a docstring.
                code = link.text[1].code
                docs = page.root.docs
                # Get the object referenced by the link.
                mod = get(page.env, :CurrentModule, current_module())
                obj = eval(mod, :($(Lapidary).@object($(parse(code)))))
                # Find it's source location somewhere in the document.
                haskey(docs, obj) || error("no doc for reference `$code` in `$(page.src)`.")
                sourcepage, anchor = docs[obj]
                link.url = build_relpath(sourcepage.build, page.build, anchor.name)
            elseif isa(link.text, Vector) && length(link.text) == 1
                # Referencing a header.
                # TODO: handling of multiple headers with the same name?
                text = slugify(link.text[1])
                # For the moment we just take the first one.
                sourcepage = page
                for p in page.root.pages
                    if haskey(p.slugs, text)
                        sourcepage = p
                        n = p.slugs[text]
                        n > 1 && error("$n headers in `$(p.src)` with same name `$text`.")
                        break
                    end
                end
                link.url = build_relpath(sourcepage.build, page.build, string(text, "-1"))
            end
        end
        false
    end
    false
end

## run doctests on codeblocks

function process!(::DocChecks, page::Page, content, block)
    walk(page, block) do source
        isa(source, Markdown.Code) || return true
        doctest(source)
        false
    end
    false
end

## rendering
##
## TODO: (this is only a mock up and the moment)
##  - handle different formats. Currently only a basic markdown output. Should add HTML and
##    LaTeX as well.
##  - user-defined templates to apply to each page?
##  - fixup/standarise the markup for each node type.

function process!(::SetupBuildDirectory, page::Page, content, block)
    dir = dirname(page.build)
    isdir(dir) || mkpath(dir)
    false
end

function process!(::Render, page::Page, content, block::StaticFile)
    cp(page.src, page.build, remove_destination = true)
    true
end

function process!(::Render, page::Page, content, block::DocStr)
    open(page.build, "a") do output
        category = doccategory(block.object)
        _, anchor = page.root.docs[block.object]
        print(output, "\n<a href='#$(anchor.name)'> # </a>")
        println(output, "**", category, "**", "\n")
        Markdown.plain(output, block.content)
        println(output, "<hr></hr>")
    end
    false
end

function process!(::Render, page::Page, content, block::Metadata)
    merge!(page.env, block.env)
    true
end

function process!(::Render, page::Page, content, block::Anchor)
    open(page.build, "a") do output
        println(output, "<a id='$(block.name)'></a>")
    end
    false
end

function process!(::Render, page::Page, content, block::TableOfContents)
    open(page.build, "a") do output
        for p in block.pages, h in p.headers
            anchor, header = h
            n = header_level(header)
            if n ≤ block.depth
                print(output, "    "^(n - 1), "- ")
                url = build_relpath(anchor.page.build, page.build, anchor.name)
                link = Markdown.Link(header.text, url)
                Markdown.plaininline(output, link)
                println(output)
            end
        end
    end
    false
end

function process!(::Render, page::Page, content, block::DocstringIndex)
    open(page.build, "a") do output
        for doc in page.root.docs
            object, (p, anchor) = doc
            if isempty(block.modules) || object.mod ∈ block.modules
                url = build_relpath(anchor.page.build, page.build, anchor.name)
                link = Markdown.Link(Markdown.Code(string(object)), url)
                println(output, "- ")
                Markdown.plaininline(output, link)
                println(output)
            end
        end
    end
    false
end

# The rest of the block types *should* be markdown.
function process!(::Render, page::Page, content, block)
    open(page.build, "a") do output
        println(output)
        Markdown.plain(output, block)
        println(output)
    end
    false
end
