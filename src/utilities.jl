
function paths(root, obj, src, build)
    obj = joinpath(root, obj)
    out = joinpath(build, relpath(obj, src))
    obj, out
end

parsefile(file) = Markdown.parse(readall(file)).content

# Normalise docstring query expression to a canonical object.
macro object(x)
    haskey(Docs.keywords, x) ? quot(x) :
    isexpr(x, :call)         ? findmethod(x) :
    Docs.isvar(x)            ? :(Docs.@var($(esc(x)))) :
    esc(x)
end
findmethod(x) = Expr(:tuple, esc(Docs.namify(x)), esc(Docs.signature(x)))

function parseblock(code; skip = 0)
    code = last(split(code, '\n', limit = skip + 1))
    results, cursor = [], 1
    while cursor < length(code)
        ex, ncursor = parse(code, cursor)
        push!(results, (ex, code[cursor:ncursor-1]))
        cursor = ncursor
    end
    results
end

function slugify(s)
    # s = strip(lowercase(s))
    # s = replace(s, r"\s+", "-")
    # s = replace(s, r"&", "-and-")
    # s = replace(s, r"[^\w\-]+", "")
    # s = strip(replace(s, r"\-\-+", "-"), '-')
    URIParser.escape(s)
end

nodocs(md) = startswith(sprint(Markdown.plain, md), "No documentation found.")

function getpages(page, key)
    if haskey(page.env, key)
        pages = []
        for path in page.env[key]
            haskey(page.root.pagemap, path) || error("file `$path` not found.")
            push!(pages, page.root.pagemap[path])
        end
        pages
    else
        sort(page.root.pages, by = p -> p.src)
    end
end

build_relpath(target, source, slug) = string(relpath(target, dirname(source)), "#", slug)

function doctest(source::Markdown.Code)
    if source.language == "julia"
        sandbox = Module()
        if ismatch(r"^julia> "m, source.code) # test is a REPL-type.
            parts = split(source.code, "\njulia> ")
            for part in parts
                # each part should be a single complete expression followed by a result,
                # which may not be complete, or actually valid julia code at all.
                part   = replace(part, "julia> ", "", 1)
                cursor = 1
                expr, ncursor = parse(part, cursor)
                result, backtrace = nothing, nothing
                try
                    result = eval(sandbox, expr)
                    eval(sandbox, :(ans = $(result)))
                catch err
                    result, backtrace = err, catch_backtrace()
                end
                result_text = strip(part[ncursor:end], '\n')
                show_result = !endswith(strip(part[cursor:ncursor-1]), ";")
                # Print out the calculated values and backtrace.
                buf = IOBuffer()
                print_response(buf, result, backtrace, show_result)
                @assert startswith(takebuf_string(buf), result_text)
            end
        elseif ismatch(r"^# output:$"m, source.code) # test is a script-type code block.
            parts = split(source.code, "\n# output:\n", limit = 2)
            @assert length(parts) == 2
            code, result_text = parts
            result, backtrace = nothing, nothing
            try
                for (ex, str) in parseblock(code)
                    result = eval(sandbox, ex)
                end
            catch err
                result, backtrace = err, catch_backtrace()
            end
            result_text = strip(result_text, '\n')
            buf = IOBuffer()
            print_response(buf, result, backtrace, true)
            @assert startswith(takebuf_string(buf), result_text)
        end
    end
end
function print_response(buf, result, backtrace, show_result)
    if backtrace ≡ nothing
        if result ≢ nothing && show_result
            show(buf, result)
        end
    else
        print(buf, "    {throws ", typeof(result), "}")
    end
end

doccategory(x::Docs.Binding)           = doccategory(getfield(x.mod, x.var))
doccategory(x::Tuple{Function, Tuple}) = "Method"
doccategory(x::Function)               = "Function"
doccategory(x::DataType)               = "Type"
doccategory(other)                     = "Constant"

header_level{N}(::Markdown.Header{N}) = N
