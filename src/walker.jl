
# Change to the docstring's defining module if it has one. Change back afterwards.
function walk(f, page, block::Markdown.MD)
    tmp = get(page.env, :CurrentModule, nothing)
    mod = get(block.meta, :module, nothing)
    mod ≡ nothing || (page.env[:CurrentModule] = mod)
    f(block) && walk(f, page, block.content)
    tmp ≡ nothing ? delete!(page.env, :CurrentModule) : (page.env[:CurrentModule] = tmp)
    nothing
end

function walk(f, page::Page, block::Vector)
    for each in block
        f(each) && walk(f, page, each)
    end
end

typealias MDContentElements Union{
    Markdown.BlockQuote,
    Markdown.Paragraph,
    Markdown.MD,
    DocStr,
}
walk(f, page, block::MDContentElements) = f(block) ? walk(f, page, block.content) : nothing

typealias MDTextElements Union{
    Markdown.Bold,
    Markdown.Footnote,
    Markdown.Header,
    Markdown.Italic,
}
walk(f, page, block::MDTextElements) = f(block) ? walk(f, page, block.text)  : nothing

walk(f, page, block::Markdown.Image) = f(block) ? walk(f, page, block.alt)   : nothing
walk(f, page, block::Markdown.Table) = f(block) ? walk(f, page, block.rows)  : nothing
walk(f, page, block::Markdown.List)  = f(block) ? walk(f, page, block.items) : nothing
walk(f, page, block::Markdown.Link)  = f(block) ? walk(f, page, block.text)  : nothing

walk(f, page, block) = (f(block); nothing)
