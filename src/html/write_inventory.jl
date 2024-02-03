"""
Generate the `objects.inv` inventory file.

Write the file `objects.inv` to the root of the HTML build folder, containing an
inventory of all linkable targets in the documentation (pages, headings, and docstrings).

The `objects.inv` file is compatible with [Sphinx](https://www.sphinx-doc.org/en/master/index.html)
See [DocInventories](https://juliadocs.org/DocInventories.jl/stable/formats/) for a
description. The file can be used by [Intersphinx](https://www.sphinx-doc.org/en/master/usage/extensions/intersphinx.html)
and the [DocumenterInterLinks](https://github.com/JuliaDocs/DocumenterInterLinks.jl/)
plugin to link into the documentation from other projects.
"""
function write_inventory(doc, ctx)

    @info "Writing inventory file."
    project = doc.user.sitename
    version = _find_project_version()

    io_inv_header = open(joinpath(doc.user.build, "objects.inv"), "w")

    write(io_inv_header, "# Sphinx inventory version 2\n")
    write(io_inv_header, "# Project: $project\n")
    write(io_inv_header, "# Version: $version\n")
    write(io_inv_header, "# The remainder of this file is compressed using zlib.\n")
    io_inv = ZlibCompressorStream(io_inv_header)

    domain = "std"
    role = "doc"
    priority = -1
    for navnode in doc.internal.navlist
        name = replace(splitext(navnode.page)[1], "\\" => "/")
        uri = _get_inventory_uri(doc, ctx, navnode)
        dispname = _get_inventory_dispname(doc, ctx, navnode)
        line = "$name $domain:$role $priority $uri $dispname\n"
        write(io_inv, line)
    end

    domain = "std"
    role = "label"
    priority = -1
    for name in keys(doc.internal.headers.map)
        isempty(name) && continue  # skip empty heading
        anchor = Documenter.anchor(doc.internal.headers, name)
        if isnothing(anchor)
            # anchor not unique -> exclude from inventory
            continue
        end
        uri = _get_inventory_uri(doc, ctx, name, anchor)
        dispname = _get_inventory_dispname(doc, ctx, name, anchor)
        line = "$name $domain:$role $priority $uri $dispname\n"
        write(io_inv, line)
    end

    domain = "jl"
    priority = 1
    for name in keys(doc.internal.docs.map)
        anchor = Documenter.anchor(doc.internal.docs, name)
        if isnothing(anchor)
            # anchor not unique -> exclude from inventory
            continue
        end
        uri = _get_inventory_uri(doc, ctx, name, anchor)
        role = lowercase(Documenter.doccat(anchor.object))
        dispname = "-"
        line = "$name $domain:$role $priority $uri $dispname\n"
        write(io_inv, line)
    end

    close(io_inv)
    close(io_inv_header)

end


function _find_project_version()
    current_dir = pwd()
    parent_dir = dirname(current_dir)
    while parent_dir != current_dir
        project_toml = joinpath(current_dir, "Project.toml")
        if isfile(project_toml)
            project_data = TOML.parsefile(project_toml)
            if haskey(project_data, "version")
                version = project_data["version"]
                @debug "Obtained `version=$(repr(version))` for inventory from $(project_toml)"
                return version
            end
        end
        current_dir = parent_dir
        parent_dir = dirname(current_dir)
    end
    @warn "Cannot extract version for inventory from Project.toml"
    return ""
end


# URI for :std:label
function _get_inventory_uri(doc, ctx, name::AbstractString, anchor::Documenter.Anchor)
    filename = relpath(anchor.file, doc.user.build)
    page_url = pretty_url(ctx, get_url(ctx, filename))
    if Sys.iswindows()
        # https://github.com/JuliaDocs/Documenter.jl/issues/2387
        page_url = replace(page_url, "\\" => "/")
    end
    page_url = join(map(_escapeuri, split(page_url, "/")), "/")
    label = _escapeuri(Documenter.anchor_label(anchor))
    if label == name
        uri = page_url * raw"#$"
    else
        uri = page_url * "#$label"
    end
    return uri
end


# URI for :std:doc
function _get_inventory_uri(doc, ctx, navnode::Documenter.NavNode)
    uri = pretty_url(ctx, get_url(ctx, navnode.page))
    if Sys.iswindows()
        # https://github.com/JuliaDocs/Documenter.jl/issues/2387
        uri = replace(uri, "\\" => "/")
    end
    uri = join(map(_escapeuri, split(uri, "/")), "/")
    return uri
end


# dispname for :std:label
function _get_inventory_dispname(doc, ctx, name::AbstractString, anchor::Documenter.Anchor)
    dispname = mdflatten(anchor.node)
    if dispname == name
        dispname = "-"
    end
    return dispname
end


# dispname for :std:doc
function _get_inventory_dispname(doc, ctx, navnode::Documenter.NavNode)
    dispname = navnode.title_override
    if isnothing(dispname)
        page = getpage(ctx, navnode)
        title_node = pagetitle(page.mdast)
        if isnothing(title_node)
            dispname = "-"
        else
            dispname = mdflatten(title_node)
        end
    end
    return dispname
end


@inline _issafe(c::Char) =
    c == '-' || c == '.' || c == '_' || (isascii(c) && (isletter(c) || isnumeric(c)))

_utf8_chars(str::AbstractString) = (Char(c) for c in codeunits(str))

_escapeuri(c::Char) = string('%', uppercase(string(Int(c), base=16, pad=2)))
_escapeuri(str::AbstractString) =
    join(_issafe(c) ? c : _escapeuri(c) for c in _utf8_chars(str))
