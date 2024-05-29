# This file checks that the compiled CSS files for the HTML themes are up to date.
#
# This does not run as part of the standard test suite, since the CSS produced by libsass
# is likely not deterministic across libsass versions.
#
# However, we can still run these tests as part of the CI, and ignore the results as needed.
using Test
using Documenter: HTMLWriter, git

const MAKE = Sys.which("make")
isnothing(MAKE) && error("Can't find `make` command")

@testset "HTML themes" begin
    @test isdir(HTMLWriter.ASSETS)
    @test isdir(HTMLWriter.ASSETS_SASS)
    @test isdir(HTMLWriter.ASSETS_THEMES)

    @testset "Remove: $(theme).css" for theme in HTMLWriter.THEMES
        # catppuccin-* themes are templated based on a common catppuccin.scss source file
        scss = replace(theme, r"(?<=^catppuccin)-[a-z]+$" => "")
        @test isfile(joinpath(HTMLWriter.ASSETS_SASS, "$(scss).scss"))

        css = joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css")
        @test isfile(css)
        @info "Removing $(theme).css" css
        rm(css)
    end

    @info "Rebuilding all the themes"
    run(`$MAKE -C $(@__DIR__) all`)

    # The `make` command should recreate all the CSS files, so we double check that
    # here, and also do a `git diff` check on it.
    @testset "Check: $(theme).css" for theme in HTMLWriter.THEMES
        @info "Checking $(theme).css"
        css = joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css")
        @test isfile(css)
        # Verify that the CSS file hasn't changed (exit code 1 indicates that it has)
        git_cmd = `$(git()) -C $(@__DIR__) diff --quiet $(css)`
        p = run(ignorestatus(git_cmd))
        if p.exitcode ∉ (0, 1)
            # An exit code that is not 0 or 1 indicates an unexpected failure
            # with the Git command (e.g. the file does not exist).
            @error "Git diff check failed unexpectedly for $(theme).css" css git_cmd
        end
        @test p.exitcode == 0
    end
end
