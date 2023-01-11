using Dates
using Test
using GitHub
# Note: currently requires a modified version of CommonMark:
# https://github.com/mortenpi/CommonMark.jl/tree/mp/reference-links
using CommonMark

# Configuration:

const LINKREF_EXCEPTIONS = [
    "json-jl", "juliamono", "documenterlatex", "documentermarkdown", "liveserver", "markdownast", "documenter-issues",
    r"^julia-([0-9]+)$",
    r"^julialangorg-([0-9]+)$",
    r"^badge-([a-z]+)$",
]
const ISSUE_LIST_START = "<!-- issue link definitions -->"
const ISSUE_LIST_END = "<!-- end of issue link definitions -->"
const CHANGELOG = joinpath(@__DIR__, "..", "CHANGELOG.md")

# Functions:

"""
    isabsurl(url)
Checks whether `url` is an absolute URL (as opposed to a relative one).
"""
isabsurl(url) = occursin(ABSURL_REGEX, url)
const ABSURL_REGEX = r"^[[:alpha:]+-.]+://"

function findnodes(T, ast)
    nodes = CommonMark.Node[]
    for (node, entering) in ast
        entering || continue
        node.t isa T && push!(nodes, node)
    end
    return nodes
end

function children(n::CommonMark.Node)
    n, nodes = n.first_child, CommonMark.Node[]
    while n != CommonMark.NULL_NODE
        push!(nodes, n)
        n = n.nxt
    end
    return nodes
end

function fetch_github_issues(; minratelimit=30, auth_token=nothing, issues_list_cache=Ref{Vector{Issue}}())
    if isassigned(issues_list_cache)
        @debug "Using cached issues list" length(issues_list_cache[])
    else
        auth = isnothing(auth_token) ? GitHub.AnonymousAuth() : authenticate(auth_token)

        ratelimit = rate_limit(auth=auth)
        if ratelimit["rate"]["remaining"] < minratelimit
            reset = unix2datetime(ratelimit["rate"]["reset"])
            @warn """
            Failed to fetch issues from GitHub.
            Rate-limited: too few requests remaining ($(ratelimit["rate"]["remaining"]); less than $(minratelimit))
            Reset at $(reset) UTC (unix: $(ratelimit["rate"]["reset"]))
            Likely due to GITHUB_TOKEN not having been set.
            """ rate_limit = ratelimit
            return
        end

        @debug "rate_limit" ratelimit["rate"]["remaining"] reset = unix2datetime(ratelimit["rate"]["reset"]) rate_limit = ratelimit
        issues_list_cache[], _ = issues(
            "JuliaDocs/Documenter.jl",
            auth=auth,
            params=Dict(:state => "all", :per_page => 100)
        )
    end
    issues_dict = Dict(issue.number => issue for issue in issues_list_cache[])
    # sanity check, to make sure there are no duplicate issue numbers
    @assert length(issues_list_cache[]) == length(issues_dict)
    return issues_dict
end

function parse_changelog_into_ast(io::IO)
    p = Parser()
    bad_reflabels = String[]
    p.inline_parser.reflink_callback = reflabel -> begin
        push!(bad_reflabels, reflabel)
    end
    changelog = read(io, String)
    ast = p(changelog)
    if !isempty(bad_reflabels)
        # If we found any bad reference labels, we'll add them to the .refmap manually
        # and re-parse the CHANGELOG file
        refmap = Dict{String,Tuple{String,String}}(
            reflabel => ("#MISSING#", "")
            for reflabel in bad_reflabels
        )
        return p(changelog, refmap=refmap)
    else
        return ast
    end
end
parse_changelog_into_ast(filename::AbstractString) = open(parse_changelog_into_ast, filename)

function print_nonref_links(ast::CommonMark.Node)
    println("Following non-ref links found in AST:", "")
    for link in findnodes(CommonMark.Link, ast)
        println(" - ", term(link), " (", link.t.destination, ")")
    end
end

"""
Check that all the standard (non-reference) links in the AST are absolute URLs.
"""
function check_links_not_absolute(ast::CommonMark.Node)
    badlinks = String[]
    for link in findnodes(CommonMark.Link, ast)
        isabsurl(link.t.destination) && continue
        push!(badlinks, string(" - ", term(link), " (", link.t.destination, ")"))
    end
    isempty(badlinks) && return true
    @error """Non-absolute links detected in text.
    This is likely due to wrong brackets for reference links ('()' vs '[]').
    $(join(badlinks, "\n"))
    """
    return false
end

"""
Check that all the link reference definitions in the AST are absolute URLs.
"""
function check_linkrefs_not_absolute(ast::CommonMark.Node)
    badlinks = String[]
    for link in findnodes(CommonMark.LinkReferenceDefinition, ast)
        isabsurl(link.t.destination) && continue
        push!(badlinks, string(" - [", link.t.label, "]: ", link.t.destination))
    end
    isempty(badlinks) && return true
    @error """Non-absolute link references detected.
    $(join(badlinks, "\n"))
    """
    return false
end

"""
Returns a tuple of information if the text in a link is `#[0-9]+`, and `nothing`
if it is not.
"""
function parse_documenter_linktext(node::CommonMark.Node)
    cs = children(node)
    length(cs) == 1 || return
    cs[1].t isa CommonMark.Text || return
    m = match(r"^#([0-9]+)$", cs[1].literal)
    isnothing(m) && return
    return (number=parse(Int, m[1]), text=cs[1].literal, node=node)
end

function check_reflinks(ast::CommonMark.Node)
    badlinks = String[]
    for reflink in findnodes(CommonMark.ReferenceLink, ast)
        if any(occursin(exception, reflink.t.label) for exception in LINKREF_EXCEPTIONS)
            @debug "Ignoring ref link: '$(reflink.t.label)'"
            continue
        end
        # First, make sure that the reference link label is 'github-NNN'
        m = match(r"^github-([0-9]+)$", reflink.t.label)
        if isnothing(m)
            push!(badlinks, string(" - ", term(reflink), " [", reflink.t.label, "]"))
            continue
        end
        # If the link text is '#NNN', then we make sure that the issue numbers match
        link_issunumber = parse(Int, m[1])
        linktext = parse_documenter_linktext(reflink)
        if !isnothing(linktext)
            if linktext.number != link_issunumber
                push!(badlinks, string(" - ", term(reflink), " [", reflink.t.label, "]"))
            end
        else
            # If we didn't manage to determine the issue number from the text, we also
            # consider it to be a bad link. However, this may need to be relaxed in the
            # future, as it is not necessarily an error to have a link using the `github-N`
            # labels even if they are not an issue link.
            push!(badlinks, string(" - ", term(reflink), " [", reflink.t.label, "]"))
        end
    end
    isempty(badlinks) && return true
    @error """Invalid reference links:
    $(join(badlinks, "\n"))
    """
    return false
end

function parse_documenter_url(destination)
    m = match(r"^https://github.com/JuliaDocs/Documenter.jl/(pull|issues)/([0-9]+)$", destination)
    isnothing(m) && return
    (type=m[1], number=parse(Int, m[2]), url=destination)
end

"""
Make sure that all `github-NNN` link reference definitions point to Documenter.
"""
function check_linkrefs_github_url(ast::CommonMark.Node; ghissues::Union{Dict{Int,Issue},Nothing}=nothing)
    badlinks = String[]
    for link in findnodes(CommonMark.LinkReferenceDefinition, ast)
        # Only keep labels that are in the 'github-NNN' format
        m = match(r"^github-([0-9]+)$", link.t.label)
        isnothing(m) && continue
        urlinfo = parse_documenter_url(link.t.destination)
        if isnothing(urlinfo)
            push!(badlinks, string(" - [", link.t.label, "]: ", link.t.destination, " (bad URL)"))
            continue
        end
        # If the URL is sane, we'll check that the issue number matches:
        if urlinfo.number != parse(Int, m[1])
            push!(badlinks, string(" - [", link.t.label, "]: ", link.t.destination, " (issue number mismatch)"))
            continue
        end
        # If ghissues was passed, we will check to make sure that the issue type is correct
        isnothing(ghissues) && continue
        if !haskey(ghissues, urlinfo.number)
            push!(badlinks, string(" - [", link.t.label, "]: ", link.t.destination, " (bad GH issue number)"))
            continue
        end
        gh_url = ghissues[urlinfo.number].html_url
        if string(gh_url) != urlinfo.url
            push!(badlinks, string(" - [", link.t.label, "]: ", link.t.destination, " (bad URL for issue, should be: '$(gh_url)')"))
            continue
        end
    end
    isempty(badlinks) && return true
    @error """Invalid GitHub link references detected.
    $(join(badlinks, "\n"))
    """
    return false
end

function check_issue_list_delimiters(io::IO)
    errors = String[]
    changelog = readlines(io)
    linkdef_start = findfirst(contains(ISSUE_LIST_START), changelog)
    linkdef_end = findfirst(contains(ISSUE_LIST_END), changelog)
    # Check that the delimiters are present
    isnothing(linkdef_start) && push!(errors, " - '$(ISSUE_LIST_START)'")
    isnothing(linkdef_end) && push!(errors, " - '$(ISSUE_LIST_END)'")
    # Make sure that the issue delimiters are in the right order
    if !isnothing(linkdef_start) && !isnothing(linkdef_end)
        (linkdef_end - linkdef_start) >= 1 || push!(errors, " - Issue list delimiters in wrong order")
    end
    isempty(errors) && return true
    @error """Missing issue list delimiters:
    $(join(errors, "\n"))
    """
    return false
end
check_issue_list_delimiters(filename::AbstractString) = open(check_issue_list_delimiters, filename)

function find_github_links(ast::CommonMark.Node)
    links, linkdefs = [], []
    for node in findnodes(CommonMark.ReferenceLink, ast)
        m = match(r"^github-([0-9]+)$", node.t.label)
        isnothing(m) && continue
        push!(links, (
            label=node.t.label,
            number=parse(Int, m[1]),
            node=node,
        ))
    end
    for node in findnodes(CommonMark.LinkReferenceDefinition, ast)
        m = match(r"^github-([0-9]+)$", node.t.label)
        isnothing(m) && continue
        push!(linkdefs, (
            label=node.t.label,
            url=node.t.destination,
            number=parse(Int, m[1]),
            node=node,
        ))
    end
    return (; links, linkdefs)
end

function check_missing_links(ast)
    errors = String[]
    links, linkdefs = find_github_links(ast)
    link_numbers = sort(unique(link.number for link in links))
    linkdef_numbers = sort(unique(link.number for link in linkdefs))
    if linkdef_numbers != unique(link.number for link in linkdefs)
        push!(errors, " - Link definitions not sorted")
    end
    for n in linkdef_numbers
        # Check that there are not duplicate link definitions
        counts = count(isequal(n), link.number for link in linkdefs)
        (counts == 1) || push!(errors, " - Duplicate link definition: github-$(n) (x$(counts))")
        # Make sure that each linkdef has a corresponding link:
        idx = findfirst(isequal(n), link_numbers)
        isnothing(idx) && push!(errors, " - Missing link for link definition: github-$(n)")
    end
    for n in link_numbers
        # Make sure that each link has a corresponding link definition:
        idx = findfirst(isequal(n), linkdef_numbers)
        isnothing(idx) && push!(errors, " - Missing link definition for link: [github-$(n)]")
    end
    isempty(errors) && return true
    @error """Missing or duplicate github-NNN links.
    $(join(errors, "\n"))
    """
    return false
end

function fix_changelog_issue_list(filename; ofile=filename, ghissues::Union{Dict{Int,Issue},Nothing}=nothing)
    # Find the link definition list in the CHANGELOG
    changelog = readlines(filename)
    linkdef_start = findfirst(contains(ISSUE_LIST_START), changelog)
    linkdef_end = findfirst(contains(ISSUE_LIST_END), changelog)
    @assert !isnothing(linkdef_start)
    @assert !isnothing(linkdef_end)
    @assert (linkdef_end - linkdef_start) >= 1
    # Generate the correct link reference definition list
    ast = parse_changelog_into_ast(filename)
    links, linkdefs = find_github_links(ast)

    linkdef_list = map(sort(unique(link.number for link in links))) do issuenumber
        # If ghissues is passed, we'll determine the URL from there
        url = if !isnothing(ghissues)
            if haskey(ghissues, issuenumber)
                string(ghissues[issuenumber].html_url)
            else
                @warn "Invalid issue: github-$(issuenumber) missing from GH issue list"
                nothing
            end
        end
        # If that did not success (no ghissues, or issue missing), then we'll fall back to
        # the URL in the existing link reference definition
        if isnothing(url)
            idx = findfirst(linkdef -> linkdef.number == issuenumber, linkdefs)
            if isnothing(idx)
                @warn "Issue missing from link reference definitions, assuming '/issues/': github-$(issuenumber)"
                url = "https://github.com/JuliaDocs/Documenter.jl/issues/$(issuenumber)"
            else
                url = linkdefs[idx].url
            end
        end
        return "[github-$(issuenumber)]: $(url)"
    end
    # Update the relevant lines and write the output file
    changelog_updated = vcat(changelog[1:linkdef_start], linkdef_list, changelog[linkdef_end:end])
    open(ofile, "w") do io
        for line in changelog_updated
            write(io, line, '\n')
        end
    end
end

macro interactive(expr)
    @assert expr.head == :if
    isinteractive() ? expr.args[2] : expr
end

function run_mode(args)
    "test" in args && return :test
    "fix" in args && return :fix
    return :check
end

const PATH_OPTION_REGEX = r"^--file=(.+)$"
function changelog_file_path(args)
    idx = findlast(contains(PATH_OPTION_REGEX), args)
    isnothing(idx) && return CHANGELOG
    m = match(PATH_OPTION_REGEX, args[idx])
    path = joinpath(pwd(), m[1])
    @info "Reading CHANGELOG from $path"
    return path
end

# Read ARGS and run the script.
# The @interactive make it possible to run each of the blocks in e.g. VSCode without having
# to set up the ARGS variable.

github_issues_list = @interactive if "--github" in ARGS
    @info "Attempting to fetch issue list from GitHub..."
    issues = fetch_github_issues(auth_token=get(ENV, "GITHUB_TOKEN", nothing))
    isnothing(issues) || @info "... fetched information on $(length(issues)) issues."
    issues
end

@interactive if run_mode(ARGS) === :check
    ast = parse_changelog_into_ast(changelog_file_path(ARGS))
    # Just for information, we print out all the standard (i.e. not refererence) links found in
    # the document. This can be manually checked every now and then to make sure that there are
    # no unexpected entries there.
    print_nonref_links(ast)
    # Run all the checks and throw an error there are any problems:
    noerrors = true
    noerrors = noerrors & check_issue_list_delimiters(CHANGELOG)
    noerrors = noerrors & check_reflinks(ast)
    noerrors = noerrors & check_links_not_absolute(ast)
    noerrors = noerrors & check_linkrefs_not_absolute(ast)
    noerrors = noerrors & check_linkrefs_github_url(ast; ghissues=github_issues_list)
    noerrors = noerrors & check_missing_links(ast)
    if noerrors
        @info "No errors detected in CHANGELOG.md"
    else
        error("Errors detected in CHANGELOG.md, see the log.")
    end
end

@interactive if run_mode(ARGS) === :fix
    @info "Updating CHANGELOG.md. This will overwrite the file."
    @assert check_issue_list_delimiters(CHANGELOG)
    fix_changelog_issue_list(CHANGELOG, ghissues=github_issues_list)
end

# Run with MD string
rwmds(f, mds::AbstractString) = f(parse_changelog_into_ast(IOBuffer(mds)))

@interactive if run_mode(ARGS) === :test
    @info "Running changelog.jl tests"
    valid_example = read(joinpath(@__DIR__, "changelog-valid.md"), String)
    invalid_example = read(joinpath(@__DIR__, "changelog-invalid.md"), String)

    @testset "changelog.jl" begin
        @testset "check_issue_list_delimiters()" begin
            @test check_issue_list_delimiters(IOBuffer(valid_example))
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer(invalid_example)) === false
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer("")) === false
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer("""
            foo bar baz
            """)) === false
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer("""
            <!-- issue link definitions -->
            """)) === false
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer("""
            <!-- end of issue link definitions -->
            """)) === false
            @test @test_logs (:error,) check_issue_list_delimiters(IOBuffer("""
            <!-- end of issue link definitions -->
            <!-- issue link definitions -->
            """)) === false
            @test check_issue_list_delimiters(IOBuffer("""
            <!-- issue link definitions -->
            <!-- end of issue link definitions -->
            """))
            @test check_issue_list_delimiters(IOBuffer("""
            foo
            <!-- issue link definitions -->
            bar
            <!-- end of issue link definitions -->
            """))
        end

        @testset "check_reflinks()" begin
            @test rwmds(check_reflinks, "")
            @test rwmds(check_reflinks, valid_example)
            @test @test_logs (:error,) rwmds(check_reflinks, invalid_example) === false
            @test rwmds(
                check_reflinks,
                """
Reference link: [#1234][github-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            )
            @test @test_logs (:error,) rwmds(
                check_reflinks,
                """
Bad reference link label: [#1234][githb-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_reflinks,
                """
Mismatching issue numbers: [#4321][github-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_reflinks,
                """
Link label not '#NNNN': [1234][github-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_reflinks,
                """
Link label not '#NNNN': [foobar][github-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
        end

        @testset "check_links_not_absolute()" begin
            @test rwmds(check_links_not_absolute, "")
            @test rwmds(check_links_not_absolute, valid_example)
            @test @test_logs (:error,) rwmds(check_links_not_absolute, invalid_example) === false
            @test @test_logs (:error,) rwmds(
                check_links_not_absolute,
                """
Non-absolute URL: [foobar](github-1234).
"""
            ) === false
            @test rwmds(
                check_links_not_absolute,
                """
Absolute URL: [foobar](https://example.org/).
"""
            )
        end

        @testset "check_linkrefs_not_absolute()" begin
            @test rwmds(check_linkrefs_not_absolute, "")
            @test rwmds(check_linkrefs_not_absolute, valid_example)
            @test @test_logs (:error,) rwmds(check_linkrefs_not_absolute, invalid_example) === false
        end

        @testset "check_linkrefs_github_url()" begin
            @test rwmds(check_linkrefs_github_url, "")
            @test rwmds(check_linkrefs_github_url, valid_example)
            @test @test_logs (:error,) rwmds(check_linkrefs_github_url, invalid_example) === false
            @test @test_logs (:error,) rwmds(
                check_linkrefs_github_url,
                """
[github-1234]: https://githb.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_linkrefs_github_url,
                """
[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1235
"""
            ) === false
            @test rwmds(
                check_linkrefs_github_url,
                """
[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            )
        end

        @testset "check_missing_links()" begin
            @test rwmds(check_missing_links, "")
            @test rwmds(check_missing_links, valid_example)
            @test @test_logs (:error,) rwmds(check_missing_links, invalid_example) === false
            @test @test_logs (:error,) rwmds(
                check_missing_links,
                """
[#1234][github-1234]

[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_missing_links,
                """
[#1234][github-1234]
"""
            ) === false
            @test @test_logs (:error,) rwmds(
                check_missing_links,
                """
[github-1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
"""
            ) === false
        end
    end
end
