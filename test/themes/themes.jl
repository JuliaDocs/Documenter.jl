# This file checks that the compiled CSS files for the HTML themes are up to date.
#
# This does not run as part of the standard test suite, since the CSS produced by libsass
# is likely not deterministic across libsass versions.
#
# However, we can still run these tests as part of the CI, and ignore the results as needed.
using Test
using Documenter: HTMLWriter
using DocumenterTools: Themes

@testset "HTML themes" begin
    @test isdir(HTMLWriter.ASSETS)
    @test isdir(HTMLWriter.ASSETS_SASS)
    @test isdir(HTMLWriter.ASSETS_THEMES)

    for theme in HTMLWriter.THEMES
        # catppuccin-* themes are templated based on a common catppuccin.scss source file
        scss = replace(theme, r"(?<=^catppuccin)-[a-z]+$" => "")
        @test isfile(joinpath(HTMLWriter.ASSETS_SASS, "$(scss).scss"))
        @test isfile(joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css"))
    end

    mktempdir() do tmpdir
        for theme in HTMLWriter.THEMES
            startswith(theme, "catppuccin-") && continue # TODO: Require `make` invocation
            dst = joinpath(tmpdir, "$(theme).css")
            Themes.compile_native_theme(theme; dst=dst)
            css_compiled = read(dst)
            css_repo = read(joinpath(HTMLWriter.ASSETS_THEMES, "$(theme).css"))
            @test css_compiled == css_repo
        end
    end
end
