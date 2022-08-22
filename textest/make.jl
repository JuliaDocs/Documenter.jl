using Documenter

"""
    foo()

Foo bar **baz**.

# asd

!!! info
    asdasd
"""
function foo end

"asdsad"
function bar end
"asdsad2"
function baz end

function make(format = :pdf)
    makedocs(
        root = @__DIR__,
        build = "build-$(format)",
        sitename = "textest",
        format = (format === :pdf) ? Documenter.LaTeX(platform = "none") : Documenter.HTML(),
        pages = ["blocks.md", "inlines.md", "docstrings.md", "eval.md"],
    )
end
