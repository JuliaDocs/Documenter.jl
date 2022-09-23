"""
Provides the [`missingdocs`](@ref), [`footnotes`](@ref) and [`linkcheck`](@ref) functions
for checking docs.
"""
module DocChecks

import ..Documenter:
    Documenter,
    Documents,
    Utilities,
    Utilities.@docerror

using DocStringExtensions
import Markdown
import AbstractTrees, MarkdownAST

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
        println(b, "$n docstring$(n ≡ 1 ? "" : "s") not included in the manual:\n")
        for (binding, signatures) in bindings
            for sig in signatures
                println(b, "    $binding", sig ≡ Union{} ? "" : " :: $sig")
            end
        end
        println(b)
        print(b, """
        These are docstrings in the checked modules (configured with the modules keyword)
        that are not included in @docs or @autodocs blocks.
        """)
        @docerror(doc, :missing_docs, String(take!(b)))
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
    for (binding, doc) in meta(mod)
        # The keys of the docs meta dictonary should always be Docs.Binding objects in
        # practice. However, the key type is Any, so it is theoretically possible that
        # some non-binding metadata gets added to the dict. So on the off-chance that has
        # happened, we simply ignore those entries.
        isa(binding, Docs.Binding) || continue
        # We only consider a name exported only if it actually exists in the module, either
        # by virtue of being defined there, or if it has been brought into the scope with
        # import/using.
        name = nameof(binding)
        isexported = (binding == Utilities.Binding(mod, name)) && Base.isexported(mod, name)
        if checkdocs === :all || (isexported && checkdocs === :exports)
            out[binding] = Set(sigs(doc))
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
        for node in AbstractTrees.PreOrderDFS(page.mdast)
            footnote(node.element, orphans)
        end
        footnotes[page] = orphans
    end
    for (page, orphans) in footnotes
        for (id, (ids, bodies)) in orphans
            # Multiple footnote bodies.
            if bodies > 1
                @docerror(doc, :footnote, "footnote '$id' has $bodies bodies in $(Utilities.locrepr(page.source)).")
            end
            # No footnote references for an id.
            if ids === 0
                @docerror(doc, :footnote, "unused footnote named '$id' in $(Utilities.locrepr(page.source)).")
            end
            # No footnote bodies for an id.
            if bodies === 0
                @docerror(doc, :footnote, "no footnotes found for '$id' in $(Utilities.locrepr(page.source)).")
            end
        end
    end
end

function footnote(fn::MarkdownAST.FootnoteLink, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    # Footnote references: syntax `[^1]`.
    orphans[fn.id] = (ids + 1, bodies)
end
function footnote(fn::MarkdownAST.FootnoteDefinition, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    # Footnote body: syntax `[^1]:`.
    orphans[fn.id] = (ids, bodies + 1)
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
                for node in AbstractTrees.PreOrderDFS(page.mdast)
                    linkcheck(node, doc)
                end
            end
        else
            @docerror(doc, :linkcheck, "linkcheck requires `curl`.")
        end
    end
    return nothing
end

function linkcheck(node::MarkdownAST.Node, doc::Documents.Document; method::Symbol=:HEAD)
    node.element isa MarkdownAST.Link || return
    link = node.element

    # first, make sure we're not supposed to ignore this link
    for r in doc.user.linkcheck_ignore
        if linkcheck_ismatch(r, link.destination)
            @debug "linkcheck '$(link.destination)': ignored."
            return
        end
    end

    if !haskey(doc.internal.locallinks, link)
        timeout = doc.user.linkcheck_timeout
        null_file = @static Sys.iswindows() ? "nul" : "/dev/null"
        # In some cases, web servers (e.g. docs.github.com as of 2022) will reject requests
        # that declare a non-browser user agent (curl specifically passes 'curl/X.Y'). In
        # case of docs.github.com, the server returns a 403 with a page saying "The request
        # is blocked". However, spoofing a realistic browser User-Agent string is enough to
        # get around this, and so here we simply pass the example Chrome UA string from the
        # Mozilla developer docs, but only is it's a HTTP(S) request.
        #
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent#chrome_ua_string
        fakebrowser  = startswith(uppercase(link.destination), "HTTP") ? [
            "--user-agent",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36",
            "-H",
            "accept-encoding: gzip, deflate, br",
        ] : ""
        cmd = `curl $(method === :HEAD ? "-sI" : "-s") --proto =http,https,ftp,ftps $(fakebrowser) $(link.destination) --max-time $timeout -o $null_file --write-out "%{http_code} %{url_effective} %{redirect_url}"`

        local result
        try
            # interpolating into backticks escapes spaces so constructing a Cmd is necessary
            result = read(cmd, String)
        catch err
            @docerror(doc, :linkcheck, "$cmd failed:", exception = err)
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

            if (protocol === :HTTP && (status < 300 || status == 302)) ||
                (protocol === :FTP && (200 <= status < 300 || status == 350))
                if location !== nothing
                    @debug "linkcheck '$(link.destination)' status: $(status), redirects to '$(location)'"
                else
                    @debug "linkcheck '$(link.destination)' status: $(status)."
                end
            elseif protocol === :HTTP && status < 400
                if location !== nothing
                    @warn "linkcheck '$(link.destination)' status: $(status), redirects to '$(location)'"
                else
                    @warn "linkcheck '$(link.destination)' status: $(status)."
                end
            elseif protocol === :HTTP && status == 405 && method === :HEAD
                # when a server doesn't support HEAD requests, fallback to GET
                @debug "linkcheck '$(link.destination)' status: $(status), retrying without `-I`"
                return linkcheck(link, doc; method=:GET)
            else
                @docerror(doc, :linkcheck, "linkcheck '$(link.destination)' status: $(status).")
            end
        else
            @docerror(doc, :linkcheck, "invalid result returned by $cmd:", result)
        end
    end
    return false
end

linkcheck_ismatch(r::String, url) = (url == r)
linkcheck_ismatch(r::Regex, url) = occursin(r, url)

end
