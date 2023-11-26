# Release notes

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## UNRELEASED

### Changed

* `id` anchors may now start with a numeric digit. ([#744], [#2325])
* Documenter prints a more informative warning now if there is unexpected Julia interpolation in the Markdown (e.g. from errant `$` signs). ([#2288], [#2327])
* Documenter now warns when it encounters invalid keys in the various key-value at-blocks. ([#2306], [#2324])
* File sizes are now expressed in more human-readable format. ([#2272], [#2344])

### Fixed

* Enabled text wrapping in docstring header on smaller screens. ([#2293], [#2307])
* Fixed breadcrumb overflow with long page title on narrow screens (mobile). ([#2317])
* Fixed `linkcheck` not checking inside of docstrings. ([#2329], [#2330])
* Headings are now rewritten to `<strong>` in lists found in docstrings. ([#2308], [#2313])

## Version [v1.1.2] - 2023-10-23

### Fixed

* Non-breaking spaces are now properly converted as "~" in the `LaTeXWriter`. ([#2300])

## Version [v1.1.1] - 2023-10-12

### Fixed

* Fixed, docstring collapse/expand icon not changing correctly when clicking rapidly. ([#2103], [#2217])

## Version [v1.1.0] - 2023-09-28

### Added

* Added `Remotes.GitLab` for specifying a `Remote` hosted on gitlab.com or a self-hosted GitLab instance. ([#2279])

### Fixed

* Fixed display of inline LaTeX math `$ ... $` from `show` methods in HTMLWriter. ([#2280], [#2281])
* Fixed a crash in GitHub remote link checking when `remotes = nothing`. ([#2274], [#2285])
* Fix an error occurring with `DocTestFilters = nothing` in `@meta` blocks. ([#2273], [#1696])

## Version [v1.0.1] - 2023-09-18

### Fixed

* Docstring with an unwrapped `Markdown.MD` object, such as the ones created when the `Markdown.@doc_str` macro is used, are correctly handled again. ([#2269])

## Version [v1.0.0] - 2023-09-15

### Version changes

* The (minimum) required Julia version has been raised from 1.0 to 1.6. For older Julia versions the 0.27.X release can still be used. ([#1835], [#1841])

### Breaking

* The `strict` keyword argument to `makedocs` has been removed and replaced with `warnonly`. `makedocs` now **fails builds by default** if any of the document checks fails (previously it only issued warnings by default). ([#2051], [#2194])

  **For upgrading:** If you are running with `strict = true`, you can just drop the `strict` option.
  If you are currently being strict about specific error classes, you can invert the list of error classes with `Documenter.except`.

  If you were not setting the `strict` keyword, but your build is failing now, you should first endeavor to fix the errors that are causing the build to fail.
  If that is not feasible, you can exclude specific error categories from failing the build (e.g. `warnonly = [:footnote, :cross_references]`).
  Finally, setting `warnonly = true` can be used to recover the old `strict = false` default behavior, turning all errors back into warnings.

* The Markdown backend has been fully removed from the Documenter package, in favor of the external [DocumenterMarkdown package](https://github.com/JuliaDocs/DocumenterMarkdown.jl). This includes the removal of the exported `Deps` module. ([#1826])

  **For upgrading:** To keep using the Markdown backend, refer to the [DocumenterMarkdown package](https://github.com/JuliaDocs/DocumenterMarkdown.jl). That package might not immediately support the latest Documenter version, however.

* `@eval` blocks now require the last expression to be either `nothing` or of type `Markdown.MD`, with other cases now issuing an `:eval_block` error, and falling back to a text representation of the object. ([#1919], [#2260])

  **For upgrading:** The cases where an `@eval` results in a object that is not `nothing` or `::Markdown.MD`, the returned object should be reviewed. In case the resulting object is of some `Markdown` node type (e.g. `Markdown.Paragraph` or `Markdown.Table`), it can simply be wrapped in `Markdown.MD([...])` for block nodes, or `Markdown.MD([Markdown.Paragraph([...])])` for inline nodes. In other cases Documenter was likely not handling the returned object in a correct way, but please open an issue if this change has broken a previously working use case. The error can be ignored by passing `:eval_block` to the `warnonly` keyword.

* The handling of remote repository (e.g. GitHub) URLs has been overhauled. ([#1808], [#1881], [#2081], [#2232])

  In addition to generating source and edit links for the main repository, Documenter can now also be configured to generate correct links for cases where some files are from a different repository (e.g. with vendored dependencies). There have also been changes and fixes to the way the automatic detection of source and edit links works.

  The fallbacks to `TRAVIS_REPO_SLUG` and `GITHUB_REPOSITORY` variables have been removed in favor of explicitly specifying the `repo` keyword in the `makedocs` call.

  Documenter is now also more strict about the cases where it is unable to determine the URLs, and therefore previously successful builds may break.

  **For upgrading:** As the fallbacks to CI variables have been removed, make sure that you have your source checked out as a proper Git repository when building the documentation, so that Documenter could determine the repository link automatically from the Git `origin` URL. On GitHub Actions, this should normally already be the case, and user action is unlikely to be necessary. In other cases, if necessary, you can configure the `repo` and/or `remotes` keywords of `makedocs` appropriately.

  These changes should mostly affect more complex builds that include docstrings or files from various sources, such as when including docstrings from multiple packages. In the latter case in particular, you should make sure that all the relevant packages are also fully cloned and added as development dependencies to the `docs/Project.toml` (or equivalent) environment (or that the `remotes` keyword is configured for the `Pkg.add`-ed packages).

  Finally, in general, even if the build succeeds, double check that the various remote links (repository links, source links, edits links) have been generated correctly. If you run into any unexpected errors, please open an issue.

* Documenter now checks that local links (e.g. to other Markdown files, local images; such as `[see the other page](other.md)`) are pointing to existing files. ([#2130], [#2187])

  This can cause existing builds to fail because previously broken links are now caught by the Documenter's document checks, in particular because Documenter now runs in strict mode by default.

  **For upgrading:** You should double check and fix all the offending links. Alternatively, you can also set `warnonly = :cross_references`, so that the errors would be reduced to warnings (however, this is not recommended, as you will have broken links in your generated documentation).

* The HTML output now enforces size thresholds for the generated HTML files, to catch cases where Documenter is deploying extremely large HTML files (usually due to generated content, like figures). If any generated HTML file is above either of the thresholds, Documenter will either error and fail the build (if above `size_threshold`), or warn (if above `size_threshold_warn`). The size threshold can also be ignored for specific pages with `size_threshold_ignore`. ([#2142], [#2205], [#2211], [#2252])

  **For upgrading:** If your builds are now failing due to the size threshold checks, you should first investigate why the generated HTML files are so large (e.g. you are likely automatically generating too much HTML, like extremely large inline SVG figures), and try to reduce them below the default thresholds.
  If you are unable to reduce the generated file size, you can increase the `size_threshold` value to just above the maximum size, or disable the enforcement of size threshold checks altogether by setting `size_threshold = nothing`.
  If it is just a few specific pages that are offending, you can also ignore those with `size_threshold_ignore`.

* User-provided `assets/search.js` file no longer overrides Documenter's default search implementation, and the user-provided files will now be ignored by default. ([#2236])

  **For upgrading:** The JS file can still be included via the `assets` keyword of `format = HTML(...)`. However, it will likely conflict with Documenter's default search implementation. If you require an API to override Documenter's search engine, please open an issue.

* Plugin objects which were formally passed as (undocumented) positional keyword arguments to `makedocs` are now given as elements of a list `plugins` passed as a keyword argument ([#2245], [#2249])

  **For upgrading:** If you are passing any plugin objects to `makedocs` (positionally), pass them via the `plugins` keyword instead.

* `makedocs` will now throw an error if it gets passed an unsupported keyword argument. ([#2259])

  **For upgrading:** Remove the listed keyword arguments from the `makedocs` call. If the keyword was previously valid, consult this CHANGELOG for upgrade instructions.

### Added

* Doctest filters can now be specified as regex/substitution pairs, i.e. `r"..." => s"..."`, in order to control the replacement (which defaults to the empty string, `""`). ([#1989], [#1271])

* Documenter is now more careful not to accidentally leak SSH keys (in e.g. error messages) by removing `DOCUMENTER_KEY` from the environment when it is not needed. ([#1958], [#1962])

* Admonitions are now styled with color in the LaTeX output. ([#1931], [#1932], [#1946], [#1955])

* Improved the styling of code blocks in the LaTeXWriter. ([#1933], [#1935], [#1936], [#1944], [#1956], [#1957])

* Automatically resize oversize `tabular` environments from `@example` blocks in LaTeXWriter. ([#1930], [#1937])

* The `ansicolor` keyword to `HTML()` now defaults to true, meaning that executed outputs from `@example`- and `@repl`-blocks are now by default colored (if they emit colored output). ([#1828])

* Documenter now shows a link to the root of the repository in the top navigation bar. The link is determined automatically from the remote repository, unless overridden or disabled via the `repolink` argument of `HTML`. ([#1254])

* A more general API is now available to configure the remote repository URLs via the `repo` argument of `makedocs` by passing objects that are subtypes of `Remotes.Remote` and implement its interface (e.g. `Remotes.GitHub`). ([#1808], [#1881])

* Broken issue references (i.e. links like `[#1234](@ref)`, but when Documenter is unable to determine the remote GitHub repository) now generate `:cross_references` errors that can be caught via the `strict` keyword. ([#1808])

  This is **potentially breaking** as it can cause previously working builds to fail if they are being run in strict mode. However, such builds were already leaving broken links in the generated documentation.

  **For upgrading:** the easiest way to fix the build is to remove the offending `@ref` links. Alternatively, the `repo` argument to `makedocs` can be set to the appropriate `Remotes.Remote` object that implements the `Remotes.issueurl` function, which would make sure that correct URLs are generated.

* Woodpecker CI is now automatically supported for documentation deployment. ([#1880])

* The `@contents`-block now support `UnitRange`s for the `Depth` argument. This makes it possible to configure also the *minimal* header depth that should be displayed (`Depth = 2:3`, for example). This is supported by the HTML and the LaTeX/PDF backends. ([#245], [#1890])

* The code copy buttons in HTML now have `title` and `aria-label` attributes. ([#1903])

* The at-ref links are now more flexible, allowing arbitrary links to point to both docstrings and section headings. ([#781], [#1900])

* Code blocks like `@example` or `@repl` are now also expanded in nested contexts (e.g. admonitions, lists or block quotes). ([#491], [#1970])

* The new `pagesonly` keyword to `makedocs` can be used to restrict builds to just the Markdown files listed in `pages` (as opposed to all `.md` files under `src/`). ([#1980])

* Search engine and social media link previews are now supported, with Documenter generating the relevant HTML `meta` tags. ([#1321], [#1991])

* `deploydocs` now supports custom tag prefixes; see section "Deploying from a monorepo" in the docs. ([#1291], [#1792], [#1993])

* The `target` keyword of `deploydocs` is now required to point to a subdirectory of `root` (usually the directory where `make.jl` is located). ([#2019])

* Added keyboard shortcuts for search box (`Ctrl + /` or `Cmd + /` to focus into the search box, `Esc` to focus out of it). ([#1536], [#2027])

* The various JS and font dependencies of the HTML backend have been updated to the latest non-breaking versions. ([#2066], [#2067], [#2070], [#2071], [#2213])

  - KaTeX has been updated from `v0.13.24` to `v0.16.8` (major version bump).
  - Font Awesome has been updated from `v5.15.4` to `v6.4.2` (major version bump).
  - bulma.sass has been updated from `v0.7.5` to `v0.9.4` (major version bump).
  - darkly.scss been updated to `v0.8.1`.
  - highlight.js has been updated from `v11.5.1` to `v11.8.0`.
  - JuliaMono has been updated from `v0.045` to `v0.050`.
  - jQuery UI has been updated from `v1.12.1` to `v1.13.2`.
  - jquery has been updated from `v3.6.0` to `v3.7.0`.
  - MathJax 2 has been updated  from `v2.7.7` to `v2.7.9`.

* Move the mobile layout sidebar toggle (hamburger) from the right side to the left side. ([#1312], [#2076], [#2169], [#2215], [#2216])

* Added the ability to expand/collapse individual as well as all docstrings. ([#1393], [#2078])

* Invalid local link warnings during HTML rendering now print a bit more context, helping in pinpointing the offending link. ([#2100])

* Admonitions with category `details` are now rendered as (collapsed) `<details>` in the HTML backend. The admonition title is used as the `<summary>`. ([#2128])

* Theme switcher now includes an "Automatic (OS preference)" option that makes the site follow the user's OS setting. ([#1745], [#2085], [#2170])

* Documenter now generates a `.documenter-siteinfo.json` file in the HTML build, that contains some metadata about the build. ([#2181])

* The search UI has had a complete overhaul, with a fresh new modal UI with better context for search results and a filter mechanism to remove unwanted results. The client-side search engine has been changed from LunrJs to MinisearchJs. ([#1437], [#2141], [#2147], [#2202])

* The `doctest` routine can now receive the same `plugins` keyword argument as `makedocs`. This enables `doctest` to run if any plugin with a mandatory `Plugin` object is loaded, e.g., [DocumenterCitations](https://github.com/JuliaDocs/DocumenterCitations.jl). ([#2245])

* The HTML output will automatically write larger `@example`-block outputs to files, to make the generated HTML files smaller. The size threshold can be controlled with the `example_size_threshold` option to `HTML`. ([#2143], [#2247])

* The `@docs` and `@autodocs` blocks can now be declared non-canonical, allowing multiple copied of the same docstring to be included in the manual. ([#1079], [#1570], [#2237])

### Fixed

* Line endings in Markdown source files are now normalized to `LF` before parsing, to work around [a bug in the Julia Markdown parser][JuliaLang/julia#29344] where parsing is sensitive to line endings, and can therefore cause platform-dependent behavior. ([#1906])

* `HTMLWriter` no longer complains about invalid URLs in docstrings when `makedocs` gets run multiple time in a Julia session, as it no longer modifies the underlying docstring objects. ([#505], [#1924])

* Docstring doctests now properly get checked on each `makedocs` run, when run multiple times in the same Julia session. ([#974], [#1948])

* The default decision for whether to deploy preview builds for pull requests have been changed from `true` to `false` when not possible to verify the origin of the pull request. ([#1969])

* `deploydocs` now correctly handles version symlinks where the destination directory has been deleted. ([#2012])

### Other

* Documenter now uses [MarkdownAST](https://github.com/JuliaDocs/MarkdownAST.jl) to internally represent Markdown documents. While this change should not lead to any visible changes to the user, it is a major refactoring of the code. Please report any novel errors or unexpected behavior you encounter when upgrading to 0.28 on the [Documenter issue tracker](https://github.com/JuliaDocs/Documenter.jl/issues). ([#1892], [#1912], [#1924], [#1948])

* The code layout has changed considerably, with many of the internal submodules removed. This **may be breaking** for code that hooks into various Documenter internals, as various types and functions now live at different code paths. ([#1976], [#1977], [#2191], [#2214])


## Version [v0.27.25] - 2023-07-03

### Fixed

* Page headings are now correctly escaped in `LaTeXWriter`. ([#2134])

* Compiling the dark theme with Sass no longer emits deprecation warnings about `!global` assignments. ([#1766], [#1983], [#2145])

* The CSS Documenter ships is now minified. ([#2153], [#2157])

## Version [v0.27.24] - 2023-01-23

### Security

* `deploydocs` now takes extra care to avoid committing the temporary SSH key file to the Git repo. ([#2018])

## Version [v0.27.23] - 2022-08-26

### Added

* The `native` and `docker` PDF builds now run with the `-interaction=batchmode` (instead of `nonstopmode`) and `-halt-on-error` options to make the LaTeX error logs more readable and to fail the build early. ([#1908])

### Fixed

* The PDF/LaTeX output now handles hard Markdown line breaks (i.e. `Markdown.LineBreak` nodes). ([#1908])

* Previously broken links within the PDF output are now fixed. ([JuliaLang/julia#38054], [JuliaLang/julia#43652], [#1909])

## Version [v0.27.22] - 2022-07-24

### Other

* Documenter is now compatible with DocStringExtensions v0.9. ([#1885], [#1886])

## Version [v0.27.21] - 2022-07-13

### Fixed

* Fix a regression where Documenter throws an error on systems that do not have Git available. ([#1870], [#1871])

## Version [v0.27.20] - 2022-07-10

### Added

* The various JS and font dependencies of the HTML backend have been updated to the latest non-breaking versions. ([#1844], [#1846])

  - MathJax 3 has been updated from v3.2.0 to v3.2.2.
  - JuliaMono has been updated from v0.044 to v0.045.
  - Font Awesome has been updated from v5.15.3 to v5.15.4.
  - highlight.js has been updated from v11.0.1 to v11.5.1.
  - KaTeX has been updated from v0.13.11 to v0.13.24.

* **Experimental**: `deploydocs` now supports "deploying to tarball" (rather than pushing to the `gh-pages` branch) via the undocumented experiments `archive` keyword. ([#1865])

### Fixed

* When including docstrings for an alias, Documenter now correctly tries to include the exactly matching docstring first, before checking for signature subtypes. ([#1842])

* When checking for missing docstrings, Documenter now correctly handles docstrings for methods that extend bindings from other modules that have not been imported into the current module. ([#1695], [#1857], [#1861])

* By overriding `GIT_TEMPLATE_DIR`, `git` no longer picks up arbitrary user templates and hooks when internally called by Documenter. ([#1862])

## Version [v0.27.19] - 2022-06-05

### Added

* Documenter can now build draft version of HTML documentation by passing `draft=true` to `makedocs`. Draft mode skips potentially expensive parts of the building process and can be useful to get faster feedback when writing documentation. Draft mode currently skips doctests, `@example`-, `@repl`-, `@eval`-, and `@setup`-blocks. Draft mode can be disabled (or enabled) on a per-page basis by setting `Draft = true` in an `@meta` block. ([#1836])

* On the HTML search page, pressing enter no longer causes the page to refresh (and therefore does not trigger the slow search index rebuild). ([#1728], [#1833], [#1834])

* For the `edit_link` keyword to `HTML()`, Documenter automatically tries to figure out if the remote default branch is `main`, `master`, or something else. It will print a warning if it is unable to reliably determine either `edit_link` or `devbranch` (for `deploydocs`). ([#1827], [#1829])

* Profiling showed that a significant amount of the HTML page build time was due to external `git` commands (used to find remote URLs for docstrings). These results are now cached on a per-source-file basis resulting in faster build times. This is particularly useful when using [LiveServer.jl](https://github.com/tlienart/LiveServer.jl)s functionality for live-updating the docs while writing. ([#1838])

## Version [v0.27.18] - 2022-05-25

### Added

* The padding of the various container elements in the HTML style has been reduced, to improve the look of the generated HTML pages. ([#1814], [#1818])

### Fixed

* When deploying unversioned docs, Documenter now generates a `siteinfo.js` file that disables the version selector, even if a `../versions.js` happens to exists. ([#1667], [#1825])

* Build failures now only show fatal errors, rather than all errors. ([#1816])

* Disable git terminal prompt when detecting remote HEAD branch for ssh remotes, and allow ssh-agent authentication (by appending rather than overriding ENV). ([#1821])

## Version [v0.27.17] - 2022-05-09

### Added

* PDF/LaTeX output can now be compiled with the [Tectonic](https://tectonic-typesetting.github.io) LaTeX engine. ([#1802], [#1803])

* The phrasing of the outdated version warning in the HTML output has been improved. ([#1805])

* Documenter now provides the `Documenter.except` function which can be used to "invert" the list of errors that are passed to `makedocs` via the `strict` keyword. ([#1811])

### Fixed

* When linkchecking HTTP and HTTPS URLs, Documenter now also passes a realistic `accept-encoding` header along with the request, in order to work around servers that try to block non-browser requests. ([#1807])

* LaTeX build logs are now properly outputted to the `LaTeXWriter.{stdout,stderr}` files when using the Docker build option. ([#1806])

* `makedocs` no longer fails with an `UndefVarError` if it encounters a specific kind of bad docsystem state related to docstrings attached to the call syntax, but issues an `@autodocs` error/warning instead. ([JuliaLang/julia#45174], [#1192], [#1810], [#1811])

## Version [v0.27.16] - 2022-04-19

### Added

* Update CSS source file for JuliaMono, so that all font variations are included (not just `JuliaMono Regular`) and that the latest version (0.039 -> 0.044) of the font would be used. ([#1780], [#1784])

* The table of contents in the generated PDFs have more space between section numbers and titles to avoid them overlapping. ([#1785])

* The preamble of the LaTeX source of the PDF build can now be customized by the user. ([#1746], [#1788])

* The package version number shown in the PDF manual can now be set by the user by passing the `version` option to `format = LaTeX()`. ([#1795])

### Fixed

* Fix `strict` mode to properly print errors, not just a warnings. ([#1756], [#1776])

* Disable git terminal prompt when detecting remote HEAD branch. ([#1797])

* When linkchecking HTTP and HTTPS URLs, Documenter now passes a realistic browser (Chrome) `User-Agent` header along with the request, in order to work around servers that try to use the `User-Agent` to block non-browser requests. ([#1796])

## Version [v0.27.15] - 2022-03-17

### Added

* Documenter now deploys documentation from scheduled jobs (`schedule` on GitHub actions). ([#1772], [#1773])

* Improve layout of the table of contents section in the LaTeX/PDF output. ([#1750])

### Fixed

* Improve the fix for extraneous whitespace in REPL blocks. ([#1774])

## Version [v0.27.14] - 2022-03-02

### Fixed

* Fix a CSS bug causing REPL code blocks to contain extraneous whitespace. ([#1770], [#1771])

## Version [v0.27.13] - 2022-02-25

### Fixed

* Fix a CSS bug causing the location of the code copy button to not be fixed in the upper right corner. ([#1758], [#1759])

* Fix a bug when loading the `copy.js` script for the code copy button. ([#1760], [#1762])

## Version [v0.27.12] - 2022-01-17

### Fixed

* Fix code copy button in insecure contexts (e.g. pages hosted without https). ([#1754])

## Version [v0.27.11] - 2022-01-16

### Added

* Documenter now deploys documentation from manually triggered events (`workflow_dispatch` on GitHub actions). ([#1554], [#1752])

* MathJax 3 has been updated to v3.2.0 (minor version bump). ([#1743])

* HTML code blocks now have a copy button. ([#1748])

* Documenter now tries to detect the development branch using `git` with the old default (`master`) as fallback. If you use `main` as the development branch you shouldn't need to specify `devbranch = "main"` as an argument to deploydocs anymore. ([#1443], [#1727], [#1751])

## Version [v0.27.10] - 2021-10-20

### Fixed

* Fix depth of headers in LaTeXWriter. ([#1716])

## Version [v0.27.9] - 2021-10-18

### Fixed

* Fix some errors with text/latex MIME type in LaTeXWriter. ([#1709])

## Version [v0.27.8] - 2021-10-14

### Added

* The keyword argument `strict` in `makedocs` is more flexible: in addition to a boolean indicating whether or not any error should result in a failure, `strict` also accepts a `Symbol` or `Vector{Symbol}` indicating which error(s) should result in a build failure. ([#1689])

* Allow users to inject custom JavaScript resources to enable alternatives to Google Analytics like plausible.io. ([#1706])

### Fixed

* Fix a few accessibility issues in the HTML output. ([#1673])

## Version [v0.27.7] - 2021-09-27

### Fixed

* Fix an error when building documentation for the first time with `push_preview`. ([#1693], [#1704])

* Fix a rare logger error for failed doctests. ([#1698], [#1699])

* Fix an error occurring with `DocTestFilters = nothing` in `@meta` blocks. ([#1696])

## Version [v0.27.6] - 2021-09-07

### Added

* Add support for generating `index.html` to redirect to `dev` or `stable`. The redirected destination is the same as the outdated warning. If there's already user-generated `index.html`, Documenter will not overwrite the file. ([#937], [#1657], [#1658])

### Fixed

* Checking whether a PR comes from the correct repository when deciding to deploy a preview on GitHub Actions now works on Julia 1.0 too. ([#1665])

* When a doctest fails, pass file and line information associated to the location of the doctest instead of the location of the testing code in Documenter to the logger. ([#1687])

* Enabled colored printing for each output of `@repl`-blocks. ([#1691])

## Version [v0.27.5] - 2021-07-27

### Fixed

* Fix an error introduced in version v0.27.4 (PR([#1634]) which was triggered by trailing comments in `@eval`/`@repl`/`@example` blocks. ([#1655], [#1661])

## Version [v0.27.4] - 2021-07-19

### Added

* `@example`- and `@repl`-blocks now support colored output by mapping ANSI escape sequences to HTML. This requires Julia >= 1.6 and passing `ansicolor=true` to `Documenter.HTML` (e.g. `makedocs(format=Documenter.HTML(ansicolor=true, ...), ...)`). In Documenter 0.28.0 this will be the default so to (preemptively) opt-out pass `ansicolor=false`. ([#1441], [#1628], [#1629], [#1647])

* **Experimental** Documenter's HTML output can now prerender syntax highlighting of code blocks, i.e. syntax highlighting is applied when generating the HTML page rather than on the fly in the browser after the page is loaded. This requires (i) passing `prerender=true` to `Documenter.HTML` and (ii) a `node` (NodeJS) executable available in `PATH`. A path to a `node` executable can be specified by passing the `node` keyword argument to `Documenter.HTML` (for example from the `NodeJS_16_jll` Julia package). In addition, the `highlightjs` keyword argument can be used to specify a file path to a highlight.js library (if this is not given the release used by Documenter will be used). Example configuration:
  ```julia
  using Documenter, NodeJS_16_jll

  makedocs(;
      format = Documenter.HTML(
          prerender = true,            # enable prerendering
          node = NodeJS_16_jll.node(), # specify node executable (required if not available in PATH)
          # ...
      )
      # ...
  )
  ```
  _This feature is experimental and subject to change in future releases._ ([#1627])

* The `julia>` prompt is now colored in green in the `julia-repl` language highlighting. ([#1639], [#1641])

* The `.hljs` CSS class is now added to all code blocks to make sure that the correct text color is used for non-highlighted code blocks and if JavaScript is disabled. ([#1645])

* The sandbox module used for evaluating `@repl` and `@example` blocks is now removed (replaced with `Main`) in text output. ([#1633])

* `@repl`, `@example`, and `@eval` blocks now have `LineNumberNodes` inserted such that e.g. `@__FILE__` and `@__LINE__` give better output and not just `"none"` for the file and `1` for the line. This requires Julia 1.6 or higher (no change on earlier Julia versions). ([#1634])

### Fixed

* Dollar signs in the HTML output no longer get accidentally misinterpreted as math delimiters in the browser. ([#890], [#1625])

* Fix overflow behavior for math environments to hide unnecessary vertical scrollbars. ([#1575], [#1649])

## Version [v0.27.3] - 2021-06-29

### Added

* Documenter can now deploy documentation directly to the "root" instead of versioned folders. ([#1615], [#1616])

* The version of Documenter used for generating a document is now displayed in the build information. ([#1609], [#1611])

### Fixed

* The HTML front end no longer uses ligatures when displaying code (with JuliaMono). ([#1610], [#1617])

## Version [v0.27.2] - 2021-06-18

### Added

* The default font has been changed to `Lato Medium` so that the look of the text would be closer to the old Google Fonts version of Lato. ([#1602], [#1604])

## Version [v0.27.1] - 2021-06-17

### Added

* The HTML output now uses [JuliaMono](https://cormullion.github.io/pages/2020-07-26-JuliaMono/) as the default monospace font, retrieved from CDNJS. Relatedly, the Lato font is also now retrieved from CDNJS, and the generated HTML pages no longer depend on Google Fonts. ([#618], [#1561], [#1568], [#1569]), [JuliaLang/www.julialang.org](https://github.com/JuliaLang/www.julialang.org/issues/1272)

* The wording of the text in the the old version warning box was improved. ([#1595])

### Fixed

* Documenter no longer throws an error when generating the version selector if there are no deployed versions. ([#1594], [#1596])

## Version [v0.27.0] - 2021-06-11

### Added

* The JS dependencies have been updated to their respective latest versions.

  - highlight.js has been updated to v11.0.1 (major version bump), which also brings various updates to the highlighting of Julia code. Due to the changes in highlight.js, code highlighting will not work on IE11. ([#1503], [#1551], [#1590])

  - Headroom.js has been updated to v0.12.0 (major version bump). ([#1590])

  - KaTeX been updated to v0.13.11 (major version bump). ([#1590])

  - MathJax versions have been updated to v2.7.7 (patch version bump) and v3.1.4 (minor version bump), for MathJax 2 and 3, respectively. ([#1590])

  - jQuery been updated to v3.6.0 (minor version bump). ([#1590])

  - Font Awesome has been updated to v5.15.3 (patch version bump). ([#1590])

  - lunr.js has been updated to v2.3.9 (patch version bump). ([#1590])

  - lodash.js has been updated to v4.17.21 (patch version bump). ([#1590])

* `deploydocs` now throws an error if something goes wrong with the Git invocations used to deploy to `gh-pages`. ([#1529])

* In the HTML output, the site name at the top of the sidebar now also links back to the main page of the documentation (just like the logo). ([#1553])

* The generated HTML sites can now detect if the version the user is browsing is not for the latest version of the package and display a notice box to the user with a link to the latest version. In addition, the pages get a `noindex` tag which should aid in removing outdated versions from search engine results. ([#1302], [#1449], [#1577])

* The analytics in the HTML output now use the `gtag.js` script, replacing the old deprecated setup. ([#1559])

### Fixed

* A bad `repo` argument to `deploydocs` containing a protocol now throws an error instead of being misinterpreted. ([#1531], [#1533])

* SVG images generated by `@example` blocks are now properly scaled to page width by URI-encoding the images, instead of directly embedding the SVG tags into the HTML. ([#1537], [#1538])

* `deploydocs` no longer tries to deploy pull request previews from forks on GitHub Actions. ([#1534], [#1567])

### Other

* Documenter is no longer compatible with IOCapture v0.1 and now requires IOCapture v0.2. ([#1549])

## Version [v0.26.3] - 2021-03-02

### Fixed

* The internal naming of the temporary modules used to run doctests changed to accommodate upcoming printing changes in Julia. ([JuliaLang/julia#39841], [#1540])

## Version [v0.26.2] - 2021-02-15

### Added

* `doctest()` no longer throws an error if cleaning up the temporary directory fails for some reason. ([#1513], [#1526])

* Cosmetic improvements to the PDF output. ([#1342], [#1527])

* If `jldoctest` keyword arguments fail to parse, these now get logged as doctesting failures, rather than being ignored with a warning or making `makedocs` throw an error (depending on why they fail to parse). ([#1556], [#1557])

### Fixed

* Script-type doctests that have an empty output section no longer crash Documenter. ([#1510])

* When checking for authentication keys when deploying, Documenter now more appropriately checks if the environment variables are non-empty, rather than just whether they are defined. ([#1511])

* Doctests now correctly handle the case when the repository has been checked out with `CRLF` line endings (which can happen on Windows with `core.autocrlf=true`). ([#1516], [#1519], [#1520])

* Multiline equations are now correctly handled in at-block outputs. ([#1518])

## Version [v0.26.1] - 2020-12-16

### Fixed

* HTML assets that are copied directly from Documenters source to the build output now has correct file permissions. ([#1497])

## Version [v0.26.0] - 2020-12-10

### Breaking
* The PDF/LaTeX output is again provided as a Documenter built-in and can be enabled by passing an instance of `Documenter.LaTeX` to `format`. The DocumenterLaTeX package has been deprecated. ([#1493])

  **For upgrading:** If using the PDF/LaTeX output, change the `format` argument of `makedocs` to `format = Documenter.LaTeX(...)` and remove all references to the DocumenterLaTeX package (e.g. from `docs/Project.toml`).

### Added

* Objects that render as equations and whose `text/latex` representations are wrapped in display equation delimiters `\[ ... \]` or `$$ ... $$` are now handled correctly in the HTML output. ([#1278], [#1283], [#1426])

* The search page in the HTML output now shows the page titles in the search results. ([#1468])

* The HTML front end now respects the user's OS-level dark theme preference (determined via the `prefers-color-scheme: dark` media query). ([#1320], [#1456])

* HTML output now bails early if there are no pages, instead of throwing an `UndefRefError`. In addition, it will also warn if `index.md` is missing and it is not able to generate the main landing page (`index.html`). ([#1201], [#1491])

* `deploydocs` now prints a warning on GitHub Actions, Travis CI and Buildkite if the current branch is `main`, but `devbranch = "master`, which indicates a possible Documenter misconfiguration due to GitHub changing the default primary branch of a repository to `main`. ([#1489])

## Version [v0.25.5] - 2020-11-23

### Fixed

* In the HTML output, display equations that are wider than the page now get a scrollbar instead of overflowing. ([#1470], [#1476])

## Version [v0.25.4] - 2020-11-19

### Added

* Documenter can now deploy from Buildkite CI to GitHub Pages with `Documenter.Buildkite`. ([#1469])

* Documenter now support Azure DevOps Repos URL scheme when generating edit and source links pointing to the repository. ([#1462], [#1463], [#1471])

### Fixed

* Type aliases of `Union`s (e.g. `const MyAlias = Union{Foo,Bar}`) are now correctly listed as "Type" in docstrings. ([#1466], [#1474])

* HTMLWriter no longer prints a warning when encountering `mailto:` URLs in links. ([#1472])

## Version [v0.25.3] - 2020-10-28

### Added

* Documenter can now deploy from GitLab CI to GitHub Pages with `Documenter.GitLab`. ([#1448])

* The URL to the MathJax JS module can now be customized by passing the `url` keyword argument to the constructors (`MathJax2`, `MathJax3`). ([#1428], [#1430])

### Fixed

* `Documenter.doctest` now correctly accepts the `doctestfilters` keyword, similar to `Documenter.makedocs`. ([#1364], [#1435])

* The `Selectors.dispatch` function now uses a cache to avoid calling `subtypes` on selectors multiple times during a `makedocs` call to avoid slowdowns due to [`subtypes` being slow][julia-38079]. ([#1438], [#1440], [#1452])

## Version [v0.25.2] - 2020-08-18

### Deprecated

* The `Documenter.MathJax` type, used to specify the mathematics rendering engine in the HTML output, is now deprecated in favor of `Documenter.MathJax2`. ([#1362], [#1367])

  **For upgrading:** simply replace `MathJax` with `MathJax2`. I.e. instead of

  ```
  makedocs(
      format = Documenter.HTML(mathengine = Documenter.MathJax(...), ...),
      ...
  )
  ```

  you should have

  ```
  makedocs(
      format = Documenter.HTML(mathengine = Documenter.MathJax2(...), ...),
      ...
  )
  ```

### Added

* It is now possible to use MathJax v3 as the mathematics rendering in the HTML output. This can be done by passing `Documenter.MathJax3` as the `mathengine` keyword to `HTML`. ([#1362], [#1367])

* The deployment commits created by Documenter are no longer signed by the **@zeptodoctor** user, but rather with the non-existing `documenter@juliadocs.github.io` email address. ([#1379], [#1388])

### Fixed

* REPL doctest output lines starting with `#` right after the input code part are now correctly treated as being part of the output (unless prepended with 7 spaces, in line with the standard heuristic). ([#1369])

* Documenter now throws away the extra information from the info string of a Markdown code block (i.e. ` ```language extra-info`), to correctly determine the language, which should be a single word. ([#1392], [#1400])

* Documenter now works around a Julia 1.5.0 regression ([JuliaLang/julia#36953]) which broke doctest fixing if the original doctest output was empty. ([#1337], [#1389])

## Version [v0.25.1] - 2020-07-21

### Added

* When automatically determining the page list (i.e. `pages` is not passed to `makedocs`), Documenter now lists `index.md` before other pages. ([#1355])

* The output text boxes of `@example` blocks are now style differently from the code blocks, to make it easier to visually distinguish between the input and output. ([#1026], [#1357], [#1360])

* The generated HTML site now displays a footer by default that mentions Julia and Documenter. This can be customized or disabled by passing the `footer` keyword to `Documeter.HTML`. ([#1184], [#1365])

* Warnings that cause `makedocs` to error when `strict=true` are now printed as errors when `strict` is set to `true`. ([#1088], [#1349])

### Fixed

* In the PDF/LaTeX output, equations that use the `align` or `align*` environment are no longer further wrapped in `equation*`/`split`. ([#1368])

## Version [v0.25.0] - 2020-06-30

### Added

* When deploying with `deploydocs`, any SSH username can now be used (not just `git`), by prepending `username@` to the repository URL in the `repo` argument. ([#1285])

* The first link fragment on each page now omits the number; before the rendering resulted in: `#foobar-1`, `#foobar-2`, and now: `#foobar`, `#foobar-2`. For backwards compatibility the old fragments are also inserted such that old links will still point to the same location. ([#1292])

* When deploying on CI with `deploydocs`, the build information in the version number (i.e. what comes after `+`) is now discarded when determining the destination directory. This allows custom tags to be used to fix documentation build and deployment issues for versions that have already been registered. ([#1298])

* You can now optionally choose to push pull request preview builds to a different branch and/or different repository than the main docs builds, by setting the optional `branch_previews` and/or `repo_previews` keyword arguments to the `deploydocs` function. Also, you can now optionally choose to use a different SSH key for preview builds, by setting the optional `DOCUMENTER_KEY_PREVIEWS` environment variable; if the `DOCUMENTER_KEY_PREVIEWS` environment variable is not set, then the regular `DOCUMENTER_KEY` environment variable will be used. ([#1307], [#1310], [#1315])

* The LaTeX/PDF backend now supports the `platform="none"` keyword, which outputs only the TeX source files, rather than a compiled PDF. ([#1338], [#1339])

* Linkcheck no longer prints a warning when encountering a `302 Found` temporary redirect. ([#1344], [#1345])

### Fixed

* `Deps.pip` is again a closure and gets executed during the `deploydocs` call, not before it. ([#1240])

* Custom assets (CSS, JS etc.) for the HTML build are now again included as the very last elements in the `<head>` tag so that it would be possible to override default the default assets. ([#1328])

* Docstrings from `@autodocs` blocks are no longer sorted according to an undocumented rule where exported names should come before unexported names. Should this behavior be necessary, the `@autodocs` can be replaced by two separate blocks that use the `Public` and `Private` options to filter out the unexported or exported docstrings in the first or the second block, respectively. ([#964], [#1323])

## Version [v0.24.11] - 2020-05-06

### Fixed

* Some sections and page titles that were missing from the search results in the HTML backend now show up. ([#1311])

## Version [v0.24.10] - 2020-04-26

### Added

* The `curl` timeout when checking remote links is now configurable with the `linkcheck_timeout` keyword. ([#1057], [#1295])

### Fixed

* Special characters are now properly escaped in admonition titles in LaTeX/PDF builds and do not cause the PDF build to fail anymore. ([#1299])

## Version [v0.24.9] - 2020-04-15

### Fixed

* Canonical URLs are now properly prettified (e.g. `/path/` instead of `/path/index.html`) when using `prettyurls=true`. ([#1293])

## Version [v0.24.8] - 2020-04-13

### Added

* Non-standard admonition categories are (again) applied to the admonition `<div>` elements in HTML output (as `is-category-$category`). ([#1279], [#1280])

## Version [v0.24.7] - 2020-03-23

### Fixed

* Remove `only`, a new export from `Base` on Julia 1.4, from the JS search filter. ([#1264])

* Fix errors in LaTeX builds due to bad escaping of certain characters. ([#1118], [#1119], [#1200], [#1269])

## Version [v0.24.6] - 2020-03-12

### Added

* Reorganize some of the internal variables in Documenter's Sass sources, to make it easier to create custom themes on top of the Documenter base theme. ([#1258])

## Version [v0.24.5] - 2020-01-31

### Added

* Documenter now correctly emulates the "REPL softscope" (Julia 1.5) in REPL-style doctest blocks and `@repl` blocks. ([#1232])

## Version [v0.24.4] - 2020-01-18

### Added

* Change the inline code to less distracting black color in the HTML light theme. ([#1212], [#1222])

* Add the ability specify the `lang` attribute of the `html` tag in the HTML output, to better support documentation pages in other languages. By default Documenter now defaults to `lang="en"`. ([#1223])

## Version [v0.24.3] - 2019-12-16

### Fixed

* Fix a case where Documenter's deployment would fail due to git picking up the wrong ssh config file on non-standard systems. ([#1216])

## Version [v0.24.2] - 2019-11-26

### Other

* Improvements to logging in `deploydocs`. ([#1195])

## Version [v0.24.1] - 2019-11-25

### Fixed

* Fix a bad `mktempdir` incantation in `LaTeXWriter`. ([#1194])

## Version [v0.24.0] - 2019-11-22

### Breaking

* Documenter no longer creates a symlink between the old `latest` url to specified `devurl`. ([#1151])

  **For upgrading:** Make sure that links to the latest documentation have been updated (e.g. the package README).

* The deprecated `makedocs` keywords (`html_prettyurls`, `html_disable_git`, `html_edit_branch`, `html_canonical`, `assets`, `analytics`) have been removed. ([#1107])

  **For upgrading:** Pass the corresponding values to the `HTML` constructor when settings the `format` keyword.

### Deprecated

* The `edit_branch` keyword to `Documenter.HTML` has been deprecated in favor of the new `edit_link` keyword. As a new feature, passing `edit_link = nothing` disables the "Edit on GitHub" links altogether. ([#1173])

  **For upgrading:** If using `edit_branch = nothing`, use `edit_link = :commit` instead. If passing a `String` to `edit_branch`, pass that to `edit_link` instead.

### Added

* Documenter can now deploy preview documentation from pull requests (with head branch in the same repository, i.e. not from forks). This is enabled by passing `push_preview=true` to `deploydocs`. ([#1180])

* Deployment is now more customizable and thus not as tied to Travis CI as before. ([#1147], [#1171], [#1180])

* Documenter now has builtin support for deploying from GitHub Actions. Documenter will autodetect the running system, unless explicitly specified. ([#1144], [#1152])

* When using GitHub Actions Documenter will (try to) post a GitHub status with a link to the generated documentation. This is especially useful for pull request preview builds (see above). ([#1186])

* The Documenter HTML front end now uses [KaTeX](https://katex.org/) as the default math rendering engine. ([#1097])

  **Possible breakage:** This may break the rendering of equations that use some more esoteric features that are only supported in MathJax. It is possible to switch back to MathJax by passing `mathengine = Documenter.MathJax()` to the `HTML` constructor in the `format` keyword.

* The HTML front end generated by Documenter has been redesigned and now uses the [Bulma CSS framework](https://bulma.io/). ([#1043])

  **Possible breakage:** Packages overriding the default Documenter CSS file, relying on some external CSS or relying on Documenter's CSS working in a particular way will not build correct-looking sites. Custom themes should now be developed as Sass files and compiled together with the Documenter and Bulma Sass dependencies (under `assets/html/scss`).

* The handling of JS and CSS assets is now more customizable:

  * The `asset` function can now be used to declare remote JS and CSS assets in the `assets` keyword. ([#1108])
  * The `highlights` keyword to `HTML` can be used to declare additional languages that should be highlighted in code blocks. ([#1094])
  * It is now possible to choose between MathJax and KaTeX as the math rendering engine with the `mathengine` keyword to `HTML` and to set their configuration in the `make.jl` script directly. ([#1097])

* The JS and CSS dependencies of the front end have been updated to the latest versions. ([#1189])

* Displaying of the site name at the top of the sidebar can now be disabled by passing `sidebar_sitename = false` to `HTML` in the `format` keyword. ([#1089])

* For deployments that have Google Analytics enabled, the URL fragment (i.e. the in-page `#` target) also stored in analytics. ([#1121])

* Page titles are now boosted in the search, yielding better search results. ([#631], [#1112], [#1113])

* In the PDF/LaTeX output, images that are wider than the text are now being scaled down to text width automatically. The PDF builds now require the `adjustbox` LaTeX package to be available. ([#1137])

* If the TeX compilation fails for the PDF/LaTeX output, `makedocs` now throws an exception. ([#1166])

### Fixed

* `LaTeXWriter` now outputs valid LaTeX if an `@contents` block is nested by more than two levels, or if `@contents` or `@index` blocks do not contain any items. ([#1166])

## Version [v0.23.4] - 2019-10-09

### Fixed

* The `include` and `eval` functions are also available in `@setup` blocks now. ([#1148], [#1153])

## Version [v0.23.3] - 2019-08-28

### Fixed

* Fix file permission error when `Pkg.test`ing Documenter. ([#1115])

## Version [v0.23.2] - 2019-08-04

### Fixed

* Empty Markdown headings no longer cause Documenter to crash. ([#1081], [#1082])

## Version [v0.23.1] - 2019-07-28

### Fixed

* Documenter no longer throws an error if the provided `EditURL` argument is missing. ([#1076], [#1077])

* Non-standard Markdown AST nodes no longer cause Documenter to exit with a missing method error in doctesting and HTML output. Documenter falls back to `repr()` for such nodes. ([#1073], [#1075])

* Docstrings parsed into nested `Markdown.MD` objects are now unwrapped correctly and do not cause Documenter to crash with a missing method error anymore. The user can run into that when reusing docstrings with the `@doc @doc(foo) function bar end` pattern. ([#1075])

## Version [v0.23.0] - 2019-07-18

### Version changes

* Documenter v0.23 requires Julia v1.0. ([#1015])

### Breaking

* `DocTestSetup`s that are defined in `@meta` blocks no longer apply to doctests that are in docstrings. ([#774])

  - Specifically, the pattern where `@docs` or `@autodocs` blocks were surrounded by `@meta` blocks, setting up a shared `DocTestSetup` for many docstrings, no longer works.

  - Documenter now exports the `DocMeta` module, which provides an alternative way to add `DocTestSetup` to docstrings.

  **For upgrading:** Use `DocMeta.setdocmeta!` in `make.jl` to set up a `DocTestSetup` that applies to all the docstrings in a particular module instead and, if applicable, remove the now redundant `@meta` blocks. See the ["Setup code" section under "Doctesting"](https://documenter.juliadocs.org/v0.23/man/doctests/#Setup-Code-1) in the manual for more information.

### Added

* `makedocs` now accepts the `doctest = :only` keyword, which allows doctests to be run while most other build steps, such as rendering, are skipped. This makes it more feasible to run doctests as part of the test suite (see the manual for more information). ([#198], [#535], [#756], [#774])

* Documenter now exports the `doctest` function, which verifies the doctests in all the docstrings of a given module. This can be used to verify docstring doctests as part of test suite, or to fix doctests right in the REPL. ([#198], [#535], [#756], [#774], [#1054])

* `makedocs` now accepts the `expandfirst` argument, which allows specifying a set of pages that should be evaluated before others. ([#1027], [#1029])

* The evaluation order of pages is now fixed (unless customized with `expandfirst`). The pages are evaluated in the alphabetical order of their file paths. ([#1027], [#1029])

* The logo image in the HTML output will now always point to the first page in the navigation menu (as opposed to `index.html`, which may or may not exist). When using pretty URLs, the `index.html` part now omitted from the logo link URL. ([#1005])

* Minor changes to how doctesting errors are printed. ([#1028])

* Videos can now be included in the HTML output using the image syntax (`![]()`) if the file extension matches a known format (`.webm`, `.mp4`, `.ogg`, `.ogm`, `.ogv`, `.avi`). ([#1034])

* The PDF output now uses the DejaVu Sans  and DejaVu Sans Mono fonts to provide better Unicode coverage. ([#803], [#1066])

* **Experimental** The current working directory when evaluating `@repl` and `@example` blocks can now be set to a fixed directory by passing the `workdir` keyword to `makedocs`. _The new keyword and its behaviour are experimental and not part of the public API._ ([#1013], [#1025])

### Fixed

* The HTML output now outputs HTML files for pages that are not referenced in the `pages` keyword too (Documenter finds them according to their extension). But they do exists outside of the standard navigation hierarchy (as defined by `pages`). This fixes a bug where these pages could still be referenced by `@ref` links and `@contents` blocks, but in the HTML output, the links ended up being broken. ([#1031], [#1047])

* `makedocs` now throws an error when the format objects (`Documenter.HTML`, `LaTeX`, `Markdown`) get passed positionally. The format types are no longer subtypes of `Documenter.Plugin`. ([#1046], [#1061])

* Doctesting now also handles doctests that contain invalid syntax and throw parsing errors. ([#487], [#1062])

* Stacktraces in doctests that throw an error are now filtered more thoroughly, fixing an issue where too much of the stacktrace was included when `doctest` or `makedocs` was called from a more complicated context. ([#1062])

## Version [v0.22.6] - 2019-07-18

### Other

* Add DocStringExtensions 0.8 as an allowed dependency version. ([#1071])

## Version [v0.22.5] - 2019-07-03

### Fixed

* Fix a test dependency problem revealed by a bugfix in Julia / Pkg. ([#1037])

## Version [v0.22.4] - 2019-05-09

### Fixed

* Documenter no longer crashes if the build includes doctests from docstrings that are defined in files that do not exist on the file system (e.g. if a Julia Base docstring is included when running a non-source Julia build). ([#1002])

* URLs for files in the repository are now generated correctly when the repository is used as a Git submodule in another repository. ([#1000], [#1004])

* When checking for omitted docstrings, Documenter no longer gives "`Package.Package` missing" type false positives. ([#1009])

* `makedocs` again exits with an error if `strict=true` and there is a doctest failure. ([#1003], [#1014])

## Version [v0.22.3] - 2019-04-12

### Fixed

* Fixed filepaths for images included in the .tex file for PDF output on Windows. ([#999])

## Version [v0.22.2] - 2019-04-05

### Fixed

* Error reporting for meta-blocks now handles missing files gracefully instead of throwing. ([#996])

### Added

* The `sitename` keyword argument to `deploydocs`, which is required for the default HTML output, is now properly documented. ([#995])

## Version [v0.22.1] - 2019-03-30

### Fixed

* Fixed a world-age related bug in doctests. ([#994])

## Version [v0.22.0] - 2019-03-28

### Deprecated

* The `assets` and `analytics` arguments to `makedocs` have been deprecated in favor of the corresponding arguments of the `Documenter.HTML` format plugin. ([#953])

  **For upgrading:** pass the corresponding arguments with the `Documenter.HTML` plugin instead. E.g. instead of

  ```
  makedocs(
      assets = ..., analytics = ...,
      ...
  )
  ```

  you should have

  ```
  makedocs(
      format = Documenter.HTML(assets = ..., analytics = ...),
      ...
  )
  ```

  _**Note:** It is technically possible to specify the same argument twice with different values by passing both variants. In that case the value passed to `makedocs` takes precedence._

### Added

* Documentation is no longer deployed on Travis CI cron jobs. ([#917])

* Log messages from failed `@meta`, `@docs`, `@autodocs`,
  `@eval`, `@example` and `@setup` blocks now include information about the source location
  of the block. ([#929])

* Docstrings from `@docs`-blocks are now included in the
  rendered docs even if some part(s) of the block failed. ([#928], [#935])

* The Markdown and LaTeX output writers can now handle multimedia
  output, such as images, from `@example` blocks. All the writers now also handle `text/markdown`
  output, which is preferred over `text/plain` if available. ([#938], [#948])

* The HTML output now also supports SVG, WebP, GIF and JPEG logos. ([#953])

* Reporting of failed doctests are now using the logging
  system to be consistent with the rest of Documenter's output. ([#958])

* The construction of the search index in the HTML output has been refactored to make it easier to use with other search backends in the future. The structure of the generated search index has also been modified, which can yield slightly different search results. Documenter now depends on the lightweight [JSON.jl](https://github.com/JuliaIO/JSON.jl) package. ([#966])

* Docstrings that begin with an indented code block (such as a function signature) now have that block highlighted as Julia code by default.
  This behaviour can be disabled by passing `highlightsig=false` to `makedocs`. ([#980])

### Fixed

* Paths in `include` calls in `@eval`, `@example`, `@repl` and `jldoctest`
  blocks are now interpreted to be relative `pwd`, which is set to the output directory of the
  resulting file. ([#941])

* `deploydocs` and `git_push` now support non-github repos correctly and work when the `.ssh` directory does not already exist or the working directory contains spaces. ([#971])

* Tables now honor column alignment in the HTML output. If a column does not explicitly specify its alignment, the parser defaults to it being right-aligned, whereas previously all cells were left-aligned. ([#511], [#989])

* Code lines ending with `# hide` are now properly hidden for CRLF inputs. ([#991])

## Version [v0.21.5] - 2019-02-22

### Fixed

* Deprecation warnings for `format` now get printed correctly when multiple formats are passed as a `Vector`. ([#967])

## Version [v0.21.4] - 2019-02-16

### Fixed

* A bug in `jldoctest`-blocks that, in rare cases, resulted in
  wrong output has been fixed. ([#959], [#960])

## Version [v0.21.3] - 2019-02-12

### Security

* The lunr.js and lodash JavaScript dependencies have been updated to their latest patch versions (from 2.3.1 to 2.3.5 and 4.17.4 to 4.17.11, respectively).
  This is in response to a vulnerability in lodash <4.17.11 ([CVE-2018-16487](https://nvd.nist.gov/vuln/detail/CVE-2018-16487)). ([#946])

## Version [v0.21.2] - 2019-02-06

### Fixed

* `linkcheck` now handles servers that do not support `HEAD` requests
  and properly checks for status codes of FTP responses. ([#934])

## Version [v0.21.1] - 2019-01-29

### Fixed

* `@repl` blocks now work correctly together with quoted
  expressions. ([#923], [#926])

* `@example`, `@repl` and `@eval` blocks now handle reserved words,
  e.g. `try`/`catch`, correctly. ([#886], [#927])

## Version [v0.21.0] - 2018-12-11

### Deprecated

* The symbol values to the `format` argument of `makedocs` (`:html`, `:markdown`, `:latex`) have been deprecated in favor of the `Documenter.HTML`, `Markdown` and `LaTeX`
  objects. The `Markdown` and `LaTeX` types are exported from the [DocumenterMarkdown](https://github.com/JuliaDocs/DocumenterMarkdown.jl) and [DocumenterLaTeX](https://github.com/JuliaDocs/DocumenterLaTeX.jl) packages,
  respectively. HTML output is still the default. ([#891])

  **For upgrading:** If you don't specify `format` (i.e. you rely on the default) you don't have to do anything.
  Otherwise update calls to `makedocs` to use struct instances instead of symbols, e.g.

  ```
  makedocs(
      format = :markdown
  )
  ```

  should be changed to

  ```
  using DocumenterMarkdown
  makedocs(
      format = Markdown()
  )
  ```

* The `html_prettyurls`, `html_canonical`, `html_disable_git` and `html_edit_branch` arguments to `makedocs` have been deprecated in favor of the corresponding arguments of the `Documenter.HTML` format plugin. ([#864], [#891])

  **For upgrading:** pass the corresponding arguments with the `Documenter.HTML` plugin instead. E.g. instead of

  ```
  makedocs(
      html_prettyurls = ..., html_canonical = ...,
      ...
  )
  ```

  you should have

  ```
  makedocs(
      format = Documenter.HTML(prettyurls = ..., canonical = ...),
      ...
  )
  ```

  _**Note:** It is technically possible to specify the same argument twice with different values by passing both variants. In that case the value to the deprecated `html_*` variant takes precedence._

### Added

* Packages extending Documenter can now define subtypes of `Documenter.Plugin`,
  which can be passed to `makedocs` as positional arguments to pass options to the extensions. ([#864])

* `@autodocs` blocks now support the `Filter` keyword, which allows passing a user-defined function that will filter the methods spliced in by the at-autodocs block. ([#885])

* `linkcheck` now supports checking URLs using the FTP protocol. ([#879])

* Build output logging has been improved and switched to the logging macros from `Base`. ([#876])

* The default `documenter.sty` LaTeX preamble now include `\usepackage{graphicx}`. ([#898])

* `deploydocs` is now more helpful when it fails to interpret `DOCUMENTER_KEY`. It now also uses the `BatchMode` SSH option and throws an error instead of asking for a passphrase and timing out the Travis build when `DOCUMENTER_KEY` is broken. ([#697], [#907])

* `deploydocs` now have a `forcepush` keyword argument that can be used to
  force-push the built documentation instead of adding a new commit. ([#905])

## Version [v0.20.0] - 2018-10-27

### Version changes

* Documenter v0.20 requires at least Julia v0.7. ([#795])

### Breaking

* Documentation deployment via the `deploydocs` function has changed considerably.

  - The user-facing directories (URLs) of different versions and what gets displayed in the version selector have changed. By default, Documenter now creates the `stable/` directory (as before) and a directory for every minor version (`vX.Y/`). The `release-X.Y` directories are no longer created. ([#706], [#813], [#817])

    Technically, Documenter now deploys actual files only to `dev/` and `vX.Y.Z/` directories. The directories (URLs) that change from version to version (e.g. `latest/`, `vX.Y`) are implemented as symlinks on the `gh-pages` branch.

    The version selector will only display `vX.Y/`, `stable/` and `dev/` directories by default. This behavior can be customized with the `versions` keyword of `deploydocs`.

  - Documentation from the development branch (e.g. `master`) now deploys to `dev/` by default (instead of `latest/`). This can be customized with the `devurl` keyword. ([#802])

  - The `latest` keyword to `deploydocs` has been deprecated and renamed to `devbranch`. ([#802])

  - The `julia` and `osname` keywords to `deploydocs` are now deprecated. ([#816])

  - The default values of the `target`, `deps` and `make` keywords to `deploydocs` have been changed. See the default format change below for more information. ([#826])

  **For upgrading:**

  - If you are using the `latest` keyword, then just use `devbranch` with the same value instead.

  - Update links that point to `latest/` to point to `dev/` instead (e.g. in the README).

  - Remove any links to the `release-X.Y` branches and remove the directories from your `gh-pages` branch.

  - The operating system and Julia version should be specified in the Travis build stage configuration (via `julia:` and `os:` options, see "Hosting Documentation" in the manual for more details) or by checking the `TRAVIS_JULIA_VERSION` and `TRAVIS_OS_NAME` environment variables in `make.jl` yourself.

* `makedocs` will now build Documenter's native HTML output by default and `deploydocs`' defaults now assume the HTML output. ([#826])

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

* "Pretty URLs" are enabled by default now for the HTML output. The default value of the `html_prettyurls` has been changed to `true`.

  For a page `foo/page.md` Documenter now generates `foo/page/index.html`, instead of `foo/page.html`.
  On GitHub pages deployments it means that your URLs look like  `foo/page/` instead of `foo/page.html`.

  For local builds you should explicitly set `html_prettyurls = false`.

  **For upgrading:** If you wish to retain the old behavior, set `html_prettyurls = false` in `makedocs`. If you already set `html_prettyurls`, you do not need to change anything.

* The `Travis.genkeys` and `Documenter.generate` functions have been moved to a separate [DocumenterTools.jl package](https://github.com/JuliaDocs/DocumenterTools.jl). ([#789])

### Deprecated

* The Markdown/MkDocs (`format = :markdown`) and PDF/LaTeX (`format = :latex`) outputs now require an external package to be loaded ([DocumenterMarkdown](https://github.com/JuliaDocs/DocumenterMarkdown.jl) and [DocumenterLaTeX](https://github.com/JuliaDocs/DocumenterLaTeX.jl), respectively). ([#833])

  **For upgrading:** Make sure that the respective extra package is installed and then just add `using DocumenterMarkdown` or `using DocumenterLaTeX` to `make.jl`.

### Added

* If Documenter is not able to determine which Git hosting service is being used to host the source, the "Edit on XXX" links become "Edit source" with a generic icon. ([#804])

* The at-blocks now support `MIME"text/html"` rendering of objects (e.g. for interactive plots). I.e. if a type has `show(io, ::MIME"text/html", x)` defined, Documenter now uses that when rendering the objects in the document. ([#764])

* Addeds to the sidebar. When loading a page, the sidebar will jump to the current page now. Also, the scrollbar in WebKit-based browsers look less intrusive now. ([#792], [#854], [#863])

* Minor style enhancements to admonitions. ([#841])

### Fixed

* The at-blocks that execute code can now handle `include` statements. ([#793], [#794])

* At-docs blocks no longer give an error when containing empty lines. ([#823], [#824])


<!-- Links to pull requests/issues/etc. generated by docs/changelog.jl -->

[v0.20.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.20.0
[v0.21.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.0
[v0.21.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.1
[v0.21.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.2
[v0.21.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.3
[v0.21.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.4
[v0.21.5]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.21.5
[v0.22.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.0
[v0.22.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.1
[v0.22.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.2
[v0.22.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.3
[v0.22.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.4
[v0.22.5]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.5
[v0.22.6]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.22.6
[v0.23.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.23.0
[v0.23.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.23.1
[v0.23.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.23.2
[v0.23.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.23.3
[v0.23.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.23.4
[v0.24.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.0
[v0.24.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.1
[v0.24.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.2
[v0.24.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.3
[v0.24.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.4
[v0.24.5]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.5
[v0.24.6]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.6
[v0.24.7]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.7
[v0.24.8]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.8
[v0.24.9]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.9
[v0.24.10]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.10
[v0.24.11]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.24.11
[v0.25.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.0
[v0.25.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.1
[v0.25.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.2
[v0.25.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.3
[v0.25.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.4
[v0.25.5]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.25.5
[v0.26.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.26.0
[v0.26.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.26.1
[v0.26.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.26.2
[v0.26.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.26.3
[v0.27.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.0
[v0.27.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.1
[v0.27.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.2
[v0.27.3]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.3
[v0.27.4]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.4
[v0.27.5]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.5
[v0.27.6]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.6
[v0.27.7]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.7
[v0.27.8]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.8
[v0.27.9]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.9
[v0.27.10]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.10
[v0.27.11]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.11
[v0.27.12]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.12
[v0.27.13]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.13
[v0.27.14]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.14
[v0.27.15]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.15
[v0.27.16]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.16
[v0.27.17]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.17
[v0.27.18]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.18
[v0.27.19]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.19
[v0.27.20]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.20
[v0.27.21]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.21
[v0.27.22]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.22
[v0.27.23]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.23
[v0.27.24]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.24
[v0.27.25]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.25
[v1.0.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.0.0
[v1.0.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.0.1
[v1.1.0]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.1.0
[v1.1.1]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.1.1
[v1.1.2]: https://github.com/JuliaDocs/Documenter.jl/releases/tag/v1.1.2
[#198]: https://github.com/JuliaDocs/Documenter.jl/issues/198
[#245]: https://github.com/JuliaDocs/Documenter.jl/issues/245
[#487]: https://github.com/JuliaDocs/Documenter.jl/issues/487
[#491]: https://github.com/JuliaDocs/Documenter.jl/issues/491
[#505]: https://github.com/JuliaDocs/Documenter.jl/issues/505
[#511]: https://github.com/JuliaDocs/Documenter.jl/issues/511
[#535]: https://github.com/JuliaDocs/Documenter.jl/issues/535
[#618]: https://github.com/JuliaDocs/Documenter.jl/issues/618
[#631]: https://github.com/JuliaDocs/Documenter.jl/issues/631
[#697]: https://github.com/JuliaDocs/Documenter.jl/issues/697
[#706]: https://github.com/JuliaDocs/Documenter.jl/issues/706
[#744]: https://github.com/JuliaDocs/Documenter.jl/issues/744
[#756]: https://github.com/JuliaDocs/Documenter.jl/issues/756
[#764]: https://github.com/JuliaDocs/Documenter.jl/issues/764
[#774]: https://github.com/JuliaDocs/Documenter.jl/issues/774
[#781]: https://github.com/JuliaDocs/Documenter.jl/issues/781
[#789]: https://github.com/JuliaDocs/Documenter.jl/issues/789
[#792]: https://github.com/JuliaDocs/Documenter.jl/issues/792
[#793]: https://github.com/JuliaDocs/Documenter.jl/issues/793
[#794]: https://github.com/JuliaDocs/Documenter.jl/issues/794
[#795]: https://github.com/JuliaDocs/Documenter.jl/issues/795
[#802]: https://github.com/JuliaDocs/Documenter.jl/issues/802
[#803]: https://github.com/JuliaDocs/Documenter.jl/issues/803
[#804]: https://github.com/JuliaDocs/Documenter.jl/issues/804
[#813]: https://github.com/JuliaDocs/Documenter.jl/issues/813
[#816]: https://github.com/JuliaDocs/Documenter.jl/issues/816
[#817]: https://github.com/JuliaDocs/Documenter.jl/issues/817
[#823]: https://github.com/JuliaDocs/Documenter.jl/issues/823
[#824]: https://github.com/JuliaDocs/Documenter.jl/issues/824
[#826]: https://github.com/JuliaDocs/Documenter.jl/issues/826
[#833]: https://github.com/JuliaDocs/Documenter.jl/issues/833
[#841]: https://github.com/JuliaDocs/Documenter.jl/issues/841
[#854]: https://github.com/JuliaDocs/Documenter.jl/issues/854
[#863]: https://github.com/JuliaDocs/Documenter.jl/issues/863
[#864]: https://github.com/JuliaDocs/Documenter.jl/issues/864
[#876]: https://github.com/JuliaDocs/Documenter.jl/issues/876
[#879]: https://github.com/JuliaDocs/Documenter.jl/issues/879
[#885]: https://github.com/JuliaDocs/Documenter.jl/issues/885
[#886]: https://github.com/JuliaDocs/Documenter.jl/issues/886
[#890]: https://github.com/JuliaDocs/Documenter.jl/issues/890
[#891]: https://github.com/JuliaDocs/Documenter.jl/issues/891
[#898]: https://github.com/JuliaDocs/Documenter.jl/issues/898
[#905]: https://github.com/JuliaDocs/Documenter.jl/issues/905
[#907]: https://github.com/JuliaDocs/Documenter.jl/issues/907
[#917]: https://github.com/JuliaDocs/Documenter.jl/issues/917
[#923]: https://github.com/JuliaDocs/Documenter.jl/issues/923
[#926]: https://github.com/JuliaDocs/Documenter.jl/issues/926
[#927]: https://github.com/JuliaDocs/Documenter.jl/issues/927
[#928]: https://github.com/JuliaDocs/Documenter.jl/issues/928
[#929]: https://github.com/JuliaDocs/Documenter.jl/issues/929
[#934]: https://github.com/JuliaDocs/Documenter.jl/issues/934
[#935]: https://github.com/JuliaDocs/Documenter.jl/issues/935
[#937]: https://github.com/JuliaDocs/Documenter.jl/issues/937
[#938]: https://github.com/JuliaDocs/Documenter.jl/issues/938
[#941]: https://github.com/JuliaDocs/Documenter.jl/issues/941
[#946]: https://github.com/JuliaDocs/Documenter.jl/issues/946
[#948]: https://github.com/JuliaDocs/Documenter.jl/issues/948
[#953]: https://github.com/JuliaDocs/Documenter.jl/issues/953
[#958]: https://github.com/JuliaDocs/Documenter.jl/issues/958
[#959]: https://github.com/JuliaDocs/Documenter.jl/issues/959
[#960]: https://github.com/JuliaDocs/Documenter.jl/issues/960
[#964]: https://github.com/JuliaDocs/Documenter.jl/issues/964
[#966]: https://github.com/JuliaDocs/Documenter.jl/issues/966
[#967]: https://github.com/JuliaDocs/Documenter.jl/issues/967
[#971]: https://github.com/JuliaDocs/Documenter.jl/issues/971
[#974]: https://github.com/JuliaDocs/Documenter.jl/issues/974
[#980]: https://github.com/JuliaDocs/Documenter.jl/issues/980
[#989]: https://github.com/JuliaDocs/Documenter.jl/issues/989
[#991]: https://github.com/JuliaDocs/Documenter.jl/issues/991
[#994]: https://github.com/JuliaDocs/Documenter.jl/issues/994
[#995]: https://github.com/JuliaDocs/Documenter.jl/issues/995
[#996]: https://github.com/JuliaDocs/Documenter.jl/issues/996
[#999]: https://github.com/JuliaDocs/Documenter.jl/issues/999
[#1000]: https://github.com/JuliaDocs/Documenter.jl/issues/1000
[#1002]: https://github.com/JuliaDocs/Documenter.jl/issues/1002
[#1003]: https://github.com/JuliaDocs/Documenter.jl/issues/1003
[#1004]: https://github.com/JuliaDocs/Documenter.jl/issues/1004
[#1005]: https://github.com/JuliaDocs/Documenter.jl/issues/1005
[#1009]: https://github.com/JuliaDocs/Documenter.jl/issues/1009
[#1013]: https://github.com/JuliaDocs/Documenter.jl/issues/1013
[#1014]: https://github.com/JuliaDocs/Documenter.jl/issues/1014
[#1015]: https://github.com/JuliaDocs/Documenter.jl/issues/1015
[#1025]: https://github.com/JuliaDocs/Documenter.jl/issues/1025
[#1026]: https://github.com/JuliaDocs/Documenter.jl/issues/1026
[#1027]: https://github.com/JuliaDocs/Documenter.jl/issues/1027
[#1028]: https://github.com/JuliaDocs/Documenter.jl/issues/1028
[#1029]: https://github.com/JuliaDocs/Documenter.jl/issues/1029
[#1031]: https://github.com/JuliaDocs/Documenter.jl/issues/1031
[#1034]: https://github.com/JuliaDocs/Documenter.jl/issues/1034
[#1037]: https://github.com/JuliaDocs/Documenter.jl/issues/1037
[#1043]: https://github.com/JuliaDocs/Documenter.jl/issues/1043
[#1046]: https://github.com/JuliaDocs/Documenter.jl/issues/1046
[#1047]: https://github.com/JuliaDocs/Documenter.jl/issues/1047
[#1054]: https://github.com/JuliaDocs/Documenter.jl/issues/1054
[#1057]: https://github.com/JuliaDocs/Documenter.jl/issues/1057
[#1061]: https://github.com/JuliaDocs/Documenter.jl/issues/1061
[#1062]: https://github.com/JuliaDocs/Documenter.jl/issues/1062
[#1066]: https://github.com/JuliaDocs/Documenter.jl/issues/1066
[#1071]: https://github.com/JuliaDocs/Documenter.jl/issues/1071
[#1073]: https://github.com/JuliaDocs/Documenter.jl/issues/1073
[#1075]: https://github.com/JuliaDocs/Documenter.jl/issues/1075
[#1076]: https://github.com/JuliaDocs/Documenter.jl/issues/1076
[#1077]: https://github.com/JuliaDocs/Documenter.jl/issues/1077
[#1079]: https://github.com/JuliaDocs/Documenter.jl/issues/1079
[#1081]: https://github.com/JuliaDocs/Documenter.jl/issues/1081
[#1082]: https://github.com/JuliaDocs/Documenter.jl/issues/1082
[#1088]: https://github.com/JuliaDocs/Documenter.jl/issues/1088
[#1089]: https://github.com/JuliaDocs/Documenter.jl/issues/1089
[#1094]: https://github.com/JuliaDocs/Documenter.jl/issues/1094
[#1097]: https://github.com/JuliaDocs/Documenter.jl/issues/1097
[#1107]: https://github.com/JuliaDocs/Documenter.jl/issues/1107
[#1108]: https://github.com/JuliaDocs/Documenter.jl/issues/1108
[#1112]: https://github.com/JuliaDocs/Documenter.jl/issues/1112
[#1113]: https://github.com/JuliaDocs/Documenter.jl/issues/1113
[#1115]: https://github.com/JuliaDocs/Documenter.jl/issues/1115
[#1118]: https://github.com/JuliaDocs/Documenter.jl/issues/1118
[#1119]: https://github.com/JuliaDocs/Documenter.jl/issues/1119
[#1121]: https://github.com/JuliaDocs/Documenter.jl/issues/1121
[#1137]: https://github.com/JuliaDocs/Documenter.jl/issues/1137
[#1144]: https://github.com/JuliaDocs/Documenter.jl/issues/1144
[#1147]: https://github.com/JuliaDocs/Documenter.jl/issues/1147
[#1148]: https://github.com/JuliaDocs/Documenter.jl/issues/1148
[#1151]: https://github.com/JuliaDocs/Documenter.jl/issues/1151
[#1152]: https://github.com/JuliaDocs/Documenter.jl/issues/1152
[#1153]: https://github.com/JuliaDocs/Documenter.jl/issues/1153
[#1166]: https://github.com/JuliaDocs/Documenter.jl/issues/1166
[#1171]: https://github.com/JuliaDocs/Documenter.jl/issues/1171
[#1173]: https://github.com/JuliaDocs/Documenter.jl/issues/1173
[#1180]: https://github.com/JuliaDocs/Documenter.jl/issues/1180
[#1184]: https://github.com/JuliaDocs/Documenter.jl/issues/1184
[#1186]: https://github.com/JuliaDocs/Documenter.jl/issues/1186
[#1189]: https://github.com/JuliaDocs/Documenter.jl/issues/1189
[#1192]: https://github.com/JuliaDocs/Documenter.jl/issues/1192
[#1194]: https://github.com/JuliaDocs/Documenter.jl/issues/1194
[#1195]: https://github.com/JuliaDocs/Documenter.jl/issues/1195
[#1200]: https://github.com/JuliaDocs/Documenter.jl/issues/1200
[#1201]: https://github.com/JuliaDocs/Documenter.jl/issues/1201
[#1212]: https://github.com/JuliaDocs/Documenter.jl/issues/1212
[#1216]: https://github.com/JuliaDocs/Documenter.jl/issues/1216
[#1222]: https://github.com/JuliaDocs/Documenter.jl/issues/1222
[#1223]: https://github.com/JuliaDocs/Documenter.jl/issues/1223
[#1232]: https://github.com/JuliaDocs/Documenter.jl/issues/1232
[#1234]: https://github.com/JuliaDocs/Documenter.jl/issues/1234
[#1240]: https://github.com/JuliaDocs/Documenter.jl/issues/1240
[#1254]: https://github.com/JuliaDocs/Documenter.jl/issues/1254
[#1258]: https://github.com/JuliaDocs/Documenter.jl/issues/1258
[#1264]: https://github.com/JuliaDocs/Documenter.jl/issues/1264
[#1269]: https://github.com/JuliaDocs/Documenter.jl/issues/1269
[#1271]: https://github.com/JuliaDocs/Documenter.jl/issues/1271
[#1278]: https://github.com/JuliaDocs/Documenter.jl/issues/1278
[#1279]: https://github.com/JuliaDocs/Documenter.jl/issues/1279
[#1280]: https://github.com/JuliaDocs/Documenter.jl/issues/1280
[#1283]: https://github.com/JuliaDocs/Documenter.jl/issues/1283
[#1285]: https://github.com/JuliaDocs/Documenter.jl/issues/1285
[#1291]: https://github.com/JuliaDocs/Documenter.jl/issues/1291
[#1292]: https://github.com/JuliaDocs/Documenter.jl/issues/1292
[#1293]: https://github.com/JuliaDocs/Documenter.jl/issues/1293
[#1295]: https://github.com/JuliaDocs/Documenter.jl/issues/1295
[#1298]: https://github.com/JuliaDocs/Documenter.jl/issues/1298
[#1299]: https://github.com/JuliaDocs/Documenter.jl/issues/1299
[#1302]: https://github.com/JuliaDocs/Documenter.jl/issues/1302
[#1307]: https://github.com/JuliaDocs/Documenter.jl/issues/1307
[#1310]: https://github.com/JuliaDocs/Documenter.jl/issues/1310
[#1311]: https://github.com/JuliaDocs/Documenter.jl/issues/1311
[#1312]: https://github.com/JuliaDocs/Documenter.jl/issues/1312
[#1315]: https://github.com/JuliaDocs/Documenter.jl/issues/1315
[#1320]: https://github.com/JuliaDocs/Documenter.jl/issues/1320
[#1321]: https://github.com/JuliaDocs/Documenter.jl/issues/1321
[#1323]: https://github.com/JuliaDocs/Documenter.jl/issues/1323
[#1328]: https://github.com/JuliaDocs/Documenter.jl/issues/1328
[#1337]: https://github.com/JuliaDocs/Documenter.jl/issues/1337
[#1338]: https://github.com/JuliaDocs/Documenter.jl/issues/1338
[#1339]: https://github.com/JuliaDocs/Documenter.jl/issues/1339
[#1342]: https://github.com/JuliaDocs/Documenter.jl/issues/1342
[#1344]: https://github.com/JuliaDocs/Documenter.jl/issues/1344
[#1345]: https://github.com/JuliaDocs/Documenter.jl/issues/1345
[#1349]: https://github.com/JuliaDocs/Documenter.jl/issues/1349
[#1355]: https://github.com/JuliaDocs/Documenter.jl/issues/1355
[#1357]: https://github.com/JuliaDocs/Documenter.jl/issues/1357
[#1360]: https://github.com/JuliaDocs/Documenter.jl/issues/1360
[#1362]: https://github.com/JuliaDocs/Documenter.jl/issues/1362
[#1364]: https://github.com/JuliaDocs/Documenter.jl/issues/1364
[#1365]: https://github.com/JuliaDocs/Documenter.jl/issues/1365
[#1367]: https://github.com/JuliaDocs/Documenter.jl/issues/1367
[#1368]: https://github.com/JuliaDocs/Documenter.jl/issues/1368
[#1369]: https://github.com/JuliaDocs/Documenter.jl/issues/1369
[#1379]: https://github.com/JuliaDocs/Documenter.jl/issues/1379
[#1388]: https://github.com/JuliaDocs/Documenter.jl/issues/1388
[#1389]: https://github.com/JuliaDocs/Documenter.jl/issues/1389
[#1392]: https://github.com/JuliaDocs/Documenter.jl/issues/1392
[#1393]: https://github.com/JuliaDocs/Documenter.jl/issues/1393
[#1400]: https://github.com/JuliaDocs/Documenter.jl/issues/1400
[#1426]: https://github.com/JuliaDocs/Documenter.jl/issues/1426
[#1428]: https://github.com/JuliaDocs/Documenter.jl/issues/1428
[#1430]: https://github.com/JuliaDocs/Documenter.jl/issues/1430
[#1435]: https://github.com/JuliaDocs/Documenter.jl/issues/1435
[#1437]: https://github.com/JuliaDocs/Documenter.jl/issues/1437
[#1438]: https://github.com/JuliaDocs/Documenter.jl/issues/1438
[#1440]: https://github.com/JuliaDocs/Documenter.jl/issues/1440
[#1441]: https://github.com/JuliaDocs/Documenter.jl/issues/1441
[#1443]: https://github.com/JuliaDocs/Documenter.jl/issues/1443
[#1448]: https://github.com/JuliaDocs/Documenter.jl/issues/1448
[#1449]: https://github.com/JuliaDocs/Documenter.jl/issues/1449
[#1452]: https://github.com/JuliaDocs/Documenter.jl/issues/1452
[#1456]: https://github.com/JuliaDocs/Documenter.jl/issues/1456
[#1462]: https://github.com/JuliaDocs/Documenter.jl/issues/1462
[#1463]: https://github.com/JuliaDocs/Documenter.jl/issues/1463
[#1466]: https://github.com/JuliaDocs/Documenter.jl/issues/1466
[#1468]: https://github.com/JuliaDocs/Documenter.jl/issues/1468
[#1469]: https://github.com/JuliaDocs/Documenter.jl/issues/1469
[#1470]: https://github.com/JuliaDocs/Documenter.jl/issues/1470
[#1471]: https://github.com/JuliaDocs/Documenter.jl/issues/1471
[#1472]: https://github.com/JuliaDocs/Documenter.jl/issues/1472
[#1474]: https://github.com/JuliaDocs/Documenter.jl/issues/1474
[#1476]: https://github.com/JuliaDocs/Documenter.jl/issues/1476
[#1489]: https://github.com/JuliaDocs/Documenter.jl/issues/1489
[#1491]: https://github.com/JuliaDocs/Documenter.jl/issues/1491
[#1493]: https://github.com/JuliaDocs/Documenter.jl/issues/1493
[#1497]: https://github.com/JuliaDocs/Documenter.jl/issues/1497
[#1503]: https://github.com/JuliaDocs/Documenter.jl/issues/1503
[#1510]: https://github.com/JuliaDocs/Documenter.jl/issues/1510
[#1511]: https://github.com/JuliaDocs/Documenter.jl/issues/1511
[#1513]: https://github.com/JuliaDocs/Documenter.jl/issues/1513
[#1516]: https://github.com/JuliaDocs/Documenter.jl/issues/1516
[#1518]: https://github.com/JuliaDocs/Documenter.jl/issues/1518
[#1519]: https://github.com/JuliaDocs/Documenter.jl/issues/1519
[#1520]: https://github.com/JuliaDocs/Documenter.jl/issues/1520
[#1526]: https://github.com/JuliaDocs/Documenter.jl/issues/1526
[#1527]: https://github.com/JuliaDocs/Documenter.jl/issues/1527
[#1529]: https://github.com/JuliaDocs/Documenter.jl/issues/1529
[#1531]: https://github.com/JuliaDocs/Documenter.jl/issues/1531
[#1533]: https://github.com/JuliaDocs/Documenter.jl/issues/1533
[#1534]: https://github.com/JuliaDocs/Documenter.jl/issues/1534
[#1536]: https://github.com/JuliaDocs/Documenter.jl/issues/1536
[#1537]: https://github.com/JuliaDocs/Documenter.jl/issues/1537
[#1538]: https://github.com/JuliaDocs/Documenter.jl/issues/1538
[#1540]: https://github.com/JuliaDocs/Documenter.jl/issues/1540
[#1549]: https://github.com/JuliaDocs/Documenter.jl/issues/1549
[#1551]: https://github.com/JuliaDocs/Documenter.jl/issues/1551
[#1553]: https://github.com/JuliaDocs/Documenter.jl/issues/1553
[#1554]: https://github.com/JuliaDocs/Documenter.jl/issues/1554
[#1556]: https://github.com/JuliaDocs/Documenter.jl/issues/1556
[#1557]: https://github.com/JuliaDocs/Documenter.jl/issues/1557
[#1559]: https://github.com/JuliaDocs/Documenter.jl/issues/1559
[#1561]: https://github.com/JuliaDocs/Documenter.jl/issues/1561
[#1567]: https://github.com/JuliaDocs/Documenter.jl/issues/1567
[#1568]: https://github.com/JuliaDocs/Documenter.jl/issues/1568
[#1569]: https://github.com/JuliaDocs/Documenter.jl/issues/1569
[#1570]: https://github.com/JuliaDocs/Documenter.jl/issues/1570
[#1575]: https://github.com/JuliaDocs/Documenter.jl/issues/1575
[#1577]: https://github.com/JuliaDocs/Documenter.jl/issues/1577
[#1590]: https://github.com/JuliaDocs/Documenter.jl/issues/1590
[#1594]: https://github.com/JuliaDocs/Documenter.jl/issues/1594
[#1595]: https://github.com/JuliaDocs/Documenter.jl/issues/1595
[#1596]: https://github.com/JuliaDocs/Documenter.jl/issues/1596
[#1602]: https://github.com/JuliaDocs/Documenter.jl/issues/1602
[#1604]: https://github.com/JuliaDocs/Documenter.jl/issues/1604
[#1609]: https://github.com/JuliaDocs/Documenter.jl/issues/1609
[#1610]: https://github.com/JuliaDocs/Documenter.jl/issues/1610
[#1611]: https://github.com/JuliaDocs/Documenter.jl/issues/1611
[#1615]: https://github.com/JuliaDocs/Documenter.jl/issues/1615
[#1616]: https://github.com/JuliaDocs/Documenter.jl/issues/1616
[#1617]: https://github.com/JuliaDocs/Documenter.jl/issues/1617
[#1625]: https://github.com/JuliaDocs/Documenter.jl/issues/1625
[#1627]: https://github.com/JuliaDocs/Documenter.jl/issues/1627
[#1628]: https://github.com/JuliaDocs/Documenter.jl/issues/1628
[#1629]: https://github.com/JuliaDocs/Documenter.jl/issues/1629
[#1633]: https://github.com/JuliaDocs/Documenter.jl/issues/1633
[#1634]: https://github.com/JuliaDocs/Documenter.jl/issues/1634
[#1639]: https://github.com/JuliaDocs/Documenter.jl/issues/1639
[#1641]: https://github.com/JuliaDocs/Documenter.jl/issues/1641
[#1645]: https://github.com/JuliaDocs/Documenter.jl/issues/1645
[#1647]: https://github.com/JuliaDocs/Documenter.jl/issues/1647
[#1649]: https://github.com/JuliaDocs/Documenter.jl/issues/1649
[#1655]: https://github.com/JuliaDocs/Documenter.jl/issues/1655
[#1657]: https://github.com/JuliaDocs/Documenter.jl/issues/1657
[#1658]: https://github.com/JuliaDocs/Documenter.jl/issues/1658
[#1661]: https://github.com/JuliaDocs/Documenter.jl/issues/1661
[#1665]: https://github.com/JuliaDocs/Documenter.jl/issues/1665
[#1667]: https://github.com/JuliaDocs/Documenter.jl/issues/1667
[#1673]: https://github.com/JuliaDocs/Documenter.jl/issues/1673
[#1687]: https://github.com/JuliaDocs/Documenter.jl/issues/1687
[#1689]: https://github.com/JuliaDocs/Documenter.jl/issues/1689
[#1691]: https://github.com/JuliaDocs/Documenter.jl/issues/1691
[#1693]: https://github.com/JuliaDocs/Documenter.jl/issues/1693
[#1695]: https://github.com/JuliaDocs/Documenter.jl/issues/1695
[#1696]: https://github.com/JuliaDocs/Documenter.jl/issues/1696
[#1698]: https://github.com/JuliaDocs/Documenter.jl/issues/1698
[#1699]: https://github.com/JuliaDocs/Documenter.jl/issues/1699
[#1704]: https://github.com/JuliaDocs/Documenter.jl/issues/1704
[#1706]: https://github.com/JuliaDocs/Documenter.jl/issues/1706
[#1709]: https://github.com/JuliaDocs/Documenter.jl/issues/1709
[#1716]: https://github.com/JuliaDocs/Documenter.jl/issues/1716
[#1727]: https://github.com/JuliaDocs/Documenter.jl/issues/1727
[#1728]: https://github.com/JuliaDocs/Documenter.jl/issues/1728
[#1743]: https://github.com/JuliaDocs/Documenter.jl/issues/1743
[#1745]: https://github.com/JuliaDocs/Documenter.jl/issues/1745
[#1746]: https://github.com/JuliaDocs/Documenter.jl/issues/1746
[#1748]: https://github.com/JuliaDocs/Documenter.jl/issues/1748
[#1750]: https://github.com/JuliaDocs/Documenter.jl/issues/1750
[#1751]: https://github.com/JuliaDocs/Documenter.jl/issues/1751
[#1752]: https://github.com/JuliaDocs/Documenter.jl/issues/1752
[#1754]: https://github.com/JuliaDocs/Documenter.jl/issues/1754
[#1756]: https://github.com/JuliaDocs/Documenter.jl/issues/1756
[#1758]: https://github.com/JuliaDocs/Documenter.jl/issues/1758
[#1759]: https://github.com/JuliaDocs/Documenter.jl/issues/1759
[#1760]: https://github.com/JuliaDocs/Documenter.jl/issues/1760
[#1762]: https://github.com/JuliaDocs/Documenter.jl/issues/1762
[#1766]: https://github.com/JuliaDocs/Documenter.jl/issues/1766
[#1770]: https://github.com/JuliaDocs/Documenter.jl/issues/1770
[#1771]: https://github.com/JuliaDocs/Documenter.jl/issues/1771
[#1772]: https://github.com/JuliaDocs/Documenter.jl/issues/1772
[#1773]: https://github.com/JuliaDocs/Documenter.jl/issues/1773
[#1774]: https://github.com/JuliaDocs/Documenter.jl/issues/1774
[#1776]: https://github.com/JuliaDocs/Documenter.jl/issues/1776
[#1780]: https://github.com/JuliaDocs/Documenter.jl/issues/1780
[#1784]: https://github.com/JuliaDocs/Documenter.jl/issues/1784
[#1785]: https://github.com/JuliaDocs/Documenter.jl/issues/1785
[#1788]: https://github.com/JuliaDocs/Documenter.jl/issues/1788
[#1792]: https://github.com/JuliaDocs/Documenter.jl/issues/1792
[#1795]: https://github.com/JuliaDocs/Documenter.jl/issues/1795
[#1796]: https://github.com/JuliaDocs/Documenter.jl/issues/1796
[#1797]: https://github.com/JuliaDocs/Documenter.jl/issues/1797
[#1802]: https://github.com/JuliaDocs/Documenter.jl/issues/1802
[#1803]: https://github.com/JuliaDocs/Documenter.jl/issues/1803
[#1805]: https://github.com/JuliaDocs/Documenter.jl/issues/1805
[#1806]: https://github.com/JuliaDocs/Documenter.jl/issues/1806
[#1807]: https://github.com/JuliaDocs/Documenter.jl/issues/1807
[#1808]: https://github.com/JuliaDocs/Documenter.jl/issues/1808
[#1810]: https://github.com/JuliaDocs/Documenter.jl/issues/1810
[#1811]: https://github.com/JuliaDocs/Documenter.jl/issues/1811
[#1814]: https://github.com/JuliaDocs/Documenter.jl/issues/1814
[#1816]: https://github.com/JuliaDocs/Documenter.jl/issues/1816
[#1818]: https://github.com/JuliaDocs/Documenter.jl/issues/1818
[#1821]: https://github.com/JuliaDocs/Documenter.jl/issues/1821
[#1825]: https://github.com/JuliaDocs/Documenter.jl/issues/1825
[#1826]: https://github.com/JuliaDocs/Documenter.jl/issues/1826
[#1827]: https://github.com/JuliaDocs/Documenter.jl/issues/1827
[#1828]: https://github.com/JuliaDocs/Documenter.jl/issues/1828
[#1829]: https://github.com/JuliaDocs/Documenter.jl/issues/1829
[#1833]: https://github.com/JuliaDocs/Documenter.jl/issues/1833
[#1834]: https://github.com/JuliaDocs/Documenter.jl/issues/1834
[#1835]: https://github.com/JuliaDocs/Documenter.jl/issues/1835
[#1836]: https://github.com/JuliaDocs/Documenter.jl/issues/1836
[#1838]: https://github.com/JuliaDocs/Documenter.jl/issues/1838
[#1841]: https://github.com/JuliaDocs/Documenter.jl/issues/1841
[#1842]: https://github.com/JuliaDocs/Documenter.jl/issues/1842
[#1844]: https://github.com/JuliaDocs/Documenter.jl/issues/1844
[#1846]: https://github.com/JuliaDocs/Documenter.jl/issues/1846
[#1857]: https://github.com/JuliaDocs/Documenter.jl/issues/1857
[#1861]: https://github.com/JuliaDocs/Documenter.jl/issues/1861
[#1862]: https://github.com/JuliaDocs/Documenter.jl/issues/1862
[#1865]: https://github.com/JuliaDocs/Documenter.jl/issues/1865
[#1870]: https://github.com/JuliaDocs/Documenter.jl/issues/1870
[#1871]: https://github.com/JuliaDocs/Documenter.jl/issues/1871
[#1880]: https://github.com/JuliaDocs/Documenter.jl/issues/1880
[#1881]: https://github.com/JuliaDocs/Documenter.jl/issues/1881
[#1885]: https://github.com/JuliaDocs/Documenter.jl/issues/1885
[#1886]: https://github.com/JuliaDocs/Documenter.jl/issues/1886
[#1890]: https://github.com/JuliaDocs/Documenter.jl/issues/1890
[#1892]: https://github.com/JuliaDocs/Documenter.jl/issues/1892
[#1900]: https://github.com/JuliaDocs/Documenter.jl/issues/1900
[#1903]: https://github.com/JuliaDocs/Documenter.jl/issues/1903
[#1906]: https://github.com/JuliaDocs/Documenter.jl/issues/1906
[#1908]: https://github.com/JuliaDocs/Documenter.jl/issues/1908
[#1909]: https://github.com/JuliaDocs/Documenter.jl/issues/1909
[#1912]: https://github.com/JuliaDocs/Documenter.jl/issues/1912
[#1919]: https://github.com/JuliaDocs/Documenter.jl/issues/1919
[#1924]: https://github.com/JuliaDocs/Documenter.jl/issues/1924
[#1930]: https://github.com/JuliaDocs/Documenter.jl/issues/1930
[#1931]: https://github.com/JuliaDocs/Documenter.jl/issues/1931
[#1932]: https://github.com/JuliaDocs/Documenter.jl/issues/1932
[#1933]: https://github.com/JuliaDocs/Documenter.jl/issues/1933
[#1935]: https://github.com/JuliaDocs/Documenter.jl/issues/1935
[#1936]: https://github.com/JuliaDocs/Documenter.jl/issues/1936
[#1937]: https://github.com/JuliaDocs/Documenter.jl/issues/1937
[#1944]: https://github.com/JuliaDocs/Documenter.jl/issues/1944
[#1946]: https://github.com/JuliaDocs/Documenter.jl/issues/1946
[#1948]: https://github.com/JuliaDocs/Documenter.jl/issues/1948
[#1955]: https://github.com/JuliaDocs/Documenter.jl/issues/1955
[#1956]: https://github.com/JuliaDocs/Documenter.jl/issues/1956
[#1957]: https://github.com/JuliaDocs/Documenter.jl/issues/1957
[#1958]: https://github.com/JuliaDocs/Documenter.jl/issues/1958
[#1962]: https://github.com/JuliaDocs/Documenter.jl/issues/1962
[#1969]: https://github.com/JuliaDocs/Documenter.jl/issues/1969
[#1970]: https://github.com/JuliaDocs/Documenter.jl/issues/1970
[#1976]: https://github.com/JuliaDocs/Documenter.jl/issues/1976
[#1977]: https://github.com/JuliaDocs/Documenter.jl/issues/1977
[#1980]: https://github.com/JuliaDocs/Documenter.jl/issues/1980
[#1983]: https://github.com/JuliaDocs/Documenter.jl/issues/1983
[#1989]: https://github.com/JuliaDocs/Documenter.jl/issues/1989
[#1991]: https://github.com/JuliaDocs/Documenter.jl/issues/1991
[#1993]: https://github.com/JuliaDocs/Documenter.jl/issues/1993
[#2012]: https://github.com/JuliaDocs/Documenter.jl/issues/2012
[#2018]: https://github.com/JuliaDocs/Documenter.jl/issues/2018
[#2019]: https://github.com/JuliaDocs/Documenter.jl/issues/2019
[#2027]: https://github.com/JuliaDocs/Documenter.jl/issues/2027
[#2051]: https://github.com/JuliaDocs/Documenter.jl/issues/2051
[#2066]: https://github.com/JuliaDocs/Documenter.jl/issues/2066
[#2067]: https://github.com/JuliaDocs/Documenter.jl/issues/2067
[#2070]: https://github.com/JuliaDocs/Documenter.jl/issues/2070
[#2071]: https://github.com/JuliaDocs/Documenter.jl/issues/2071
[#2076]: https://github.com/JuliaDocs/Documenter.jl/issues/2076
[#2078]: https://github.com/JuliaDocs/Documenter.jl/issues/2078
[#2081]: https://github.com/JuliaDocs/Documenter.jl/issues/2081
[#2085]: https://github.com/JuliaDocs/Documenter.jl/issues/2085
[#2100]: https://github.com/JuliaDocs/Documenter.jl/issues/2100
[#2103]: https://github.com/JuliaDocs/Documenter.jl/issues/2103
[#2128]: https://github.com/JuliaDocs/Documenter.jl/issues/2128
[#2130]: https://github.com/JuliaDocs/Documenter.jl/issues/2130
[#2134]: https://github.com/JuliaDocs/Documenter.jl/issues/2134
[#2141]: https://github.com/JuliaDocs/Documenter.jl/issues/2141
[#2142]: https://github.com/JuliaDocs/Documenter.jl/issues/2142
[#2143]: https://github.com/JuliaDocs/Documenter.jl/issues/2143
[#2145]: https://github.com/JuliaDocs/Documenter.jl/issues/2145
[#2147]: https://github.com/JuliaDocs/Documenter.jl/issues/2147
[#2153]: https://github.com/JuliaDocs/Documenter.jl/issues/2153
[#2157]: https://github.com/JuliaDocs/Documenter.jl/issues/2157
[#2169]: https://github.com/JuliaDocs/Documenter.jl/issues/2169
[#2170]: https://github.com/JuliaDocs/Documenter.jl/issues/2170
[#2181]: https://github.com/JuliaDocs/Documenter.jl/issues/2181
[#2187]: https://github.com/JuliaDocs/Documenter.jl/issues/2187
[#2191]: https://github.com/JuliaDocs/Documenter.jl/issues/2191
[#2194]: https://github.com/JuliaDocs/Documenter.jl/issues/2194
[#2202]: https://github.com/JuliaDocs/Documenter.jl/issues/2202
[#2205]: https://github.com/JuliaDocs/Documenter.jl/issues/2205
[#2211]: https://github.com/JuliaDocs/Documenter.jl/issues/2211
[#2213]: https://github.com/JuliaDocs/Documenter.jl/issues/2213
[#2214]: https://github.com/JuliaDocs/Documenter.jl/issues/2214
[#2215]: https://github.com/JuliaDocs/Documenter.jl/issues/2215
[#2216]: https://github.com/JuliaDocs/Documenter.jl/issues/2216
[#2217]: https://github.com/JuliaDocs/Documenter.jl/issues/2217
[#2232]: https://github.com/JuliaDocs/Documenter.jl/issues/2232
[#2236]: https://github.com/JuliaDocs/Documenter.jl/issues/2236
[#2237]: https://github.com/JuliaDocs/Documenter.jl/issues/2237
[#2245]: https://github.com/JuliaDocs/Documenter.jl/issues/2245
[#2247]: https://github.com/JuliaDocs/Documenter.jl/issues/2247
[#2249]: https://github.com/JuliaDocs/Documenter.jl/issues/2249
[#2252]: https://github.com/JuliaDocs/Documenter.jl/issues/2252
[#2259]: https://github.com/JuliaDocs/Documenter.jl/issues/2259
[#2260]: https://github.com/JuliaDocs/Documenter.jl/issues/2260
[#2269]: https://github.com/JuliaDocs/Documenter.jl/issues/2269
[#2272]: https://github.com/JuliaDocs/Documenter.jl/issues/2272
[#2273]: https://github.com/JuliaDocs/Documenter.jl/issues/2273
[#2274]: https://github.com/JuliaDocs/Documenter.jl/issues/2274
[#2279]: https://github.com/JuliaDocs/Documenter.jl/issues/2279
[#2280]: https://github.com/JuliaDocs/Documenter.jl/issues/2280
[#2281]: https://github.com/JuliaDocs/Documenter.jl/issues/2281
[#2285]: https://github.com/JuliaDocs/Documenter.jl/issues/2285
[#2288]: https://github.com/JuliaDocs/Documenter.jl/issues/2288
[#2293]: https://github.com/JuliaDocs/Documenter.jl/issues/2293
[#2300]: https://github.com/JuliaDocs/Documenter.jl/issues/2300
[#2306]: https://github.com/JuliaDocs/Documenter.jl/issues/2306
[#2307]: https://github.com/JuliaDocs/Documenter.jl/issues/2307
[#2308]: https://github.com/JuliaDocs/Documenter.jl/issues/2308
[#2313]: https://github.com/JuliaDocs/Documenter.jl/issues/2313
[#2317]: https://github.com/JuliaDocs/Documenter.jl/issues/2317
[#2324]: https://github.com/JuliaDocs/Documenter.jl/issues/2324
[#2325]: https://github.com/JuliaDocs/Documenter.jl/issues/2325
[#2327]: https://github.com/JuliaDocs/Documenter.jl/issues/2327
[#2329]: https://github.com/JuliaDocs/Documenter.jl/issues/2329
[#2330]: https://github.com/JuliaDocs/Documenter.jl/issues/2330
[#2344]: https://github.com/JuliaDocs/Documenter.jl/issues/2344
[JuliaLang/julia#29344]: https://github.com/JuliaLang/julia/issues/29344
[JuliaLang/julia#36953]: https://github.com/JuliaLang/julia/issues/36953
[JuliaLang/julia#38054]: https://github.com/JuliaLang/julia/issues/38054
[JuliaLang/julia#39841]: https://github.com/JuliaLang/julia/issues/39841
[JuliaLang/julia#43652]: https://github.com/JuliaLang/julia/issues/43652
[JuliaLang/julia#45174]: https://github.com/JuliaLang/julia/issues/45174
