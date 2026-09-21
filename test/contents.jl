module ContentsTests
using Documenter
using Test
import IOCapture

# `@contents` without `Pages = [...]` must follow the `pages` order given to `makedocs`
# rather than the order in which the pages happen to be expanded (issue #936).
@testset "@contents ordering" begin
    function build_doc(files::Vector{Pair{String, String}}, pages)
        tmp = mktempdir()
        src = joinpath(tmp, "src")
        mkpath(src)
        for (name, content) in files
            write(joinpath(src, name), content)
        end
        IOCapture.capture() do
            Documenter.makedocs(;
                root = tmp, sitename = "T", pages = pages,
                format = Documenter.HTML(edit_link = nothing, disable_git = true),
                remotes = nothing,
            )
        end
        return read(joinpath(tmp, "build", "index.html"), String)
    end

    # Alphabetically, `zeta.md` sorts last; the `pages` order puts it first.
    files = [
        "index.md" => "# Index\n\n```@contents\n```\n",
        "alpha.md" => "# Alpha\n",
        "zeta.md" => "# Zeta\n",
    ]
    pages = ["index.md", "zeta.md", "alpha.md"]

    # The anchor fragments only appear in the `@contents` listing, not in the sidebar.
    html = build_doc(files, pages)
    @test findfirst("#Zeta", html) < findfirst("#Alpha", html)

    # An explicit `Pages = [...]` still wins over the navigation order.
    files[1] = "index.md" => "# Index\n\n```@contents\nPages = [\"alpha.md\", \"zeta.md\"]\n```\n"
    html = build_doc(files, pages)
    @test findfirst("#Alpha", html) < findfirst("#Zeta", html)
end

# A misspelled setting (e.g. `pages` instead of `Pages`) is silently ignored otherwise.
@testset "@contents / @index unknown settings" begin
    tmp = mktempdir()
    mkpath(joinpath(tmp, "src"))
    write(
        joinpath(tmp, "src", "index.md"),
        """
        # H

        ```@contents
        pages = ["index.md"]
        ```

        ```@index
        pages = ["index.md"]
        ```
        """
    )
    c = IOCapture.capture() do
        Documenter.makedocs(;
            root = tmp, sitename = "T",
            format = Documenter.HTML(edit_link = nothing, disable_git = true),
            remotes = nothing,
        )
    end
    @test occursin("unsupported keyword arguments have been set in the `@contents` node", c.output)
    @test occursin("unsupported keyword arguments have been set in the `@index` node", c.output)
end

end
