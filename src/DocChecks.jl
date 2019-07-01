"""
Provides the [`missingdocs`](@ref), [`footnotes`](@ref) and [`linkcheck`](@ref) functions
for checking docs.
"""
module DocChecks

import ..Documenter:
    Documenter,
    Documents,
    Utilities,
    Utilities.Markdown2

using DocStringExtensions
import Markdown

# Missing docstrings.
# -------------------

"""
$(SIGNATURES)

Checks that a [`Documents.Document`](@ref) contains all available docstrings that are
defined in the `modules` keyword passed to [`Documenter.makedocs`](@ref).

Prints out the name of each object that has not had its docs spliced into the document.
"""
function missingdocs(doc::Documents.Document)
    doc.user.checkdocs === :none && return
    @debug "checking for missing docstrings."
    bindings = allbindings(doc.user.checkdocs, doc.blueprint.modules)
    for object in keys(doc.internal.objects)
        # The module references in docs blocks can yield a binding like
        # Docs.Binding(Mod, :SubMod) for a module SubMod, a submodule of Mod. However, the
        # module bindings that come from Docs.meta() always appear to be of the form
        # Docs.Binding(Mod.SubMod, :SubMod) (since Julia 0.7). We therefore "normalize"
        # module bindings before we search in the list returned by allbindings().
        binding = if Documenter.DocSystem.defined(object.binding) && !Documenter.DocSystem.iskeyword(object.binding)
            m = Documenter.DocSystem.resolve(object.binding)
            isa(m, Module) && nameof(object.binding.mod) != object.binding.var ?
                Docs.Binding(m, nameof(m)) : object.binding
        else
            object.binding
        end
        if haskey(bindings, binding)
            signatures = bindings[binding]
            if object.signature ≡ Union{} || length(signatures) ≡ 1
                delete!(bindings, binding)
            elseif object.signature in signatures
                delete!(signatures, object.signature)
            end
        end
    end
    n = reduce(+, map(length, values(bindings)), init=0)
    if n > 0
        b = IOBuffer()
        println(b, "$n docstring$(n ≡ 1 ? "" : "s") potentially missing:\n")
        for (binding, signatures) in bindings
            for sig in signatures
                println(b, "    $binding", sig ≡ Union{} ? "" : " :: $sig")
            end
        end
        push!(doc.internal.errors, :missing_docs)
        @warn String(take!(b))
    end
end

function allbindings(checkdocs::Symbol, mods)
    out = Dict{Utilities.Binding, Set{Type}}()
    for m in mods
        allbindings(checkdocs, m, out)
    end
    out
end

function allbindings(checkdocs::Symbol, mod::Module, out = Dict{Utilities.Binding, Set{Type}}())
    for (obj, doc) in meta(mod)
        isa(obj, IdDict{Any,Any}) && continue
        name = nameof(obj)
        isexported = Base.isexported(mod, name)
        if checkdocs === :all || (isexported && checkdocs === :exports)
            out[Utilities.Binding(mod, name)] = Set(sigs(doc))
        end
    end
    out
end

meta(m) = Docs.meta(m)

nameof(b::Base.Docs.Binding) = b.var
nameof(x) = Base.nameof(x)

sigs(x::Base.Docs.MultiDoc) = x.order
sigs(::Any) = Type[Union{}]


# Footnote checks.
# ----------------
"""
$(SIGNATURES)

Checks footnote links in a [`Documents.Document`](@ref).
"""
function footnotes(doc::Documents.Document)
    @debug "checking footnote links."
    # A mapping of footnote ids to a tuple counter of how many footnote references and
    # footnote bodies have been found.
    #
    # For all ids the final result should be `(N, 1)` where `N > 1`, i.e. one or more
    # footnote references and a single footnote body.
    footnotes = Dict{Documents.Page, Dict{String, Tuple{Int, Int}}}()
    for (src, page) in doc.blueprint.pages
        empty!(page.globals.meta)
        orphans = Dict{String, Tuple{Int, Int}}()
        for element in page.elements
            Documents.walk(page.globals.meta, page.mapping[element]) do block
                footnote(block, orphans)
            end
        end
        footnotes[page] = orphans
    end
    for (page, orphans) in footnotes
        for (id, (ids, bodies)) in orphans
            # Multiple footnote bodies.
            if bodies > 1
                push!(doc.internal.errors, :footnote)
                @warn "footnote '$id' has $bodies bodies in $(Utilities.locrepr(page.source))."
            end
            # No footnote references for an id.
            if ids === 0
                push!(doc.internal.errors, :footnote)
                @warn "unused footnote named '$id' in $(Utilities.locrepr(page.source))."
            end
            # No footnote bodies for an id.
            if bodies === 0
                push!(doc.internal.errors, :footnote)
                @warn "no footnotes found for '$id' in $(Utilities.locrepr(page.source))."
            end
        end
    end
end

function footnote(fn::Markdown.Footnote, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    if fn.text === nothing
        # Footnote references: syntax `[^1]`.
        orphans[fn.id] = (ids + 1, bodies)
        return false # No more footnotes inside footnote references.
    else
        # Footnote body: syntax `[^1]:`.
        orphans[fn.id] = (ids, bodies + 1)
        return true # Might be footnotes inside footnote bodies.
    end
end

footnote(other, orphans::Dict) = true

# Link Checks.
# ------------

hascurl() = (try; success(`curl --version`); catch err; false; end)

"""
$(SIGNATURES)

Checks external links using curl.
"""
function linkcheck(doc::Documents.Document)
    if doc.user.linkcheck
        if hascurl()
            for (src, page) in doc.blueprint.pages
                for element in page.elements
                    Documents.walk(page.globals.meta, page.mapping[element]) do block
                        linkcheck(block, doc)
                    end
                end
            end
        else
            push!(doc.internal.errors, :linkcheck)
            @warn "linkcheck requires `curl`."
        end
    end
    return nothing
end

function linkcheck(link::Markdown.Link, doc::Documents.Document; method::Symbol=:HEAD)

    # first, make sure we're not supposed to ignore this link
    for r in doc.user.linkcheck_ignore
        if linkcheck_ismatch(r, link.url)
            @debug "linkcheck '$(link.url)': ignored."
            return false
        end
    end

    if !haskey(doc.internal.locallinks, link)
        null_file = @static Sys.iswindows() ? "nul" : "/dev/null"
        cmd = `curl $(method === :HEAD ? "-sI" : "-s") --proto =http,https,ftp,ftps $(link.url) --max-time 10 -o $null_file --write-out "%{http_code} %{url_effective} %{redirect_url}"`

        local result
        try
            # interpolating into backticks escapes spaces so constructing a Cmd is necessary
            result = read(cmd, String)
        catch err
            push!(doc.internal.errors, :linkcheck)
            @warn "$cmd failed:" exception = err
            return false
        end
        STATUS_REGEX = r"^(\d+) (\w+)://(?:\S+) (\S+)?$"m
        matched = match(STATUS_REGEX, result)
        if matched !== nothing
            status, scheme, location = matched.captures
            status = parse(Int, status)
            scheme = uppercase(scheme)
            protocol = startswith(scheme, "HTTP") ? :HTTP :
                startswith(scheme, "FTP") ? :FTP : :UNKNOWN

            if (protocol === :HTTP && status < 300) ||
                (protocol === :FTP && (200 <= status < 300 || status == 350))
                @debug "linkcheck '$(link.url)' status: $(status)."
            elseif protocol === :HTTP && status < 400
                if location !== nothing
                    @warn "linkcheck '$(link.url)' status: $(status), redirects to $(location)."
                else
                    @warn "linkcheck '$(link.url)' status: $(status)."
                end
            elseif protocol === :HTTP && status == 405 && method === :HEAD
                # when a server doesn't support HEAD requests, fallback to GET
                @debug "linkcheck '$(link.url)' status: $(status), retrying without `-I`"
                return linkcheck(link, doc; method=:GET)
            else
                push!(doc.internal.errors, :linkcheck)
                @error "linkcheck '$(link.url)' status: $(status)."
            end
        else
            push!(doc.internal.errors, :linkcheck)
            @warn "invalid result returned by $cmd:" result
        end
    end
    return false
end
linkcheck(other, doc::Documents.Document) = true

linkcheck_ismatch(r::String, url) = (url == r)
linkcheck_ismatch(r::Regex, url) = occursin(r, url)

end
