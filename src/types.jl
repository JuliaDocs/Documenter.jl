
typealias Str UTF8String

immutable StaticFile end

immutable Page
    root     :: Any               # Document root.
    content  :: Vector            # An empty vector for non-markdown files.
    src      :: Str               # Source file.
    build    :: Str               # Destination file.
    markdown :: Bool              # Is the file a static or markdown file?
    env      :: Dict{Symbol, Any} # Page's environment: current module, etc.
    slugs    :: Dict{Str, Int}    # Uniquifier for slugs on a page.
    headers  :: Vector            # Headers (levels 1 - 6) from a page, in order. With anchors.

    function Page(root, src, build, fmt)
        path, ext = splitext(build)
        markdown  = ext == ".md"
        build, content = markdown ? (string(path, fmt), parsefile(src)) : (build, [StaticFile()])
        new(root, content, src, build, markdown, Dict(), Dict(), [])
    end
end

immutable Document
    src     :: Str             # Source file.
    build   :: Str             # Destination file.
    clean   :: Bool            # Should the build directory be cleared out before a build.
    passes  :: Vector          # A pipeline of transformations to be applied to the doc.
    pagemap :: Dict{Str, Page} # Mapping from source file name to page object.
    pages   :: Vector{Page}    # All pages in source folder.
    docs    :: ObjectIdDict    # Stores references to all docstrings in document.

    function Document(src, build, format, clean, passes)
        isdir(src) || error("cannot find `src` directory `$src` in the docs directory.")
        doc = new(src, build, clean, passes, Dict(), [], ObjectIdDict())
        for (root, dirs, files) in walkdir(src)
            for file in files
                obj, out  = paths(root, file, src, build)
                page = Page(doc, obj, out, format)
                push!(doc.pages, page)
                doc.pagemap[obj] = page
            end
        end
        doc
    end
end

immutable DocStr
    object  :: Any
    content :: Markdown.MD
    page    :: Page
end

immutable Metadata
    env  :: Dict{Symbol, Any}
    page :: Page

    Metadata(page::Page) = new(Dict(), page)
end

immutable Anchor
    name :: Str
    page :: Page

    function Anchor(name, page)
        s = slugify(string(name))
        n = haskey(page.slugs, s) ? (page.slugs[s] += 1) : (page.slugs[s] = 1)
        new(string(s, "-", n), page)
    end
end

immutable TableOfContents
    pages :: Vector{Page}
    depth :: Int
end

immutable DocstringIndex
    pages   :: Vector{Page}
    modules :: Vector{Module}
end
