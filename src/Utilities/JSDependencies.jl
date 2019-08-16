"""
Provides an API to programmatically construct a [RequireJS](https://requirejs.org/) script.
"""
module JSDependencies
using JSON

"""
    struct RemoteLibrary

Declares a remote JS dependency that should be declared in the RequireJS configuration shim.

# Fields

* `name`: a unique name for the dependency, used to refer to it in other dependencies and
  snippets
* `url`: full remote URL from where the dependency can be loaded from
* `deps`: a list of the library's dependencies (becomes the `deps` configuration in the
  RequireJS shim)
* `exports`: sets the `exports` config in the resulting RequireJS shim

# Constructors

```julia
RemoteLibrary(name::AbstractString, url::AbstractString; deps=String[], exports=nothing)
```
"""
struct RemoteLibrary
    name :: String
    url :: String
    # The following become part of the shim
    deps :: Vector{String}
    exports :: Union{Nothing, String}

    function RemoteLibrary(name::AbstractString, url::AbstractString; deps=String[], exports=nothing)
        new(name, url, deps, exports)
    end
end

"""
    struct Snippet

Declares a JS code snipped that should be loaded with RequireJS. This gets wrapped in
`require([deps...], function(args...) {script...})` in the output.

# Fields

* `deps`: names of the [`RemoteLibrary`](@ref) dependencies of the snippet
* `args`: the arguments of the callback function, corresponding to the library objects
  of the dependencies, in the order of `deps`
* `js`: the JS code of the function that gets used as the function body of the callback

# Constructors

```julia
Snippet(deps::AbstractVector, args::AbstractVector, js::AbstractString)
```
"""
struct Snippet
    deps :: Vector{String}
    args :: Vector{String}
    js :: String

    function Snippet(deps::AbstractVector, args::AbstractVector, js::AbstractString)
        new(deps, args, js)
    end
end

"""
    struct RequireJS

Declares a single RequireJS configuration/app file.

# Fields

* `libraries`: a dictionary of [`RemoteLibrary`](@ref) declarations (keys are the library
  names)
* `snippets`: a list of JS snippets ([`Snippet`](@ref))

# Constructors

```julia
RequireJS(libraries::AbstractVector{RemoteLibrary}, snippets::AbstractVector{Snippet} = Snippet[])
```

# API

* The `push!` function can be used to add additional libraries and snippets.
*
"""
struct RequireJS
    libraries :: Dict{String, RemoteLibrary}
    snippets :: Vector{Snippet}

    function RequireJS(libraries::AbstractVector, snippets::AbstractVector = Snippet[])
        all(x -> isa(x, RemoteLibrary), libraries) || throw(ArgumentError("Bad element types for `libraries`: $(typeof.(libraries))"))
        all(x -> isa(x, Snippet), snippets) || throw(ArgumentError("Bad element types for `snippets`: $(typeof.(snippets))"))
        r = new(Dict(), [])
        for library in libraries
            push!(r, library)
        end
        for snippet in snippets
            push!(r, snippet)
        end
        return r
    end
end

function Base.push!(r::RequireJS, lib::RemoteLibrary)
    if lib.name in keys(r.libraries)
        error("Library already added.")
    end
    r.libraries[lib.name] = lib
end

Base.push!(r::RequireJS, s::Snippet) = push!(r.snippets, s)

"""
    verify(r::RequireJS; verbose=false) -> Bool

Checks that none of the dependencies are missing (returns `false` if some are). If `verbose`
is set to `true`, it will also log an error with the missing dependency.
"""
function verify(r::RequireJS; verbose=false)
    isvalid = true
    for (name, lib) in r.libraries
        for dep in lib.deps
            if !(dep in keys(r.libraries))
                verbose && @error("$(dep) of $(name) missing from libraries")
                isvalid = false
            end
        end
    end
    for s in r.snippets
        for dep in s.deps
            if !(dep in keys(r.libraries))
                verbose && @error("$(dep) missing from libraries")
                isvalid = false
            end
        end
    end
    return isvalid
end

"""
    writejs(io::IO, r::RequireJS)
    writejs(filename::AbstractString, r::RequireJS)

Writes out the [`RequireJS`](@ref) object as a valid JS that can be loaded with a `<script>`
tag, either into a stream or a file. It will contain all the configuration and snippets.
"""
function writejs end

function writejs(filename::AbstractString, r::RequireJS)
    open(filename, "w") do io
        writejs(io, r)
    end
end

function writejs(io::IO, r::RequireJS)
    write(io, """
    // Generated by Documenter.jl
    requirejs.config({
      paths: {
    """)
    for (name, lib) in r.libraries
        url = endswith(lib.url, ".js") ? replace(lib.url, r"\.js$" => "") : lib.url
        write(io, """
            '$(lib.name)': '$(url)',
        """) # FIXME: escape bad characters
    end
    write(io, """
      },
    """)
    shim = shimdict(r)
    if !isempty(shim)
        write(io, "  shim: ")
        JSON.print(io, shim, 2) # FIXME: escape JS properly
        write(io, ",\n")
    end
    write(io, """
    });
    """)

    for s in r.snippets
        args = join(s.args, ", ") # FIXME: escapes
        deps = join(("\'$(d)\'" for d in s.deps), ", ") # FIXME: escapes
        write(io, """
        $("/"^80)
        require([$(deps)], function($(args)) {
        $(s.js)
        })
        """)
    end
end

function shimdict(r::RequireJS)
    shim = Dict{String,Any}()
    for (name, lib) in r.libraries
        @assert name == lib.name
        libshim = shimdict(lib)
        if libshim !== nothing
            shim[name] = libshim
        end
    end
    return shim
end

function shimdict(lib::RemoteLibrary)
    isempty(lib.deps) && (lib.exports === nothing) && return nothing
    shim = Dict{Symbol,Any}()
    if !isempty(lib.deps)
        shim[:deps] = lib.deps
    end
    if lib.exports !== nothing
        shim[:exports] = lib.exports
    end
    return shim
end

"""
    parse_snippet(filename::AbstractString) -> Snippet
    parse_snippet(io::IO) -> Snippet

Parses a JS snippet file into a [`Snippet`](@ref) object.

# Format

The first few lines are parsed to get the dependencies and argument variable names of the
snippet. They need to match `^//\\s*([a-z]+):` (i.e. start with `//`, optional whitespace, a
lowercase identifier, and a colon). Once the parser hits a line that does not match that
pattern, it will assume that it and all the following lines are the actual script.

Only lowercase letters are allowed in the identifiers. Currently only `libraries` and
`arguments` are actually parsed and lines with other syntactically valid identifiers are
ignored. For `libraries` and `arguments`, the value (after the colon) must be a comma
separated list.

A valid snippet file would look like the following. Note that the list of arguments can be
shorter than the list of dependencies.

```js
// libraries: jquery, highlight, highlight-julia, highlight-julia-repl
// arguments: \$, hljs

// Initialize the highlight.js highlighter
\$(document).ready(function() {
  hljs.initHighlighting();
})
```
"""
function parse_snippet end

parse_snippet(filename::AbstractString; kwargs...) = open(filename, "r") do io
    parse_snippet(io; kwargs...)
end

function parse_snippet(io::IO)
    libraries = String[]
    arguments = String[]
    lineno = 1
    while true
        pos = position(io)
        line = readline(io)
        m = match(r"^//\s*([a-z]+):(.*)$", line)
        if m === nothing
            seek(io, pos) # undo the last readline() call
            break
        end
        if m[1] == "libraries"
            libraries = strip.(split(m[2], ","))
            if any(s -> match(r"^[a-z-_]+$", s) === nothing, libraries)
                error("Unable to parse a library declaration '$(line)' on line $(lineno)")
            end
        elseif m[1] == "arguments"
            arguments = strip.(split(m[2], ","))
        end
        lineno += 1
    end
    snippet = String(read(io))
    Snippet(libraries, arguments, snippet)
end

"""
Replaces some of the characters in the string with escape sequences so that the strings
would be valid JS string literals, as per the
[ECMAScript® 2017 standard](https://www.ecma-international.org/ecma-262/8.0/index.html#sec-literals-string-literals).
Note that it always escapes both potential `"` and `'` closing quotes.
"""
function jsescape(s)
    b = IOBuffer()
    # From the ECMAScript® 2017 standard:
    #
    # > All code points may appear literally in a string literal except for the closing
    # > quote code points, U+005C (REVERSE SOLIDUS), U+000D (CARRIAGE RETURN), U+2028 (LINE
    # > SEPARATOR), U+2029 (PARAGRAPH SEPARATOR), and U+000A (LINE FEED).
    #
    # https://www.ecma-international.org/ecma-262/8.0/index.html#sec-literals-string-literals
    #
    # Note: in ECMAScript® 2019 (10th edition), U+2028 and U+2029 do not actually need to be
    # escaped anymore:
    #
    # > Updated syntax includes optional catch binding parameters and allowing U+2028 (LINE
    # > SEPARATOR) and U+2029 (PARAGRAPH SEPARATOR) in string literals to align with JSON.
    #
    # https://www.ecma-international.org/ecma-262/10.0/index.html#sec-intro
    #
    # But we'll  keep these escapes around for now, as not all JS parsers may be compatible
    # with the latest standard yet.
    for c in s
        if c === '\u000a'     # LINE FEED,       i.e. \n
            write(b, "\\n")
        elseif c === '\u000d' # CARRIAGE RETURN, i.e. \r
            write(b, "\\r")
        elseif c === '\u005c' # REVERSE SOLIDUS, i.e. \
            write(b, "\\\\")
        elseif c === '\u0022' # QUOTATION MARK,  i.e. "
            write(b, "\\\"")
        elseif c === '\u0027' # APOSTROPHE,      i.e. '
            write(b, "\\'")
        elseif c === '\u2028' # LINE SEPARATOR
            write(b, "\\u2028")
        elseif c === '\u2029' # PARAGRAPH SEPARATOR
            write(b, "\\u2029")
        else
            write(b, c)
        end
    end
    String(take!(b))
end

end
