# Documenter.jl changelog

## Version `v0.20-dev`

* Documenter v0.20 requires at least Julia v0.7. ([#795][github-795])

* ![BREAKING][badge-breaking] Documentation deployment via the `deploydocs` function has changed considerably.

  - The user-facing directories (URLs) of different versions and what gets displayed in the version selector have changed. By default, Documenter now creates the `stable/` directory (as before) and a directory for every minor version (`vX.Y/`). The `release-X.Y` directories are no longer created. ([#706][github-706], [#813][github-813], [#817][github-817])

    Technically, Documenter now deploys actual files only to `dev/` and `vX.Y.Z/` directories. The directories (URLs) that change from version to version (e.g. `latest/`, `vX.Y`) are implemented as symlinks on the `gh-pages` branch.

    The version selector will only display `vX.Y/`, `stable/` and `dev/` directories by default. This behavior can be customized with the `selector` keyword of `deploydocs`.

  - Documentation from the development branch (e.g. `master`) now deploys to `dev/` by default (instead of `latest/`). This can be customized with the `devurl` keyword. ([#802][github-802])

  - The `latest` keyword to `deploydocs` has been deprecated and renamed to `devbranch`. ([#802][github-802])

  - The `julia` and `osname` keywords to `deploydocs` are now deprecated. ([#816][github-816])

  - The default values of the `target`, `deps` and `make` keywords to `deploydocs` have been changed. See the default format change below for more information. ([#826][github-826])

  **For upgrading:**

  - If you are using the `latest` keyword, then just use `devbranch` with the same value instead.

  - Update links that point to `latest/` to point to `dev/` instead (e.g. in the README).

  - Remove any links to the `release-X.Y` branches and remove the directories from your `gh-pages` branch.

  - The operating system and Julia version should be specified in the Travis build stage configuration (via `julia:` and `os:` options, see "Hosting Documentation" in the manual for more details) or by checking the `TRAVIS_JULIA_VERSION` and `TRAVIS_OS_NAME` environment variables in `make.jl` yourself.

* ![BREAKING][badge-breaking] `makedocs` will now build Documenter's native HTML output by default and `deploydocs`' defaults now assume the HTML output. ([#826][github-826])

  - The default value of the `format` keyword of `makedocs` has been changed to `:html`.

  - The default value of the `target` keyword to `deploydocs` has been changed to `"build"`.

  - The default value of the `make` and `deps` keywords to `deploydocs` have been changed to `nothing`.

  **For upgrading:** If you are relying on the Markdown/MkDocs output, you now need to:

  - In `makedocs`, explicitly set `format = :markdown`

  - In `deploydocs`, explicitly set

    ```julia
    target = "site"
    deps = Deps.pip("pygments", "mkdocs")
    make = () -> run(`mkdocs build`)
    ```

  - Explicitly import `DocumenterMarkdown` in `make.jl`. See the `MarkdownWriter` deprecation below.

  If you already specify any of the changed keywords, then you do not need to make any changes to those keywords you already set.

  However, if you are setting any of the values to the new defaults (e.g. when you are already using the HTML output), you may now rely on the new defaults.

* ![Deprecation][badge-deprecation] The Markdown/MkDocs (`format = :markdown`) and PDF/LaTeX (`format = :latex`) outputs now require an external package to be loaded ([DocumenterMarkdown](https://github.com/JuliaDocs/DocumenterMarkdown.jl) and [DocumenterLaTeX](https://github.com/JuliaDocs/DocumenterLaTeX.jl), respectively). ([#833][github-833])

  **For upgrading:** Make sure that the respective extra package is installed and then just add `using DocumenterMarkdown` or `using DocumenterLaTeX` to `make.jl`.

* ![BREAKING][badge-breaking] "Pretty URLs" are enabled by default now for the HTML output. The default value of the `html_prettyurls` has been changed to `true`.

  For a page `foo/page.md` Documenter now generates `foo/page/index.html`, instead of `foo/page.html`.
  On GitHub pages deployments it means that your URLs look like  `foo/page/` instead of `foo/page.html`.

  For local builds you should explicitly set `html_prettyurls = false`.

  **For upgrading:** If you wish to retain the old behavior, set `html_prettyurls = false` in `makedocs`. If you already set `html_prettyurls`, you do not need to change anything.

* ![BREAKING][badge-breaking] The `Travis.genkeys` and `Documenter.generate` functions have been moved to a separate [DocumenterTools.jl package](https://github.com/JuliaDocs/DocumenterTools.jl). ([#789][github-789])

* ![Enhancement][badge-enhancement] If Documenter is not able to determine which Git hosting service is being used to host the source, the "Edit on XXX" links become "Edit source" with a generic icon. ([#804][github-804])

* ![Enhancement][badge-enhancement] The at-blocks now support `MIME"text/html"` rendering of objects (e.g. for interactive plots). I.e. if a type has `show(io, ::MIME"text/html", x)` defined, Documenter now uses that when rendering the objects in the document. ([#764][github-764])

* ![Enhancement][badge-enhancement] Minor style enhancements. ([#841][github-841])

* ![Bugfix][badge-bugfix] The at-blocks that execute code can now handle `include` statements. ([#793][github-793], [#794][github-794])

* ![Bugfix][badge-bugfix] At-docs blocks no longer give an error when containing empty lines. ([#823][github-823], [#824][github-824])

[github-706]: https://github.com/JuliaDocs/Documenter.jl/pull/706
[github-764]: https://github.com/JuliaDocs/Documenter.jl/pull/764
[github-789]: https://github.com/JuliaDocs/Documenter.jl/pull/789
[github-793]: https://github.com/JuliaDocs/Documenter.jl/pull/793
[github-794]: https://github.com/JuliaDocs/Documenter.jl/pull/794
[github-795]: https://github.com/JuliaDocs/Documenter.jl/pull/795
[github-802]: https://github.com/JuliaDocs/Documenter.jl/pull/802
[github-804]: https://github.com/JuliaDocs/Documenter.jl/pull/804
[github-813]: https://github.com/JuliaDocs/Documenter.jl/pull/813
[github-816]: https://github.com/JuliaDocs/Documenter.jl/pull/816
[github-817]: https://github.com/JuliaDocs/Documenter.jl/pull/817
[github-823]: https://github.com/JuliaDocs/Documenter.jl/pull/823
[github-824]: https://github.com/JuliaDocs/Documenter.jl/pull/824
[github-826]: https://github.com/JuliaDocs/Documenter.jl/pull/826
[github-833]: https://github.com/JuliaDocs/Documenter.jl/pull/833
[github-841]: https://github.com/JuliaDocs/Documenter.jl/pull/841


[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-enhancement]: https://img.shields.io/badge/enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg

<!--
# Badges

![BREAKING][badge-breaking]
![Deprecation][badge-deprecation]
![Feature][badge-feature]
![Enhancement][badge-enhancement]
![Bugfix][badge-bugfix]
-->
