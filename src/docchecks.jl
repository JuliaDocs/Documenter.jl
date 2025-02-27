# Provides the [`missingdocs`](@ref), [`footnotes`](@ref) and [`linkcheck`](@ref) functions
# for checking docs.

# Missing docstrings.
# -------------------

"""
$(SIGNATURES)

Checks that a [`Document`](@ref) contains all available docstrings that are
defined in the `modules` keyword passed to [`makedocs`](@ref).

Prints out the name of each object that has not had its docs spliced into the document.

Returns the number of missing bindings to allow for automated testing of documentation.
"""
function missingdocs(doc::Document)
    doc.user.checkdocs === :none && return 0
    bindings = missingbindings(doc)
    n = reduce(+, map(length, values(bindings)), init = 0)
    if n > 0
        b = IOBuffer()
        println(b, "$n docstring$(n ≡ 1 ? "" : "s") not included in the manual:\n")
        for (binding, signatures) in bindings
            for sig in signatures
                println(b, "    $binding", sig ≡ Union{} ? "" : " :: $sig")
            end
        end
        println(b)
        print(
            b, """
            These are docstrings in the checked modules (configured with the modules keyword)
            that are not included in canonical @docs or @autodocs blocks.
            """
        )
        @docerror(doc, :missing_docs, String(take!(b)))
    end
    return n
end

function missingbindings(doc::Document)
    @debug "checking for missing docstrings."
    bindings = allbindings(doc.user.checkdocs, doc.blueprint.modules)
    for object in keys(doc.internal.objects)
        if !is_canonical(object)
            continue
        end
        # The module references in docs blocks can yield a binding like
        # Docs.Binding(Mod, :SubMod) for a module SubMod, a submodule of Mod. However, the
        # module bindings that come from Docs.meta() always appear to be of the form
        # Docs.Binding(Mod.SubMod, :SubMod) (since Julia 0.7). We therefore "normalize"
        # module bindings before we search in the list returned by allbindings().
        binding = if DocSystem.defined(object.binding) && !DocSystem.iskeyword(object.binding)
            m = DocSystem.resolve(object.binding)
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
    return bindings
end

function allbindings(checkdocs::Symbol, mods)
    out = Dict{Binding, Set{Type}}()
    for m in mods
        allbindings(checkdocs, m, out)
    end
    return out
end

function allbindings(checkdocs::Symbol, mod::Module, out = Dict{Binding, Set{Type}}())
    for (binding, doc) in meta(mod)
        # The keys of the docs meta dictionary should always be Docs.Binding objects in
        # practice. However, the key type is Any, so it is theoretically possible that
        # some non-binding metadata gets added to the dict. So on the off-chance that has
        # happened, we simply ignore those entries.
        isa(binding, Docs.Binding) || continue
        # We only consider a name exported only if it actually exists in the module, either
        # by virtue of being defined there, or if it has been brought into the scope with
        # import/using.
        name = nameof(binding)
        isexported = (binding == Binding(mod, name)) && Base.isexported(mod, name)
        ispublic = (binding == Binding(mod, name)) && @static if isdefined(Base, :ispublic)
            Base.ispublic(mod, name)
        else
            Base.isexported(mod, name)
        end
        if checkdocs === :all ||
                (isexported && checkdocs === :exports) ||
                (ispublic && checkdocs === :public)
            out[binding] = Set(sigs(doc))
        end
    end
    return out
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

Checks footnote links in a [`Document`](@ref).
"""
function footnotes(doc::Document)
    @debug "checking footnote links."
    # A mapping of footnote ids to a tuple counter of how many footnote references and
    # footnote bodies have been found.
    #
    # For all ids the final result should be `(N, 1)` where `N > 1`, i.e. one or more
    # footnote references and a single footnote body.
    footnotes = Dict{Page, Dict{String, Tuple{Int, Int}}}()
    for (src, page) in doc.blueprint.pages
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
                @docerror(doc, :footnote, "footnote '$id' has $bodies bodies in $(locrepr(page.source)).")
            end
            # No footnote references for an id.
            if ids === 0
                @docerror(doc, :footnote, "unused footnote named '$id' in $(locrepr(page.source)).")
            end
            # No footnote bodies for an id.
            if bodies === 0
                @docerror(doc, :footnote, "no footnotes found for '$id' in $(locrepr(page.source)).")
            end
        end
    end
    return
end

function footnote(fn::MarkdownAST.FootnoteLink, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    # Footnote references: syntax `[^1]`.
    return orphans[fn.id] = (ids + 1, bodies)
end
function footnote(fn::MarkdownAST.FootnoteDefinition, orphans::Dict)
    ids, bodies = get(orphans, fn.id, (0, 0))
    # Footnote body: syntax `[^1]:`.
    return orphans[fn.id] = (ids, bodies + 1)
end
footnote(other, orphans::Dict) = true

# Link Checks.
# ------------

function hascurl()
    try
        return success(`curl --version`)
    catch err
        return false
    end
end

"""
$(SIGNATURES)

Checks external links using curl.
"""
function linkcheck(doc::Document)
    if doc.user.linkcheck
        if hascurl()
            for (src, page) in doc.blueprint.pages
                linkcheck(page.mdast, doc)
            end
        else
            @docerror(doc, :linkcheck, "linkcheck requires `curl`.")
        end
    end
    return nothing
end

function linkcheck(mdast::MarkdownAST.Node, doc::Document)
    for node in AbstractTrees.PreOrderDFS(mdast)
        linkcheck(node, node.element, doc)
    end
    return
end

function linkcheck(node::MarkdownAST.Node, element::MarkdownAST.AbstractElement, doc::Document)
    # The linkcheck is only active for specific `element` types
    # (`MarkdownAST.Link`, most importantly), which are defined below as more
    # specific methods
    return nothing
end

function linkcheck(node::MarkdownAST.Node, link::MarkdownAST.Link, doc::Document; method::Symbol = :HEAD)

    # first, make sure we're not supposed to ignore this link
    for r in doc.user.linkcheck_ignore
        if linkcheck_ismatch(r, link.destination)
            @debug "linkcheck '$(link.destination)': ignored."
            return
        end
    end

    if !haskey(doc.internal.locallinks, link)
        cmd = _linkcheck_curl(method, link.destination; timeout = doc.user.linkcheck_timeout, useragent = doc.user.linkcheck_useragent)

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
                return linkcheck(node, link, doc; method = :GET)
            else
                @docerror(doc, :linkcheck, "linkcheck '$(link.destination)' status: $(status).")
            end
        else
            @docerror(doc, :linkcheck, "invalid result returned by $cmd:", result)
        end
    end
    return false
end


function linkcheck(node::MarkdownAST.Node, docs_node::Documenter.DocsNode, doc::Document)
    for mdast in docs_node.mdasts
        linkcheck(mdast, doc)
    end
    return
end

linkcheck_ismatch(r::String, url) = (url == r)
linkcheck_ismatch(r::Regex, url) = occursin(r, url)

const _LINKCHECK_DEFAULT_USERAGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"

function _linkcheck_curl(method::Symbol, url::AbstractString; timeout::Real, useragent::Union{AbstractString, Nothing})
    null_file = @static Sys.iswindows() ? "nul" : "/dev/null"
    # In some cases, web servers (e.g. docs.github.com as of 2022) will reject requests
    # that declare a non-browser user agent (curl specifically passes 'curl/X.Y'). In
    # case of docs.github.com, the server returns a 403 with a page saying "The request
    # is blocked". However, spoofing a realistic browser User-Agent string is enough to
    # get around this, and so here we simply pass the example Chrome UA string from the
    # Mozilla developer docs, but only is it's a HTTP(S) request.
    #
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent#chrome_ua_string
    fakebrowser = if startswith(uppercase(url), "HTTP")
        headers = [
            "-H",
            "accept-encoding: gzip, deflate, br",
        ]
        if !isnothing(useragent)
            push!(headers, "--user-agent", useragent)
        end
        headers
    else
        String[]
    end
    return `curl $(method === :HEAD ? "-sI" : "-s") --proto =http,https,ftp,ftps $(fakebrowser) $(url) --max-time $timeout -o $null_file --write-out "%{http_code} %{url_effective} %{redirect_url}"`
end

# Automatic Pkg.add() GitHub remote check
# ---------------------------------------

function gh_get_json(path)
    io = IOBuffer()
    url = "https://api.github.com$(path)"
    @debug "request: GET $url"
    resp = Downloads.request(
        url,
        output = io,
        headers = Dict(
            "Accept" => "application/vnd.github.v3+json",
            "X-GitHub-Api-Version" => "2022-11-28"
        )
    )
    return resp.status, JSON.parse(String(take!(io)))
end

function tag(repo, tag_ref)
    status, result = gh_get_json("/repos/$(repo)/git/ref/tags/$(tag_ref)")
    if status == 404
        return nothing
    elseif status != 200
        error("Unexpected error code $(status) '$(repo)' while getting tag '$(tag_ref)'.")
    end
    if result["object"]["type"] == "tag"
        status, result = gh_get_json("/repos/$(repo)/git/tags/$(result["object"]["sha"])")
        if status == 404
            return nothing
        elseif status != 200
            error("Unexpected error code $(status) '$(repo)' while getting tag '$(tag_ref)'.")
        end
    end
    return result
end

function gitcommit(repo, commit_tag)
    status, result = gh_get_json("/repos/$(repo)/git/commits/$(commit_tag)")
    if status != 200
        error("Unexpected error code $(status) '$(repo)' while getting commit '$(commit_tag)'.")
    end
    return result
end

GITHUB_ERROR_ADVICE = (
    "This means automatically finding the source URL link for this package failed. " *
        "Please add the source URL link manually to the `remotes` field " *
        "in `makedocs` or install the package using `Pkg.develop()``."
)

function githubcheck(doc::Document)
    if !doc.user.linkcheck || (doc.user.remotes === nothing)
        return
    end
    # When we add GitHub links based on packages which have been added with
    # Pkg.add(), we don't have much git information, so we simply use a guessed
    # tag based on the version `v$VERSION`, as this tag is added by the popular
    # TagBot action.
    #
    # This check uses the GitHub API to check whether the tag exists, and if
    # so, whether the tree hash matches the tree hash of the package entry
    # in the manifest.
    src_to_uuid = get_src_to_uuid(doc)
    for remote_repo in doc.user.remotes
        if !(remote_repo.remote isa Remotes.GitHub)
            continue
        end
        if !(remote_repo.root in keys(src_to_uuid))
            continue
        end
        uuid = src_to_uuid[remote_repo.root]
        repo_info = uuid_to_repo(doc, uuid)
        if repo_info === nothing
            continue
        end
        if remote_repo.remote != repo_info[1] || remote_repo.commit != repo_info[2]
            continue
        end
        # Looks like it's been guessed -- let's check if it matches the
        # tree hash from the package entry
        uuid_to_version_info = get_uuid_to_version_info(doc)
        tree_hash = uuid_to_version_info[uuid][2]
        remote = remote_repo.remote
        repo = remote.user * "/" * remote.repo
        tag_guess = remote_repo.commit
        tag_ref = tag(repo, tag_guess)
        if tag_ref === nothing
            @docerror(doc, :linkcheck_remotes, "linkcheck (remote) '$(repo)' error while getting tag '$(tag_guess)'. $(GITHUB_ERROR_ADVICE)")
            return
        end
        if tag_ref["object"]["type"] != "commit"
            @docerror(doc, :linkcheck_remotes, "linkcheck (remote) '$(repo)' tag '$(tag_guess)' does not point to a commit. $(GITHUB_ERROR_ADVICE)")
            return
        end
        commit_sha = tag_ref["object"]["sha"]
        git_commit = gitcommit(repo, commit_sha)
        actual_tree_hash = git_commit["tree"]["sha"]
        if string(tree_hash) != actual_tree_hash
            @docerror(
                doc,
                :linkcheck_remotes,
                "linkcheck (remote) '$(repo)' tag '$(tag_guess)' points to tree hash $(actual_tree_hash), but package entry has $(tree_hash). $(GITHUB_ERROR_ADVICE)"
            )
        end
    end
    return
end
