module TestHelperModule
    import MarkdownAST
    import RegistryInstances
end


function render_expand_doc(src, kwargs...)
    doc = Documenter.Document(;
        sitename = "sitename",
        modules = [TestHelperModule, TestHelperModule.MarkdownAST, TestHelperModule.RegistryInstances],
        pages = ["testpage" => "testpage.md"],
        linkcheck = true
    )
    doc.blueprint.pages["testpage.md"] = Documenter.Page("", "", "", [], Documenter.Globals(), src)
    for navnode in walk_navpages(doc.user.pages, nothing, doc)
        push!(doc.internal.navtree, navnode)
    end
    expand(doc)
    ctx = HTMLContext(doc, HTML())
    html = render_article(ctx, doc.internal.navtree[1])
    return doc, html
end
