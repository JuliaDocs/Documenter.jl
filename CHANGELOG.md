# Documenter.jl changelog

## Version `v0.28.0` (unreleased)

* The (minimum) required Julia version has been raised from 1.0 to 1.6. For older Julia versions the 0.27.X release can still be used. ([#1835][github-1835], [#1841][github-1841])
* ![BREAKING][badge-breaking] The Markdown backend has been fully removed from the Documenter package, in favor of the external [DocumenterMarkdown package][documentermarkdown]. This includes the removal of the exported `Deps` module. ([#1826][github-1826])

  **For upgrading:** To keep using the Markdown backend, refer to the [DocumenterMarkdown package][documentermarkdown]. That package might not immediately support the latest Documenter version, however.

* ![BREAKING][badge-breaking] `@eval` blocks now require the last expression to be either `nothing` or of type `Markdown.MD`, with other cases now issuing a warning and falling back to a text representation in a code block. ([#1919][github-1919])

  **For upgrading:** The cases where an `@eval` results in a object that is not `nothing` or `::Markdown.MD`, the returned object should be reviewed. In case the resulting object is of some `Markdown` node type (e.g. `Markdown.Paragraph` or `Markdown.Table`), it can simply be wrapped in `Markdown.MD([...])` for block nodes, or `Markdown.MD([Markdown.Paragraph([...])])` for inline nodes. In other cases Documenter was likely not handling the returned object in a correct way, but please open an issue if this change has broken a previously working use case.

* ![Enhancement][badge-enhancement] Doctest filters can now be specified as regex/substitution pairs, i.e. `r"..." => s"..."`, in order to control the replacement (which defaults to the empty string, `""`). ([#1989][github-1989])
* ![Enhancement][badge-enhancement] Documenter is now more careful not to accidentally leak SSH keys (in e.g. error messages) by removing `DOCUMENTER_KEY` from the environment when it is not needed. ([#1958][github-1958], [#1962][github-1962])
* ![Enhancement][badge-enhancement] Admonitions are now styled with color in the LaTeX output. ([#1931][github-1931], [#1932][github-1932], [#1946][github-1946], [#1955][github-1955])
* ![Enhancement][badge-enhancement] Improved the styling of code blocks in the LaTeXWriter. ([#1933][github-1933], [#1935][github-1935], [#1936][github-1936], [#1944][github-1944], [#1956][github-1956], [#1957][github-1957])
* ![Enhancement][badge-enhancement] Automatically resize oversize `tabular` environments from `@example` blocks in LaTeXWriter. ([#1930][github-1930], [#1937][github-1937])
* ![Enhancement][badge-enhancement] The `ansicolor` keyword to `HTML()` now defaults to true, meaning that executed outputs from `@example`- and `@repl`-blocks are now by default colored (if they emit colored output). ([#1828][github-1828])
* ![Enhancement][badge-enhancement] Documenter now shows a link to the root of the repository in the top navigation bar. The link is determined automatically from the remote repository, unless overridden or disabled via the `repolink` argument of `HTML`. ([#1254][github-1254])
* ![Enhancement][badge-enhancement] A more general API is now available to configure the remote repository URLs via the `repo` argument of `makedocs` by passing objects that are subtypes of `Remotes.Remote` and implement its interface (e.g. `Remotes.GitHub`). Documenter will also try to determine `repo` automatically from the `GITHUB_REPOSITORY` environment variable if other fallbacks have failed. ([#1808][github-1808], [#1881][github-1881])
* ![Enhancement][badge-enhancement] Broken issue references (i.e. links like `[#1234](@ref)`, but when Documenter is unable to determine the remote GitHub repository) now generate `:cross_references` errors that can be caught via the `strict` keyword. ([#1808][github-1808])

  This is **potentially breaking** as it can cause previously working builds to fail if they are being run in strict mode. However, such builds were already leaving broken links in the generated documentation.

  **For upgrading:** the easiest way to fix the build is to remove the offending `@ref` links. Alternatively, the `repo` argument to `makedocs` can be set to the appropriate `Remotes.Remote` object that implements the `Remotes.issueurl` function, which would make sure that correct URLs are generated.

* ![Enhancement][badge-enhancement] Woodpecker CI is now automatically supported for documentation deployment. ([#1880][github-1880])
* ![Enhancement][badge-enhancement] The `@contents`-block now support `UnitRange`s for the `Depth` argument. This makes it possible to configure also the *minimal* header depth that should be displayed (`Depth = 2:3`, for example). This is supported by the HTML and the LaTeX/PDF backends. ([#245][github-245], [#1890][github-1890])
* ![Enhancement][badge-enhancement] The code copy buttons in HTML now have `title` and `aria-label` attributes. ([#1903][github-1903])
* ![Enhancement][badge-enhancement] The at-ref links are now more flexible, allowing arbitrary links to point to both docstrings and section headings. ([#781][github-781], [#1900][github-1900])
* ![Enhancement][badge-enhancement] Code blocks like `@example` or `@repl` are now also expanded in nested contexts (e.g. admonitions, lists or block quotes). ([#491][github-491], [#1970][github-1970])
* ![Enhancement][badge-enhancement] The new `pagesonly` keyword to `makedocs` can be used to restrict builds to just the Markdown files listed in `pages` (as opposed to all `.md` files under `src/`). ([#1980][github-1980])
* ![Bugfix][badge-bugfix] Documenter now generates the correct source URLs for docstrings from other packages when the `repo` argument to `makedocs` is set (note: the source links to such docstrings only work if the external package is cloned from GitHub and added as a dev-dependency). However, this change **breaks** the case where the `repo` argument is used to override the main package/repository URL, assuming the repository is cloned from GitHub. ([#1808][github-1808])
* ![Bugfix][badge-bugfix] Documenter no longer uses the `TRAVIS_REPO_SLUG` environment variable to determine the Git remote of non-main repositories (when inferring it from the Git repository configuration has failed), which could previously lead to bad source links. ([#1881][github-1881])
* ![Bugfix][badge-bugfix] Line endings in Markdown source files are now normalized to `LF` before parsing, to work around [a bug in the Julia Markdown parser][julia-29344] where parsing is sensitive to line endings, and can therefore cause platform-dependent behavior. ([#1906][github-1906])
* ![Bugfix][badge-bugfix] `HTMLWriter` no longer complains about invalid URLs in docstrings when `makedocs` gets run multiple time in a Julia session, as it no longer modifies the underlying docstring objects. ([#505][github-505], [#1924][github-1924])
* ![Bugfix][badge-bugfix] Docstring doctests now properly get checked on each `makedocs` run, when run multiple times in the same Julia session. ([#974][github-974], [#1948][github-1948])
* ![Bugfix][badge-bugfix] The default decision for whether to deploy preview builds for pull requests have been changed from `true` to `false` when not possible to verify the origin of the pull request. ([#1969][github-1969])
* ![Maintenance][badge-maintenance] Documenter now uses [MarkdownAST][markdownast] to internally represent Markdown documents. While this change should not lead to any visible changes to the user, it is a major refactoring of the code. Please report any novel errors or unexpected behavior you encounter when upgrading to 0.28 on the [Documenter issue tracker][documenter-issues]. ([#1892][github-1892], [#1912][github-1912], [#1924][github-1924], [#1948][github-1948])
* ![Maintenance][badge-maintenance] The code layout has changed considerably, with many of the internal submodules removed. This **may be breaking** for code that hooks into various Documenter internals, as various types and functions now live at different code paths. ([#1977][github-1977])

## Version `v0.27.23`

* ![Enhancement][badge-enhancement] The `native` and `docker` PDF builds now run with the `-interaction=batchmode` (instead of `nonstopmode`) and `-halt-on-error` options to make the LaTeX error logs more readable and to fail the build early. ([#1908][github-1908])
* ![Bugfix][badge-bugfix] The PDF/LaTeX output now handles hard Markdown line breaks (i.e. `Markdown.LineBreak` nodes). ([#1908][github-1908])
* ![Bugfix][badge-bugfix] Previously broken links within the PDF output are now fixed. ([JuliaLang/julia#38054][julia-38054], [JuliaLang/julia#43652][julia-43652], [#1909][github-1909])

## Version `v0.27.22`

* ![Maintenance][badge-maintenance] Documenter is now compatible with DocStringExtensions v0.9. ([#1885][github-1885], [#1886][github-1886])

## Version `v0.27.21`

* ![Bugfix][badge-bugfix] Fix a regression where Documenter throws an error on systems that do not have Git available. ([#1870][github-1870], [#1871][github-1871])

## Version `v0.27.20`

* ![Enhancement][badge-enhancement] The various JS and font dependencies of the HTML backend have been updated to the latest non-breaking versions. ([#1844][github-1844], [#1846][github-1846])

  - MathJax 3 has been updated from `v3.2.0` to `v3.2.2`.
  - JuliaMono has been updated from `v0.044` to `v0.045`.
  - Font Awesome has been updated from `v5.15.3` to `v5.15.4`.
  - highlight.js has been updated from `v11.0.1` to `v11.5.1`.
  - KaTeX has been updated from `v0.13.11` to `v0.13.24`.

* ![Experimental][badge-experimental] `deploydocs` now supports "deploying to tarball" (rather than pushing to the `gh-pages` branch) via the undocumented experiments `archive` keyword. ([#1865][github-1865])
* ![Bugfix][badge-bugfix] When including docstrings for an alias, Documenter now correctly tries to include the exactly matching docstring first, before checking for signature subtypes. ([#1842][github-1842])
* ![Bugfix][badge-bugfix] When checking for missing docstrings, Documenter now correctly handles docstrings for methods that extend bindings from other modules that have not been imported into the current module. ([#1695][github-1695], [#1857][github-1857], [#1861][github-1861])
* ![Bugfix][badge-bugfix] By overriding `GIT_TEMPLATE_DIR`, `git` no longer picks up arbitrary user templates and hooks when internally called by Documenter. ([#1862][github-1862])

## Version `v0.27.19`

* ![Enhancement][badge-enhancement] Documenter can now build draft version of HTML documentation by passing `draft=true` to `makedocs`. Draft mode skips potentially expensive parts of the building process and can be useful to get faster feedback when writing documentation. Draft mode currently skips doctests, `@example`-, `@repl`-, `@eval`-, and `@setup`-blocks. Draft mode can be disabled (or enabled) on a per-page basis by setting `Draft = true` in an `@meta` block. ([#1836][github-1836])
* ![Enhancement][badge-enhancement] On the HTML search page, pressing enter no longer causes the page to refresh (and therefore does not trigger the slow search index rebuild). ([#1728][github-1728], [#1833][github-1833], [#1834][github-1834])
* ![Enhancement][badge-enhancement] For the `edit_link` keyword to `HTML()`, Documenter automatically tries to figure out if the remote default branch is `main`, `master`, or something else. It will print a warning if it is unable to reliably determine either `edit_link` or `devbranch` (for `deploydocs`). ([#1827][github-1827], [#1829][github-1829])
* ![Enhancement][badge-enhancement] Profiling showed that a significant amount of the HTML page build time was due to external `git` commands (used to find remote URLs for docstrings). These results are now cached on a per-source-file basis resulting in faster build times. This is particularly useful when using [LiveServer.jl][liveserver]s functionality for live-updating the docs while writing. ([#1838][github-1838])

## Version `v0.27.18`

* ![Enhancement][badge-enhancement] The padding of the various container elements in the HTML style has been reduced, to improve the look of the generated HTML pages. ([#1814][github-1814], [#1818][github-1818])
* ![Bugfix][badge-bugfix] When deploying unversioned docs, Documenter now generates a `siteinfo.js` file that disables the version selector, even if a `../versions.js` happens to exists. ([#1667][github-1667], [#1825][github-1825])
* ![Bugfix][badge-bugfix] Build failures now only show fatal errors, rather than all errors. ([#1816][github-1816])
* ![Bugfix][badge-bugfix] Disable git terminal prompt when detecting remote HEAD branch for ssh remotes, and allow ssh-agent authentication (by appending rather than overriding ENV). ([#1821][github-1821])

## Version `v0.27.17`

* ![Enhancement][badge-enhancement] PDF/LaTeX output can now be compiled with the [Tectonic](https://tectonic-typesetting.github.io) LaTeX engine. ([#1802][github-1802], [#1803][github-1803])
* ![Enhancement][badge-enhancement] The phrasing of the outdated version warning in the HTML output has been improved. ([#1805][github-1805])
* ![Enhancement][badge-enhancement] Documenter now provides the `Documenter.except` function which can be used to "invert" the list of errors that are passed to `makedocs` via the `strict` keyword. ([#1811][github-1811])
* ![Bugfix][badge-bugfix] When linkchecking HTTP and HTTPS URLs, Documenter now also passes a realistic `accept-encoding` header along with the request, in order to work around servers that try to block non-browser requests. ([#1807][github-1807])
* ![Bugfix][badge-bugfix] LaTeX build logs are now properly outputted to the `LaTeXWriter.{stdout,stderr}` files when using the Docker build option. ([#1806][github-1806])
* ![Bugfix][badge-bugfix] `makedocs` no longer fails with an `UndefVarError` if it encounters a specific kind of bad docsystem state related to docstrings attached to the call syntax, but issues an `@autodocs` error/warning instead. ([JuliaLang/julia#45174][julia-45174], [#1192][github-1192], [#1810][github-1810], [#1811][github-1811])

## Version `v0.27.16`

* ![Enhancement][badge-enhancement] Update CSS source file for JuliaMono, so that all font variations are included (not just `JuliaMono Regular`) and that the latest version (0.039 -> 0.044) of the font would be used. ([#1780][github-1780], [#1784][github-1784])
* ![Enhancement][badge-enhancement] The table of contents in the generated PDFs have more space between section numbers and titles to avoid them overlapping. ([#1785][github-1785])
* ![Enhancement][badge-enhancement] The preamble of the LaTeX source of the PDF build can now be customized by the user. ([#1746][github-1746], [#1788][github-1788])
* ![Enhancement][badge-enhancement] The package version number shown in the PDF manual can now be set by the user by passing the `version` option to `format = LaTeX()`. ([#1795][github-1795])
* ![Bugfix][badge-bugfix] Fix `strict` mode to properly print errors, not just a warnings. ([#1756][github-1756], [#1776][github-1776])
* ![Bugfix][badge-bugfix] Disable git terminal prompt when detecting remote HEAD branch. ([#1797][github-1797])
* ![Bugfix][badge-bugfix] When linkchecking HTTP and HTTPS URLs, Documenter now passes a realistic browser (Chrome) `User-Agent` header along with the request, in order to work around servers that try to use the `User-Agent` to block non-browser requests. ([#1796][github-1796])

## Version `v0.27.15`

* ![Enhancement][badge-enhancement] Documenter now deploys documentation from scheduled jobs (`schedule` on GitHub actions). ([#1772][github-1772], [#1773][github-1773])
* ![Enhancement][badge-enhancement] Improve layout of the table of contents section in the LaTeX/PDF output. ([#1750][github-1750])
* ![Bugfix][badge-bugfix] Improve the fix for extraneous whitespace in REPL blocks. ([#1774][github-1774])

## Version `v0.27.14`

* ![Bugfix][badge-bugfix] Fix a CSS bug causing REPL code blocks to contain extraneous whitespace. ([#1770][github-1770], [#1771][github-1771])

## Version `v0.27.13`

* ![Bugfix][badge-bugfix] Fix a CSS bug causing the location of the code copy button to not be fixed in the upper right corner. ([#1758][github-1758], [#1759][github-1759])
* ![Bugfix][badge-bugfix] Fix a bug when loading the `copy.js` script for the code copy button. ([#1760][github-1760], [#1762][github-1762])

## Version `v0.27.12`

* ![Bugfix][badge-bugfix] Fix code copy button in insecure contexts (e.g. pages hosted without https). ([#1754][github-1754])

## Version `v0.27.11`

* ![Enhancement][badge-enhancement] Documenter now deploys documentation from manually triggered events (`workflow_dispatch` on GitHub actions). ([#1554][github-1554], [#1752][github-1752])
* ![Enhancement][badge-enhancement] MathJax 3 has been updated to `v3.2.0` (minor version bump). ([#1743][github-1743])
* ![Enhancement][badge-enhancement] HTML code blocks now have a copy button. ([#1748][github-1748])
* ![Enhancement][badge-enhancement] Documenter now tries to detect the development branch using `git` with the old default (`master`) as fallback. If you use `main` as the development branch you shouldn't need to specify `devbranch = "main"` as an argument to deploydocs anymore. ([#1443][github-1443], [#1727][github-1727], [#1751][github-1751])

## Version `v0.27.10`

* ![Bugfix][badge-bugfix] Fix depth of headers in LaTeXWriter. ([#1716][github-1716])

## Version `v0.27.9`

* ![Bugfix][badge-bugfix] Fix some errors with text/latex MIME type in LaTeXWriter. ([#1709][github-1709])

## Version `v0.27.8`

* ![Feature][badge-feature] The keyword argument `strict` in `makedocs` is more flexible: in addition to a boolean indicating whether or not any error should result in a failure, `strict` also accepts a `Symbol` or `Vector{Symbol}` indicating which error(s) should result in a build failure. ([#1689][github-1689])

* ![Feature][badge-feature] Allow users to inject custom JavaScript resources to enable alternatives to Google Analytics like plausible.io. ([#1706][github-1706])

* ![Bugfix][badge-bugfix] Fix a few accessibility issues in the HTML output. ([#1673][github-1673])

## Version `v0.27.7`

* ![Bugfix][badge-bugfix] Fix an error when building documentation for the first time with `push_preview`. ([#1693][github-1693], [#1704][github-1704])
* ![Bugfix][badge-bugfix] Fix a rare logger error for failed doctests. ([#1698][github-1698], [#1699][github-1699])
* ![Bugfix][badge-bugfix] Fix an error occuring with `DocTestFilters = nothing` in `@meta` blocks. ([#1696][github-1696])

## Version `v0.27.6`

* ![Feature][badge-feature] Add support for generating `index.html` to redirect to `dev` or `stable`. The redirected destination is the same as the outdated warning. If there's already user-generated `index.html`, Documenter will not overwrite the file. ([#937][github-937], [#1657][github-1657], [#1658][github-1658])

* ![Bugfix][badge-bugfix] Checking whether a PR comes from the correct repository when deciding to deploy a preview on GitHub Actions now works on Julia 1.0 too. ([#1665][github-1665])

* ![Bugfix][badge-bugfix] When a doctest fails, pass file and line information associated to the location of the doctest instead of the location of the testing code in Documenter to the logger. ([#1687][github-1687])

* ![Bugfix][badge-bugfix] Enabled colored printing for each output of `@repl`-blocks. ([#1691][github-1691])

## Version `v0.27.5`

* ![Bugfix][badge-bugfix] Fix an error introduced in version `v0.27.4` (PR[#1634][github-1634]) which was triggered by trailing comments in `@eval`/`@repl`/`@example` blocks. ([#1655][github-1655], [#1661][github-1661])

## Version `v0.27.4`

* ![Feature][badge-feature] `@example`- and `@repl`-blocks now support colored output by mapping ANSI escape sequences to HTML. This requires Julia >= 1.6 and passing `ansicolor=true` to `Documenter.HTML` (e.g. `makedocs(format=Documenter.HTML(ansicolor=true, ...), ...)`). In Documenter 0.28.0 this will be the default so to (preemptively) opt-out pass `ansicolor=false`. ([#1441][github-1441], [#1628][github-1628], [#1629][github-1629], [#1647][github-1647])

* ![Experimental][badge-experimental] ![Feature][badge-feature] Documenter's HTML output can now prerender syntax highlighting of code blocks, i.e. syntax highlighting is applied when generating the HTML page rather than on the fly in the browser after the page is loaded. This requires (i) passing `prerender=true` to `Documenter.HTML` and (ii) a `node` (NodeJS) executable available in `PATH`. A path to a `node` executable can be specified by passing the `node` keyword argument to `Documenter.HTML` (for example from the `NodeJS_16_jll` Julia package). In addition, the `highlightjs` keyword argument can be used to specify a file path to a highlight.js library (if this is not given the release used by Documenter will be used). Example configuration:
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
  _This feature is experimental and subject to change in future releases._ ([#1627][github-1627])

* ![Enhancement][badge-enhancement] The `julia>` prompt is now colored in green in the `julia-repl` language highlighting. ([#1639][github-1639], [#1641][github-1641])

* ![Enhancement][badge-enhancement] The `.hljs` CSS class is now added to all code blocks to make sure that the correct text color is used for non-highlighted code blocks and if JavaScript is disabled. ([#1645][github-1645])

* ![Enhancement][badge-enhancement] The sandbox module used for evaluating `@repl` and `@example` blocks is now removed (replaced with `Main`) in text output. ([#1633][github-1633])

* ![Enhancement][badge-enhancement] `@repl`, `@example`, and `@eval` blocks now have `LineNumberNodes` inserted such that e.g. `@__FILE__` and `@__LINE__` give better output and not just `"none"` for the file and `1` for the line. This requires Julia 1.6 or higher (no change on earlier Julia versions). ([#1634][github-1634])

* ![Bugfix][badge-bugfix] Dollar signs in the HTML output no longer get accidentally misinterpreted as math delimiters in the browser. ([#890][github-890], [#1625][github-1625])

* ![Bugfix][badge-bugfix] Fix overflow behavior for math environments to hide unnecessary vertical scrollbars. ([#1575][github-1575], [#1649][github-1649])

## Version `v0.27.3`

* ![Feature][badge-feature] Documenter can now deploy documentation directly to the "root" instead of versioned folders. ([#1615][github-1615], [#1616][github-1616])

* ![Enhancement][badge-enhancement] The version of Documenter used for generating a document is now displayed in the build information. ([#1609][github-1609], [#1611][github-1611])

* ![Bugfix][badge-bugfix] The HTML front end no longer uses ligatures when displaying code (with JuliaMono). ([#1610][github-1610], [#1617][github-1617])

## Version `v0.27.2`

* ![Enhancement][badge-enhancement] The default font has been changed to `Lato Medium` so that the look of the text would be closer to the old Google Fonts version of Lato. ([#1602][github-1602], [#1604][github-1604])

## Version `v0.27.1`

* ![Enhancement][badge-enhancement] The HTML output now uses [JuliaMono][juliamono] as the default monospace font, retrieved from CDNJS. Relatedly, the Lato font is also now retrieved from CDNJS, and the generated HTML pages no longer depend on Google Fonts. ([#618][github-618], [#1561][github-1561], [#1568][github-1568], [#1569][github-1569], [JuliaLang/www.julialang.org][julialangorg-1272])

* ![Enhancement][badge-enhancement] The wording of the text in the the old version warning box was improved. ([#1595][github-1595])

* ![Bugfix][badge-bugfix] Documenter no longer throws an error when generating the version selector if there are no deployed versions. ([#1594][github-1594], [#1596][github-1596])

## Version `v0.27.0`

* ![Enhancement][badge-enhancement] The JS dependencies have been updated to their respective latest versions.

  - highlight.js has been updated to `v11.0.1` (major version bump), which also brings various updates to the highlighting of Julia code. Due to the changes in highlight.js, code highlighting will not work on IE11. ([#1503][github-1503], [#1551][github-1551], [#1590][github-1590])

  - Headroom.js has been updated to `v0.12.0` (major version bump). ([#1590][github-1590])

  - KaTeX been updated to `v0.13.11` (major version bump). ([#1590][github-1590])

  - MathJax versions have been updated to `v2.7.7` (patch version bump) and `v3.1.4` (minor version bump), for MathJax 2 and 3, respectively. ([#1590][github-1590])

  - jQuery been updated to `v3.6.0` (minor version bump). ([#1590][github-1590])

  - Font Awesome has been updated to `v5.15.3` (patch version bump). ([#1590][github-1590])

  - lunr.js has been updated to `v2.3.9` (patch version bump). ([#1590][github-1590])

  - lodash.js has been updated to `v4.17.21` (patch version bump). ([#1590][github-1590])

* ![Enhancement][badge-enhancement] `deploydocs` now throws an error if something goes wrong with the Git invocations used to deploy to `gh-pages`. ([#1529][github-1529])

* ![Enhancement][badge-enhancement] In the HTML output, the site name at the top of the sidebar now also links back to the main page of the documentation (just like the logo). ([#1553][github-1553])

* ![Enhancement][badge-enhancement] The generated HTML sites can now detect if the version the user is browsing is not for the latest version of the package and display a notice box to the user with a link to the latest version. In addition, the pages get a `noindex` tag which should aid in removing outdated versions from search engine results. ([#1302][github-1302], [#1449][github-1449], [#1577][github-1577])

* ![Enhancement][badge-enhancement] The analytics in the HTML output now use the `gtag.js` script, replacing the old deprecated setup. ([#1559][github-1559])

* ![Bugfix][badge-bugfix] A bad `repo` argument to `deploydocs` containing a protocol now throws an error instead of being misinterpreted. ([#1531][github-1531], [#1533][github-1533])

* ![Bugfix][badge-bugfix] SVG images generated by `@example` blocks are now properly scaled to page width by URI-encoding the images, instead of directly embedding the SVG tags into the HTML. ([#1537][github-1537], [#1538][github-1538])

* ![Bugfix][badge-bugfix] `deploydocs` no longer tries to deploy pull request previews from forks on GitHub Actions. ([#1534][github-1534], [#1567][github-1567])

* ![Maintenance][badge-maintenance] Documenter is no longer compatible with IOCapture v0.1 and now requires IOCapture v0.2. ([#1549][github-1549])


## Version `v0.26.3`

* ![Maintenance][badge-maintenance] The internal naming of the temporary modules used to run doctests changed to accommodate upcoming printing changes in Julia. ([JuliaLang/julia#39841][julia-39841], [#1540][github-1540])

## Version `v0.26.2`

* ![Enhancement][badge-enhancement] `doctest()` no longer throws an error if cleaning up the temporary directory fails for some reason. ([#1513][github-1513], [#1526][github-1526])

* ![Enhancement][badge-enhancement] Cosmetic improvements to the PDF output. ([#1342][github-1342], [#1527][github-1527])

* ![Enhancement][badge-enhancement] If `jldoctest` keyword arguments fail to parse, these now get logged as doctesting failures, rather than being ignored with a warning or making `makedocs` throw an error (depending on why they fail to parse). ([#1556][github-1556], [#1557][github-1557])

* ![Bugfix][badge-bugfix] Script-type doctests that have an empty output section no longer crash Documenter. ([#1510][github-1510])

* ![Bugfix][badge-bugfix] When checking for authentication keys when deploying, Documenter now more appropriately checks if the environment variables are non-empty, rather than just whether they are defined. ([#1511][github-1511])

* ![Bugfix][badge-bugfix] Doctests now correctly handle the case when the repository has been checked out with `CRLF` line endings (which can happen on Windows with `core.autocrlf=true`). ([#1516][github-1516], [#1519][github-1519], [#1520][github-1520])

* ![Bugfix][badge-bugfix] Multiline equations are now correctly handled in at-block outputs. ([#1518][github-1518])

## Version `v0.26.1`

* ![Bugfix][badge-bugfix] HTML assets that are copied directly from Documenters source to the build output now has correct file permissions. ([#1497][github-1497])

## Version `v0.26.0`

* ![BREAKING][badge-breaking] The PDF/LaTeX output is again provided as a Documenter built-in and can be enabled by passing an instance of `Documenter.LaTeX` to `format`. The DocumenterLaTeX package has been deprecated. ([#1493][github-1493])

  **For upgrading:** If using the PDF/LaTeX output, change the `format` argument of `makedocs` to `format = Documenter.LaTeX(...)` and remove all references to the DocumenterLaTeX package (e.g. from `docs/Project.toml`).

* ![Enhancement][badge-enhancement] Objects that render as equations and whose `text/latex` representations are wrapped in display equation delimiters `\[ ... \]` or `$$ ... $$` are now handled correctly in the HTML output. ([#1278][github-1278], [#1283][github-1283], [#1426][github-1426])

* ![Enhancement][badge-enhancement] The search page in the HTML output now shows the page titles in the search results. ([#1468][github-1468])

* ![Enhancement][badge-enhancement] The HTML front end now respects the user's OS-level dark theme preference (determined via the `prefers-color-scheme: dark` media query). ([#1320][github-1320], [#1456][github-1456])

* ![Enhancement][badge-enhancement] HTML output now bails early if there are no pages, instead of throwing an `UndefRefError`. In addition, it will also warn if `index.md` is missing and it is not able to generate the main landing page (`index.html`). ([#1201][github-1201], [#1491][github-1491])

* ![Enhancement][badge-enhancement] `deploydocs` now prints a warning on GitHub Actions, Travis CI and Buildkite if the current branch is `main`, but `devbranch = "master`, which indicates a possible Documenter misconfiguration due to GitHub changing the default primary branch of a repository to `main`. ([#1489][github-1489])

## Version `v0.25.5`

* ![Bugfix][badge-bugfix] In the HTML output, display equations that are wider than the page now get a scrollbar instead of overflowing. ([#1470][github-1470], [#1476][github-1476])

## Version `v0.25.4`

* ![Feature][badge-feature] Documenter can now deploy from Buildkite CI to GitHub Pages with `Documenter.Buildkite`. ([#1469][github-1469])

* ![Enhancement][badge-enhancement] Documenter now support Azure DevOps Repos URL scheme when generating edit and source links pointing to the repository. ([#1462][github-1462], [#1463][github-1463], [#1471][github-1471])

* ![Bugfix][badge-bugfix] Type aliases of `Union`s (e.g. `const MyAlias = Union{Foo,Bar}`) are now correctly listed as "Type" in docstrings. ([#1466][github-1466], [#1474][github-1474])

* ![Bugfix][badge-bugfix] HTMLWriter no longers prints a warning when encountering `mailto:` URLs in links. ([#1472][github-1472])

## Version `v0.25.3`

* ![Feature][badge-feature] Documenter can now deploy from GitLab CI to GitHub Pages with `Documenter.GitLab`. ([#1448][github-1448])

* ![Enhancement][badge-enhancement] The URL to the MathJax JS module can now be customized by passing the `url` keyword argument to the constructors (`MathJax2`, `MathJax3`). ([#1428][github-1428], [#1430][github-1430])

* ![Bugfix][badge-bugfix] `Documenter.doctest` now correctly accepts the `doctestfilters` keyword, similar to `Documenter.makedocs`. ([#1364][github-1364], [#1435][github-1435])

* ![Bugfix][badge-bugfix] The `Selectors.dispatch` function now uses a cache to avoid calling `subtypes` on selectors multiple times during a `makedocs` call to avoid slowdowns due to [`subtypes` being slow][julia-38079]. ([#1438][github-1438], [#1440][github-1440], [#1452][github-1452])

## Version `v0.25.2`

* ![Deprecation][badge-deprecation] The `Documenter.MathJax` type, used to specify the mathematics rendering engine in the HTML output, is now deprecated in favor of `Documenter.MathJax2`. ([#1362][github-1362], [#1367][github-1367])

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

* ![Enhancement][badge-enhancement] It is now possible to use MathJax v3 as the mathematics rendering in the HTML output. This can be done by passing `Documenter.MathJax3` as the `mathengine` keyword to `HTML`. ([#1362][github-1362], [#1367][github-1367])

* ![Enhancement][badge-enhancement] The deployment commits created by Documenter are no longer signed by the **@zeptodoctor** user, but rather with the non-existing `documenter@juliadocs.github.io` email address. ([#1379][github-1379], [#1388][github-1388])

* ![Bugfix][badge-bugfix] REPL doctest output lines starting with `#` right after the input code part are now correctly treated as being part of the output (unless prepended with 7 spaces, in line with the standard heuristic). ([#1369][github-1369])

* ![Bugfix][badge-bugfix] Documenter now throws away the extra information from the info string of a Markdown code block (i.e. ` ```language extra-info`), to correctly determine the language, which should be a single word. ([#1392][github-1392], [#1400][github-1400])

* ![Maintenance][badge-maintenance] Documenter now works around a Julia 1.5.0 regression ([JuliaLang/julia#36953](https://github.com/JuliaLang/julia/issues/36953)) which broke doctest fixing if the original doctest output was empty. ([#1337][github-1337], [#1389][github-1389])

## Version `v0.25.1`

* ![Enhancement][badge-enhancement] When automatically determining the page list (i.e. `pages` is not passed to `makedocs`), Documenter now lists `index.md` before other pages. ([#1355][github-1355])

* ![Enhancement][badge-enhancement] The output text boxes of `@example` blocks are now style differently from the code blocks, to make it easier to visually distinguish between the input and output. ([#1026][github-1026], [#1357][github-1357], [#1360][github-1360])

* ![Enhancement][badge-enhancement] The generated HTML site now displays a footer by default that mentions Julia and Documenter. This can be customized or disabled by passing the `footer` keyword to `Documeter.HTML`. ([#1184][github-1184], [#1365][github-1365])

* ![Enhancement][badge-enhancement] Warnings that cause `makedocs` to error when `strict=true` are now printed as errors when `strict` is set to `true`. ([#1088][github-1088], [#1349][github-1349])

* ![Bugfix][badge-bugfix] In the PDF/LaTeX output, equations that use the `align` or `align*` environment are no longer further wrapped in `equation*`/`split`. ([#1368][github-1368])

## Version `v0.25.0`

* ![Enhancement][badge-enhancement] When deploying with `deploydocs`, any SSH username can now be used (not just `git`), by prepending `username@` to the repository URL in the `repo` argument. ([#1285][github-1285])

* ![Enhancement][badge-enhancement] The first link fragment on each page now omits the number; before the rendering resulted in: `#foobar-1`, `#foobar-2`, and now: `#foobar`, `#foobar-2`. For backwards compatibility the old fragments are also inserted such that old links will still point to the same location. ([#1292][github-1292])

* ![Enhancement][badge-enhancement] When deploying on CI with `deploydocs`, the build information in the version number (i.e. what comes after `+`) is now discarded when determining the destination directory. This allows custom tags to be used to fix documentation build and deployment issues for versions that have already been registered. ([#1298][github-1298])

* ![Enhancement][badge-enhancement] You can now optionally choose to push pull request preview builds to a different branch and/or different repository than the main docs builds, by setting the optional `branch_previews` and/or `repo_previews` keyword arguments to the `deploydocs` function. Also, you can now optionally choose to use a different SSH key for preview builds, by setting the optional `DOCUMENTER_KEY_PREVIEWS` environment variable; if the `DOCUMENTER_KEY_PREVIEWS` environment variable is not set, then the regular `DOCUMENTER_KEY` environment variable will be used. ([#1307][github-1307], [#1310][github-1310], [#1315][github-1315])

* ![Enhancement][badge-enhancement] The LaTeX/PDF backend now supports the `platform="none"` keyword, which outputs only the TeX source files, rather than a compiled PDF. ([#1338][github-1338], [#1339][github-1339])

* ![Enhancement][badge-enhancement] Linkcheck no longer prints a warning when enountering a `302 Found` temporary redirect. ([#1344][github-1344], [#1345][github-1345])

* ![Bugfix][badge-bugfix] `Deps.pip` is again a closure and gets executed during the `deploydocs` call, not before it. ([#1240][github-1240])

* ![Bugfix][badge-bugfix] Custom assets (CSS, JS etc.) for the HTML build are now again included as the very last elements in the `<head>` tag so that it would be possible to override default the default assets. ([#1328][github-1328])

* ![Bugfix][badge-bugfix] Docstrings from `@autodocs` blocks are no longer sorted according to an undocumented rule where exported names should come before unexported names. Should this behavior be necessary, the `@autodocs` can be replaced by two separate blocks that use the `Public` and `Private` options to filter out the unexported or exported docstrings in the first or the second block, respectively. ([#964][github-964], [#1323][github-1323])

## Version `v0.24.11`

* ![Bugfix][badge-bugfix] Some sections and page titles that were missing from the search results in the HTML backend now show up. ([#1311][github-1311])

## Version `v0.24.10`

* ![Enhancement][badge-enhancement] The `curl` timeout when checking remote links is now configurable with the `linkcheck_timeout` keyword. ([#1057][github-1057], [#1295][github-1295])

* ![Bugfix][badge-bugfix] Special characters are now properly escaped in admonition titles in LaTeX/PDF builds and do not cause the PDF build to fail anymore. ([#1299][github-1299])

## Version `v0.24.9`

* ![Bugfix][badge-bugfix] Canonical URLs are now properly prettified (e.g. `/path/` instead of `/path/index.html`) when using `prettyurls=true`. ([#1293][github-1293])

## Version `v0.24.8`

* ![Enhancement][badge-enhancement] Non-standard admonition categories are (again) applied to the admonition `<div>` elements in HTML output (as `is-category-$category`). ([#1279][github-1279], [#1280][github-1280])

## Version `v0.24.7`

* ![Bugfix][badge-bugfix] Remove `only`, a new export from `Base` on Julia 1.4, from the JS search filter. ([#1264][github-1264])

* ![Bugfix][badge-bugfix] Fix errors in LaTeX builds due to bad escaping of certain characters. ([#1118][github-1118], [#1119][github-1119], [#1200][github-1200], [#1269][github-1269])

## Version `v0.24.6`

* ![Enhancement][badge-enhancement] Reorganize some of the internal variables in Documenter's Sass sources, to make it easier to create custom themes on top of the Documenter base theme. ([#1258][github-1258])

## Version `v0.24.5`

* ![Enhancement][badge-enhancement] ![Bugfix][badge-bugfix] Documenter now correctly emulates the "REPL softscope" (Julia 1.5) in REPL-style doctest blocks and `@repl` blocks. ([#1232][github-1232])

## Version `v0.24.4`

* ![Enhancement][badge-enhancement] Change the inline code to less distracting black color in the HTML light theme. ([#1212][github-1212], [#1222][github-1222])

* ![Enhancement][badge-enhancement] Add the ability specify the `lang` attribute of the `html` tag in the HTML output, to better support documentation pages in other languages. By default Documenter now defaults to `lang="en"`. ([#1223][github-1223])

## Version `v0.24.3`

* ![Bugfix][badge-bugfix] Fix a case where Documenter's deployment would fail due to git picking up the wrong ssh config file on non-standard systems. ([#1216][github-1216])

## Version `v0.24.2`

* ![Maintenance][badge-maintenance] Improvements to logging in `deploydocs`. ([#1195][github-1195])

## Version `v0.24.1`

* ![Bugfix][badge-bugfix] Fix a bad `mktempdir` incantation in `LaTeXWriter`. ([#1194][github-1194])

## Version `v0.24.0`

* ![BREAKING][badge-breaking] Documenter no longer creates a symlink between the old `latest` url to specified `devurl`. ([#1151][github-1151])

  **For upgrading:** Make sure that links to the latest documentation have been updated (e.g. the package README).

* ![BREAKING][badge-breaking] The deprecated `makedocs` keywords (`html_prettyurls`, `html_disable_git`, `html_edit_branch`, `html_canonical`, `assets`, `analytics`) have been removed. ([#1107][github-1107])

  **For upgrading:** Pass the corresponding values to the `HTML` constructor when settings the `format` keyword.

* ![Feature][badge-feature] Documenter can now deploy preview documentation from pull requests (with head branch in the same repository, i.e. not from forks). This is enabled by passing `push_preview=true` to `deploydocs`. ([#1180][github-1180])

* ![Enhancement][badge-enhancement] The Documenter HTML front end now uses [KaTeX](https://katex.org/) as the default math rendering engine. ([#1097][github-1097])

  **Possible breakage:** This may break the rendering of equations that use some more esoteric features that are only supported in MathJax. It is possible to switch back to MathJax by passing `mathengine = Documenter.MathJax()` to the `HTML` constructor in the `format` keyword.

* ![Enhancement][badge-enhancement] The HTML front end generated by Documenter has been redesigned and now uses the [Bulma CSS framework](https://bulma.io/). ([#1043][github-1043])

  **Possible breakage:** Packages overriding the default Documenter CSS file, relying on some external CSS or relying on Documenter's CSS working in a particular way will not build correct-looking sites. Custom themes should now be developed as Sass files and compiled together with the Documenter and Bulma Sass dependencies (under `assets/html/scss`).

* ![Deprecation][badge-deprecation] ![Enhancement][badge-enhancement] The `edit_branch` keyword to `Documenter.HTML` has been deprecated in favor of the new `edit_link` keyword. As a new feature, passing `edit_link = nothing` disables the "Edit on GitHub" links altogether. ([#1173][github-1173])

  **For upgrading:** If using `edit_branch = nothing`, use `edit_link = :commit` instead. If passing a `String` to `edit_branch`, pass that to `edit_link` instead.

* ![Feature][badge-feature] Deployment is now more customizable and thus not as tied to Travis CI as before. ([#1147][github-1147], [#1171][github-1171], [#1180][github-1180])

* ![Feature][badge-feature] Documenter now has builtin support for deploying from GitHub Actions. Documenter will autodetect the running system, unless explicitly specified. ([#1144][github-1144], [#1152][github-1152])

* ![Feature][badge-feature] When using GitHub Actions Documenter will (try to) post a GitHub status with a link to the generated documentation. This is especially useful for pull request preview builds (see above). ([#1186][github-1186])

* ![Enhancement][badge-enhancement] The handling of JS and CSS assets is now more customizable:

  * The `asset` function can now be used to declare remote JS and CSS assets in the `assets` keyword. ([#1108][github-1108])
  * The `highlights` keyword to `HTML` can be used to declare additional languages that should be highlighted in code blocks. ([#1094][github-1094])
  * It is now possible to choose between MathJax and KaTeX as the math rendering engine with the `mathengine` keyword to `HTML` and to set their configuration in the `make.jl` script directly. ([#1097][github-1097])

* ![Enhancement][badge-enhancement] The JS and CSS dependencies of the front end have been updated to the latest versions. ([#1189][github-1189])

* ![Enhancement][badge-enhancement] Displaying of the site name at the top of the sidebar can now be disabled by passing `sidebar_sitename = false` to `HTML` in the `format` keyword. ([#1089][github-1089])

* ![Enhancement][badge-enhancement] For deployments that have Google Analytics enabled, the URL fragment (i.e. the in-page `#` target) also stored in analytics. ([#1121][github-1121])

* ![Enhancement][badge-enhancement] Page titles are now boosted in the search, yielding better search results. ([#631][github-631], [#1112][github-1112], [#1113][github-1113])

* ![Enhancement][badge-enhancement] In the PDF/LaTeX output, images that are wider than the text are now being scaled down to text width automatically. The PDF builds now require the [adjustbox](https://ctan.org/pkg/adjustbox) LaTeX package to be available. ([#1137][github-1137])

* ![Enhancement][badge-enhancement] If the TeX compilation fails for the PDF/LaTeX output, `makedocs` now throws an exception. ([#1166][github-1166])

* ![Bugfix][badge-bugfix] `LaTeXWriter` now outputs valid LaTeX if an `@contents` block is nested by more than two levels, or if `@contents` or `@index` blocks do not contain any items. ([#1166][github-1166])

## Version `v0.23.4`

* ![Bugfix][badge-bugfix] The `include` and `eval` functions are also available in `@setup` blocks now. ([#1148][github-1148], [#1153][github-1153])

## Version `v0.23.3`

* ![Bugfix][badge-bugfix] Fix file permission error when `Pkg.test`ing Documenter. ([#1115][github-1115])

## Version `v0.23.2`

* ![Bugfix][badge-bugfix] Empty Markdown headings no longer cause Documenter to crash. ([#1081][github-1081], [#1082][github-1082])

## Version `v0.23.1`

* ![Bugfix][badge-bugfix] Documenter no longer throws an error if the provided `EditURL` argument is missing. ([#1076][github-1076], [#1077][github-1077])

* ![Bugfix][badge-bugfix] Non-standard Markdown AST nodes no longer cause Documenter to exit with a missing method error in doctesting and HTML output. Documenter falls back to `repr()` for such nodes. ([#1073][github-1073], [#1075][github-1075])

* ![Bugfix][badge-bugfix] Docstrings parsed into nested `Markdown.MD` objects are now unwrapped correctly and do not cause Documenter to crash with a missing method error anymore. The user can run into that when reusing docstrings with the `@doc @doc(foo) function bar end` pattern. ([#1075][github-1075])

## Version `v0.23.0`

* Documenter v0.23 requires Julia v1.0. ([#1015][github-1015])

* ![BREAKING][badge-breaking] `DocTestSetup`s that are defined in `@meta` blocks no longer apply to doctests that are in docstrings. ([#774][github-774])

  - Specifically, the pattern where `@docs` or `@autodocs` blocks were surrounded by `@meta` blocks, setting up a shared `DocTestSetup` for many docstrings, no longer works.

  - Documenter now exports the `DocMeta` module, which provides an alternative way to add `DocTestSetup` to docstrings.

  **For upgrading:** Use `DocMeta.setdocmeta!` in `make.jl` to set up a `DocTestSetup` that applies to all the docstrings in a particular module instead and, if applicable, remove the now redundant `@meta` blocks. See the ["Setup code" section under "Doctesting"](https://juliadocs.github.io/Documenter.jl/v0.23.0/man/doctests/#Setup-Code-1) in the manual for more information.

* ![Feature][badge-feature] `makedocs` now accepts the `doctest = :only` keyword, which allows doctests to be run while most other build steps, such as rendering, are skipped. This makes it more feasible to run doctests as part of the test suite (see the manual for more information). ([#198][github-198], [#535][github-535], [#756][github-756], [#774][github-774])

* ![Feature][badge-feature] Documenter now exports the `doctest` function, which verifies the doctests in all the docstrings of a given module. This can be used to verify docstring doctests as part of test suite, or to fix doctests right in the REPL. ([#198][github-198], [#535][github-535], [#756][github-756], [#774][github-774], [#1054][github-1054])

* ![Feature][badge-feature] `makedocs` now accepts the `expandfirst` argument, which allows specifying a set of pages that should be evaluated before others. ([#1027][github-1027], [#1029][github-1029])

* ![Enhancement][badge-enhancement] The evaluation order of pages is now fixed (unless customized with `expandfirst`). The pages are evaluated in the alphabetical order of their file paths. ([#1027][github-1027], [#1029][github-1029])

* ![Enhancement][badge-enhancement] The logo image in the HTML output will now always point to the first page in the navigation menu (as opposed to `index.html`, which may or may not exist). When using pretty URLs, the `index.html` part now omitted from the logo link URL. ([#1005][github-1005])

* ![Enhancement][badge-enhancement] Minor changes to how doctesting errors are printed. ([#1028][github-1028])

* ![Enhancement][badge-enhancement] Videos can now be included in the HTML output using the image syntax (`![]()`) if the file extension matches a known format (`.webm`, `.mp4`, `.ogg`, `.ogm`, `.ogv`, `.avi`). ([#1034][github-1034])

* ![Enhancement][badge-enhancement] The PDF output now uses the DejaVu Sans  and DejaVu Sans Mono fonts to provide better Unicode coverage. ([#803][github-803], [#1066][github-1066])

* ![Bugfix][badge-bugfix] The HTML output now outputs HTML files for pages that are not referenced in the `pages` keyword too (Documenter finds them according to their extension). But they do exists outside of the standard navigation hierarchy (as defined by `pages`). This fixes a bug where these pages could still be referenced by `@ref` links and `@contents` blocks, but in the HTML output, the links ended up being broken. ([#1031][github-1031], [#1047][github-1047])

* ![Bugfix][badge-bugfix] `makedocs` now throws an error when the format objects (`Documenter.HTML`, `LaTeX`, `Markdown`) get passed positionally. The format types are no longer subtypes of `Documenter.Plugin`. ([#1046][github-1046], [#1061][github-1061])

* ![Bugfix][badge-bugfix] Doctesting now also handles doctests that contain invalid syntax and throw parsing errors. ([#487][github-487], [#1062][github-1062])

* ![Bugfix][badge-bugfix] Stacktraces in doctests that throw an error are now filtered more thoroughly, fixing an issue where too much of the stacktrace was included when `doctest` or `makedocs` was called from a more complicated context. ([#1062][github-1062])

* ![Experimental][badge-experimental] ![Feature][badge-feature] The current working directory when evaluating `@repl` and `@example` blocks can now be set to a fixed directory by passing the `workdir` keyword to `makedocs`. _The new keyword and its behaviour are experimental and not part of the public API._ ([#1013][github-1013], [#1025][github-1025])

## Version `v0.22.6`

* ![Maintenance][badge-maintenance] Add DocStringExtensions 0.8 as an allowed dependency version. ([#1071][github-1071])

## Version `v0.22.5`

* ![Maintenance][badge-maintenance] Fix a test dependency problem revealed by a bugfix in Julia / Pkg. ([#1037][github-1037])

## Version `v0.22.4`

* ![Bugfix][badge-bugfix] Documenter no longer crashes if the build includes doctests from docstrings that are defined in files that do not exist on the file system (e.g. if a Julia Base docstring is included when running a non-source Julia build). ([#1002][github-1002])

* ![Bugfix][badge-bugfix] URLs for files in the repository are now generated correctly when the repository is used as a Git submodule in another repository. ([#1000][github-1000], [#1004][github-1004])

* ![Bugfix][badge-bugfix] When checking for omitted docstrings, Documenter no longer gives "`Package.Package` missing" type false positives. ([#1009][github-1009])

* ![Bugfix][badge-bugfix] `makedocs` again exits with an error if `strict=true` and there is a doctest failure. ([#1003][github-1003], [#1014][github-1014])

## Version `v0.22.3`

* ![Bugfix][badge-bugfix] Fixed filepaths for images included in the .tex file for PDF output on Windows. ([#999][github-999])

## Version `v0.22.2`

* ![Bugfix][badge-bugfix] Error reporting for meta-blocks now handles missing files gracefully instead of throwing. ([#996][github-996])

* ![Enhancement][badge-enhancement] The `sitename` keyword argument to `deploydocs`, which is required for the default HTML output, is now properly documented. ([#995][github-995])

## Version `v0.22.1`

* ![Bugfix][badge-bugfix] Fixed a world-age related bug in doctests. ([#994][github-994])

## Version `v0.22.0`

* ![Deprecation][badge-deprecation] ![Enhancement][badge-enhancement] The `assets` and `analytics` arguments to `makedocs` have been deprecated in favor of the corresponding arguments of the `Documenter.HTML` format plugin. ([#953][github-953])

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

* ![Enhancement][badge-enhancement] Documentation is no longer deployed on Travis CI cron jobs. ([#917][github-917])

* ![Enhancement][badge-enhancement] Log messages from failed `@meta`, `@docs`, `@autodocs`,
  `@eval`, `@example` and `@setup` blocks now include information about the source location
  of the block. ([#929][github-929])

* ![Enhancement][badge-enhancement] Docstrings from `@docs`-blocks are now included in the
  rendered docs even if some part(s) of the block failed. ([#928][github-928], [#935][github-935])

* ![Enhancement][badge-enhancement] The Markdown and LaTeX output writers can now handle multimedia
  output, such as images, from `@example` blocks. All the writers now also handle `text/markdown`
  output, which is preferred over `text/plain` if available. ([#938][github-938], [#948][github-948])

* ![Enhancement][badge-enhancement] The HTML output now also supports SVG, WebP, GIF and JPEG logos. ([#953][github-953])

* ![Enhancement][badge-enhancement] Reporting of failed doctests are now using the logging
  system to be consistent with the rest of Documenter's output. ([#958][github-958])

* ![Enhancement][badge-enhancement] The construction of the search index in the HTML output has been refactored to make it easier to use with other search backends in the future. The structure of the generated search index has also been modified, which can yield slightly different search results. Documenter now depends on the lightweight [JSON.jl][json-jl] package. ([#966][github-966])

* ![Enhancement][badge-enhancement] Docstrings that begin with an indented code block (such as a function signature) now have that block highlighted as Julia code by default.
  This behaviour can be disabled by passing `highlightsig=false` to `makedocs`. ([#980][github-980])

* ![Bugfix][badge-bugfix] Paths in `include` calls in `@eval`, `@example`, `@repl` and `jldoctest`
  blocks are now interpreted to be relative `pwd`, which is set to the output directory of the
  resulting file. ([#941][github-941])

* ![Bugfix][badge-bugfix] `deploydocs` and `git_push` now support non-github repos correctly and work when the `.ssh` directory does not already exist or the working directory contains spaces. ([#971][github-971])

* ![Bugfix][badge-bugfix] Tables now honor column alignment in the HTML output. If a column does not explicitly specify its alignment, the parser defaults to it being right-aligned, whereas previously all cells were left-aligned. ([#511][github-511], [#989][github-989])

* ![Bugfix][badge-bugfix] Code lines ending with `# hide` are now properly hidden for CRLF inputs. ([#991][github-991])

## Version `v0.21.5`

* ![Bugfix][badge-bugfix] Deprecation warnings for `format` now get printed correctly when multiple formats are passed as a `Vector`. ([#967][github-967])

## Version `v0.21.4`

* ![Bugfix][badge-bugfix] A bug in `jldoctest`-blocks that, in rare cases, resulted in
  wrong output has been fixed. ([#959][github-959], [#960][github-960])

## Version `v0.21.3`

* ![Security][badge-security] The lunr.js and lodash JavaScript dependencies have been updated to their latest patch versions (from 2.3.1 to 2.3.5 and 4.17.4 to 4.17.11, respectively).
  This is in response to a vulnerability in lodash <4.17.11 ([CVE-2018-16487](https://nvd.nist.gov/vuln/detail/CVE-2018-16487)). ([#946][github-946])

## Version `v0.21.2`

* ![Bugfix][badge-bugfix] `linkcheck` now handles servers that do not support `HEAD` requests
  and properly checks for status codes of FTP responses. ([#934][github-934])

## Version `v0.21.1`

* ![Bugfix][badge-bugfix] `@repl` blocks now work correctly together with quoted
  expressions. ([#923][github-923], [#926][github-926])

* ![Bugfix][badge-bugfix] `@example`, `@repl` and `@eval` blocks now handle reserved words,
  e.g. `try`/`catch`, correctly. ([#886][github-886], [#927][github-927])

## Version `v0.21.0`

* ![Deprecation][badge-deprecation] ![Enhancement][badge-enhancement] The symbol values to the `format` argument of `makedocs` (`:html`, `:markdown`, `:latex`) have been deprecated in favor of the `Documenter.HTML`, `Markdown` and `LaTeX`
  objects. The `Markdown` and `LaTeX` types are exported from the [DocumenterMarkdown][documentermarkdown] and [DocumenterLaTeX][documenterlatex] packages,
  respectively. HTML output is still the default. ([#891][github-891])

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

* ![Deprecation][badge-deprecation] ![Enhancement][badge-enhancement] The `html_prettyurls`, `html_canonical`, `html_disable_git` and `html_edit_branch` arguments to `makedocs` have been deprecated in favor of the corresponding arguments of the `Documenter.HTML` format plugin. ([#864][github-864], [#891][github-891])

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

* ![Feature][badge-feature] Packages extending Documenter can now define subtypes of `Documenter.Plugin`,
  which can be passed to `makedocs` as positional arguments to pass options to the extensions. ([#864][github-864])

* ![Feature][badge-feature] `@autodocs` blocks now support the `Filter` keyword, which allows passing a user-defined function that will filter the methods spliced in by the at-autodocs block. ([#885][github-885])

* ![Enhancement][badge-enhancement] `linkcheck` now supports checking URLs using the FTP protocol. ([#879][github-879])

* ![Enhancement][badge-enhancement] Build output logging has been improved and switched to the logging macros from `Base`. ([#876][github-876])

* ![Enhancement][badge-enhancement] The default `documenter.sty` LaTeX preamble now include `\usepackage{graphicx}`. ([#898][github-898])

* ![Enhancement][badge-enhancement] `deploydocs` is now more helpful when it fails to interpret `DOCUMENTER_KEY`. It now also uses the `BatchMode` SSH option and throws an error instead of asking for a passphrase and timing out the Travis build when `DOCUMENTER_KEY` is broken. ([#697][github-697], [#907][github-907])

* ![Enhancement][badge-enhancement] `deploydocs` now have a `forcepush` keyword argument that can be used to
  force-push the built documentation instead of adding a new commit. ([#905][github-905])

## Version `v0.20.0`

* Documenter v0.20 requires at least Julia v0.7. ([#795][github-795])

* ![BREAKING][badge-breaking] Documentation deployment via the `deploydocs` function has changed considerably.

  - The user-facing directories (URLs) of different versions and what gets displayed in the version selector have changed. By default, Documenter now creates the `stable/` directory (as before) and a directory for every minor version (`vX.Y/`). The `release-X.Y` directories are no longer created. ([#706][github-706], [#813][github-813], [#817][github-817])

    Technically, Documenter now deploys actual files only to `dev/` and `vX.Y.Z/` directories. The directories (URLs) that change from version to version (e.g. `latest/`, `vX.Y`) are implemented as symlinks on the `gh-pages` branch.

    The version selector will only display `vX.Y/`, `stable/` and `dev/` directories by default. This behavior can be customized with the `versions` keyword of `deploydocs`.

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

* ![Enhancement][badge-enhancement] Enhancements to the sidebar. When loading a page, the sidebar will jump to the current page now. Also, the scrollbar in WebKit-based browsers look less intrusive now. ([#792][github-792], [#854][github-854], [#863][github-863])

* ![Enhancement][badge-enhancement] Minor style enhancements to admonitions. ([#841][github-841])

* ![Bugfix][badge-bugfix] The at-blocks that execute code can now handle `include` statements. ([#793][github-793], [#794][github-794])

* ![Bugfix][badge-bugfix] At-docs blocks no longer give an error when containing empty lines. ([#823][github-823], [#824][github-824])

<!-- issue link definitions -->
[github-198]: https://github.com/JuliaDocs/Documenter.jl/issues/198
[github-245]: https://github.com/JuliaDocs/Documenter.jl/issues/245
[github-487]: https://github.com/JuliaDocs/Documenter.jl/issues/487
[github-491]: https://github.com/JuliaDocs/Documenter.jl/issues/491
[github-505]: https://github.com/JuliaDocs/Documenter.jl/issues/505
[github-511]: https://github.com/JuliaDocs/Documenter.jl/issues/511
[github-535]: https://github.com/JuliaDocs/Documenter.jl/issues/535
[github-618]: https://github.com/JuliaDocs/Documenter.jl/issues/618
[github-631]: https://github.com/JuliaDocs/Documenter.jl/issues/631
[github-697]: https://github.com/JuliaDocs/Documenter.jl/issues/697
[github-706]: https://github.com/JuliaDocs/Documenter.jl/pull/706
[github-756]: https://github.com/JuliaDocs/Documenter.jl/issues/756
[github-764]: https://github.com/JuliaDocs/Documenter.jl/pull/764
[github-774]: https://github.com/JuliaDocs/Documenter.jl/pull/774
[github-781]: https://github.com/JuliaDocs/Documenter.jl/issues/781
[github-789]: https://github.com/JuliaDocs/Documenter.jl/pull/789
[github-792]: https://github.com/JuliaDocs/Documenter.jl/pull/792
[github-793]: https://github.com/JuliaDocs/Documenter.jl/issues/793
[github-794]: https://github.com/JuliaDocs/Documenter.jl/pull/794
[github-795]: https://github.com/JuliaDocs/Documenter.jl/pull/795
[github-802]: https://github.com/JuliaDocs/Documenter.jl/pull/802
[github-803]: https://github.com/JuliaDocs/Documenter.jl/issues/803
[github-804]: https://github.com/JuliaDocs/Documenter.jl/pull/804
[github-813]: https://github.com/JuliaDocs/Documenter.jl/pull/813
[github-816]: https://github.com/JuliaDocs/Documenter.jl/pull/816
[github-817]: https://github.com/JuliaDocs/Documenter.jl/pull/817
[github-823]: https://github.com/JuliaDocs/Documenter.jl/issues/823
[github-824]: https://github.com/JuliaDocs/Documenter.jl/pull/824
[github-826]: https://github.com/JuliaDocs/Documenter.jl/pull/826
[github-833]: https://github.com/JuliaDocs/Documenter.jl/pull/833
[github-841]: https://github.com/JuliaDocs/Documenter.jl/pull/841
[github-854]: https://github.com/JuliaDocs/Documenter.jl/pull/854
[github-863]: https://github.com/JuliaDocs/Documenter.jl/pull/863
[github-864]: https://github.com/JuliaDocs/Documenter.jl/pull/864
[github-876]: https://github.com/JuliaDocs/Documenter.jl/pull/876
[github-879]: https://github.com/JuliaDocs/Documenter.jl/pull/879
[github-885]: https://github.com/JuliaDocs/Documenter.jl/pull/885
[github-886]: https://github.com/JuliaDocs/Documenter.jl/issues/886
[github-890]: https://github.com/JuliaDocs/Documenter.jl/issues/890
[github-891]: https://github.com/JuliaDocs/Documenter.jl/pull/891
[github-898]: https://github.com/JuliaDocs/Documenter.jl/pull/898
[github-905]: https://github.com/JuliaDocs/Documenter.jl/pull/905
[github-907]: https://github.com/JuliaDocs/Documenter.jl/pull/907
[github-917]: https://github.com/JuliaDocs/Documenter.jl/pull/917
[github-923]: https://github.com/JuliaDocs/Documenter.jl/issues/923
[github-926]: https://github.com/JuliaDocs/Documenter.jl/pull/926
[github-927]: https://github.com/JuliaDocs/Documenter.jl/pull/927
[github-928]: https://github.com/JuliaDocs/Documenter.jl/pull/928
[github-929]: https://github.com/JuliaDocs/Documenter.jl/pull/929
[github-934]: https://github.com/JuliaDocs/Documenter.jl/pull/934
[github-935]: https://github.com/JuliaDocs/Documenter.jl/pull/935
[github-937]: https://github.com/JuliaDocs/Documenter.jl/issues/937
[github-938]: https://github.com/JuliaDocs/Documenter.jl/pull/938
[github-941]: https://github.com/JuliaDocs/Documenter.jl/pull/941
[github-946]: https://github.com/JuliaDocs/Documenter.jl/pull/946
[github-948]: https://github.com/JuliaDocs/Documenter.jl/pull/948
[github-953]: https://github.com/JuliaDocs/Documenter.jl/pull/953
[github-958]: https://github.com/JuliaDocs/Documenter.jl/pull/958
[github-959]: https://github.com/JuliaDocs/Documenter.jl/issues/959
[github-960]: https://github.com/JuliaDocs/Documenter.jl/pull/960
[github-964]: https://github.com/JuliaDocs/Documenter.jl/issues/964
[github-966]: https://github.com/JuliaDocs/Documenter.jl/pull/966
[github-967]: https://github.com/JuliaDocs/Documenter.jl/pull/967
[github-971]: https://github.com/JuliaDocs/Documenter.jl/pull/971
[github-974]: https://github.com/JuliaDocs/Documenter.jl/issues/974
[github-980]: https://github.com/JuliaDocs/Documenter.jl/pull/980
[github-989]: https://github.com/JuliaDocs/Documenter.jl/pull/989
[github-991]: https://github.com/JuliaDocs/Documenter.jl/pull/991
[github-994]: https://github.com/JuliaDocs/Documenter.jl/pull/994
[github-995]: https://github.com/JuliaDocs/Documenter.jl/pull/995
[github-996]: https://github.com/JuliaDocs/Documenter.jl/pull/996
[github-999]: https://github.com/JuliaDocs/Documenter.jl/pull/999
[github-1000]: https://github.com/JuliaDocs/Documenter.jl/issues/1000
[github-1002]: https://github.com/JuliaDocs/Documenter.jl/pull/1002
[github-1003]: https://github.com/JuliaDocs/Documenter.jl/issues/1003
[github-1004]: https://github.com/JuliaDocs/Documenter.jl/pull/1004
[github-1005]: https://github.com/JuliaDocs/Documenter.jl/pull/1005
[github-1009]: https://github.com/JuliaDocs/Documenter.jl/pull/1009
[github-1013]: https://github.com/JuliaDocs/Documenter.jl/issues/1013
[github-1014]: https://github.com/JuliaDocs/Documenter.jl/pull/1014
[github-1015]: https://github.com/JuliaDocs/Documenter.jl/pull/1015
[github-1025]: https://github.com/JuliaDocs/Documenter.jl/pull/1025
[github-1026]: https://github.com/JuliaDocs/Documenter.jl/issues/1026
[github-1027]: https://github.com/JuliaDocs/Documenter.jl/issues/1027
[github-1028]: https://github.com/JuliaDocs/Documenter.jl/pull/1028
[github-1029]: https://github.com/JuliaDocs/Documenter.jl/pull/1029
[github-1031]: https://github.com/JuliaDocs/Documenter.jl/issues/1031
[github-1034]: https://github.com/JuliaDocs/Documenter.jl/pull/1034
[github-1037]: https://github.com/JuliaDocs/Documenter.jl/pull/1037
[github-1043]: https://github.com/JuliaDocs/Documenter.jl/pull/1043
[github-1046]: https://github.com/JuliaDocs/Documenter.jl/issues/1046
[github-1047]: https://github.com/JuliaDocs/Documenter.jl/pull/1047
[github-1054]: https://github.com/JuliaDocs/Documenter.jl/pull/1054
[github-1057]: https://github.com/JuliaDocs/Documenter.jl/issues/1057
[github-1061]: https://github.com/JuliaDocs/Documenter.jl/pull/1061
[github-1062]: https://github.com/JuliaDocs/Documenter.jl/pull/1062
[github-1066]: https://github.com/JuliaDocs/Documenter.jl/pull/1066
[github-1071]: https://github.com/JuliaDocs/Documenter.jl/pull/1071
[github-1073]: https://github.com/JuliaDocs/Documenter.jl/issues/1073
[github-1075]: https://github.com/JuliaDocs/Documenter.jl/pull/1075
[github-1076]: https://github.com/JuliaDocs/Documenter.jl/issues/1076
[github-1077]: https://github.com/JuliaDocs/Documenter.jl/pull/1077
[github-1081]: https://github.com/JuliaDocs/Documenter.jl/issues/1081
[github-1082]: https://github.com/JuliaDocs/Documenter.jl/pull/1082
[github-1088]: https://github.com/JuliaDocs/Documenter.jl/issues/1088
[github-1089]: https://github.com/JuliaDocs/Documenter.jl/pull/1089
[github-1094]: https://github.com/JuliaDocs/Documenter.jl/pull/1094
[github-1097]: https://github.com/JuliaDocs/Documenter.jl/pull/1097
[github-1107]: https://github.com/JuliaDocs/Documenter.jl/pull/1107
[github-1108]: https://github.com/JuliaDocs/Documenter.jl/pull/1108
[github-1112]: https://github.com/JuliaDocs/Documenter.jl/pull/1112
[github-1113]: https://github.com/JuliaDocs/Documenter.jl/pull/1113
[github-1115]: https://github.com/JuliaDocs/Documenter.jl/pull/1115
[github-1118]: https://github.com/JuliaDocs/Documenter.jl/issues/1118
[github-1119]: https://github.com/JuliaDocs/Documenter.jl/pull/1119
[github-1121]: https://github.com/JuliaDocs/Documenter.jl/pull/1121
[github-1137]: https://github.com/JuliaDocs/Documenter.jl/pull/1137
[github-1144]: https://github.com/JuliaDocs/Documenter.jl/pull/1144
[github-1147]: https://github.com/JuliaDocs/Documenter.jl/pull/1147
[github-1148]: https://github.com/JuliaDocs/Documenter.jl/issues/1148
[github-1151]: https://github.com/JuliaDocs/Documenter.jl/pull/1151
[github-1152]: https://github.com/JuliaDocs/Documenter.jl/pull/1152
[github-1153]: https://github.com/JuliaDocs/Documenter.jl/pull/1153
[github-1166]: https://github.com/JuliaDocs/Documenter.jl/pull/1166
[github-1171]: https://github.com/JuliaDocs/Documenter.jl/pull/1171
[github-1173]: https://github.com/JuliaDocs/Documenter.jl/pull/1173
[github-1180]: https://github.com/JuliaDocs/Documenter.jl/pull/1180
[github-1184]: https://github.com/JuliaDocs/Documenter.jl/issues/1184
[github-1186]: https://github.com/JuliaDocs/Documenter.jl/pull/1186
[github-1189]: https://github.com/JuliaDocs/Documenter.jl/pull/1189
[github-1192]: https://github.com/JuliaDocs/Documenter.jl/issues/1192
[github-1194]: https://github.com/JuliaDocs/Documenter.jl/pull/1194
[github-1195]: https://github.com/JuliaDocs/Documenter.jl/pull/1195
[github-1200]: https://github.com/JuliaDocs/Documenter.jl/issues/1200
[github-1201]: https://github.com/JuliaDocs/Documenter.jl/issues/1201
[github-1212]: https://github.com/JuliaDocs/Documenter.jl/issues/1212
[github-1216]: https://github.com/JuliaDocs/Documenter.jl/pull/1216
[github-1222]: https://github.com/JuliaDocs/Documenter.jl/pull/1222
[github-1223]: https://github.com/JuliaDocs/Documenter.jl/pull/1223
[github-1232]: https://github.com/JuliaDocs/Documenter.jl/pull/1232
[github-1240]: https://github.com/JuliaDocs/Documenter.jl/pull/1240
[github-1254]: https://github.com/JuliaDocs/Documenter.jl/pull/1254
[github-1258]: https://github.com/JuliaDocs/Documenter.jl/pull/1258
[github-1264]: https://github.com/JuliaDocs/Documenter.jl/pull/1264
[github-1269]: https://github.com/JuliaDocs/Documenter.jl/pull/1269
[github-1278]: https://github.com/JuliaDocs/Documenter.jl/issues/1278
[github-1279]: https://github.com/JuliaDocs/Documenter.jl/issues/1279
[github-1280]: https://github.com/JuliaDocs/Documenter.jl/pull/1280
[github-1283]: https://github.com/JuliaDocs/Documenter.jl/pull/1283
[github-1285]: https://github.com/JuliaDocs/Documenter.jl/pull/1285
[github-1292]: https://github.com/JuliaDocs/Documenter.jl/pull/1292
[github-1293]: https://github.com/JuliaDocs/Documenter.jl/pull/1293
[github-1295]: https://github.com/JuliaDocs/Documenter.jl/pull/1295
[github-1298]: https://github.com/JuliaDocs/Documenter.jl/pull/1298
[github-1299]: https://github.com/JuliaDocs/Documenter.jl/pull/1299
[github-1302]: https://github.com/JuliaDocs/Documenter.jl/issues/1302
[github-1307]: https://github.com/JuliaDocs/Documenter.jl/pull/1307
[github-1310]: https://github.com/JuliaDocs/Documenter.jl/pull/1310
[github-1311]: https://github.com/JuliaDocs/Documenter.jl/pull/1311
[github-1315]: https://github.com/JuliaDocs/Documenter.jl/pull/1315
[github-1320]: https://github.com/JuliaDocs/Documenter.jl/issues/1320
[github-1323]: https://github.com/JuliaDocs/Documenter.jl/pull/1323
[github-1328]: https://github.com/JuliaDocs/Documenter.jl/pull/1328
[github-1337]: https://github.com/JuliaDocs/Documenter.jl/issues/1337
[github-1338]: https://github.com/JuliaDocs/Documenter.jl/issues/1338
[github-1339]: https://github.com/JuliaDocs/Documenter.jl/pull/1339
[github-1342]: https://github.com/JuliaDocs/Documenter.jl/issues/1342
[github-1344]: https://github.com/JuliaDocs/Documenter.jl/issues/1344
[github-1345]: https://github.com/JuliaDocs/Documenter.jl/pull/1345
[github-1349]: https://github.com/JuliaDocs/Documenter.jl/pull/1349
[github-1355]: https://github.com/JuliaDocs/Documenter.jl/pull/1355
[github-1357]: https://github.com/JuliaDocs/Documenter.jl/pull/1357
[github-1360]: https://github.com/JuliaDocs/Documenter.jl/pull/1360
[github-1362]: https://github.com/JuliaDocs/Documenter.jl/issues/1362
[github-1364]: https://github.com/JuliaDocs/Documenter.jl/issues/1364
[github-1365]: https://github.com/JuliaDocs/Documenter.jl/pull/1365
[github-1367]: https://github.com/JuliaDocs/Documenter.jl/pull/1367
[github-1368]: https://github.com/JuliaDocs/Documenter.jl/pull/1368
[github-1369]: https://github.com/JuliaDocs/Documenter.jl/pull/1369
[github-1379]: https://github.com/JuliaDocs/Documenter.jl/issues/1379
[github-1388]: https://github.com/JuliaDocs/Documenter.jl/pull/1388
[github-1389]: https://github.com/JuliaDocs/Documenter.jl/pull/1389
[github-1392]: https://github.com/JuliaDocs/Documenter.jl/pull/1392
[github-1400]: https://github.com/JuliaDocs/Documenter.jl/pull/1400
[github-1426]: https://github.com/JuliaDocs/Documenter.jl/pull/1426
[github-1428]: https://github.com/JuliaDocs/Documenter.jl/issues/1428
[github-1430]: https://github.com/JuliaDocs/Documenter.jl/pull/1430
[github-1435]: https://github.com/JuliaDocs/Documenter.jl/pull/1435
[github-1438]: https://github.com/JuliaDocs/Documenter.jl/issues/1438
[github-1440]: https://github.com/JuliaDocs/Documenter.jl/pull/1440
[github-1441]: https://github.com/JuliaDocs/Documenter.jl/pull/1441
[github-1443]: https://github.com/JuliaDocs/Documenter.jl/issues/1443
[github-1448]: https://github.com/JuliaDocs/Documenter.jl/pull/1448
[github-1449]: https://github.com/JuliaDocs/Documenter.jl/issues/1449
[github-1452]: https://github.com/JuliaDocs/Documenter.jl/pull/1452
[github-1456]: https://github.com/JuliaDocs/Documenter.jl/pull/1456
[github-1462]: https://github.com/JuliaDocs/Documenter.jl/issues/1462
[github-1463]: https://github.com/JuliaDocs/Documenter.jl/pull/1463
[github-1466]: https://github.com/JuliaDocs/Documenter.jl/issues/1466
[github-1468]: https://github.com/JuliaDocs/Documenter.jl/pull/1468
[github-1469]: https://github.com/JuliaDocs/Documenter.jl/pull/1469
[github-1470]: https://github.com/JuliaDocs/Documenter.jl/issues/1470
[github-1471]: https://github.com/JuliaDocs/Documenter.jl/pull/1471
[github-1472]: https://github.com/JuliaDocs/Documenter.jl/pull/1472
[github-1474]: https://github.com/JuliaDocs/Documenter.jl/pull/1474
[github-1476]: https://github.com/JuliaDocs/Documenter.jl/pull/1476
[github-1489]: https://github.com/JuliaDocs/Documenter.jl/pull/1489
[github-1491]: https://github.com/JuliaDocs/Documenter.jl/pull/1491
[github-1493]: https://github.com/JuliaDocs/Documenter.jl/pull/1493
[github-1497]: https://github.com/JuliaDocs/Documenter.jl/pull/1497
[github-1503]: https://github.com/JuliaDocs/Documenter.jl/pull/1503
[github-1510]: https://github.com/JuliaDocs/Documenter.jl/pull/1510
[github-1511]: https://github.com/JuliaDocs/Documenter.jl/pull/1511
[github-1513]: https://github.com/JuliaDocs/Documenter.jl/issues/1513
[github-1516]: https://github.com/JuliaDocs/Documenter.jl/issues/1516
[github-1518]: https://github.com/JuliaDocs/Documenter.jl/pull/1518
[github-1519]: https://github.com/JuliaDocs/Documenter.jl/pull/1519
[github-1520]: https://github.com/JuliaDocs/Documenter.jl/pull/1520
[github-1526]: https://github.com/JuliaDocs/Documenter.jl/pull/1526
[github-1527]: https://github.com/JuliaDocs/Documenter.jl/pull/1527
[github-1529]: https://github.com/JuliaDocs/Documenter.jl/pull/1529
[github-1531]: https://github.com/JuliaDocs/Documenter.jl/issues/1531
[github-1533]: https://github.com/JuliaDocs/Documenter.jl/pull/1533
[github-1534]: https://github.com/JuliaDocs/Documenter.jl/issues/1534
[github-1537]: https://github.com/JuliaDocs/Documenter.jl/issues/1537
[github-1538]: https://github.com/JuliaDocs/Documenter.jl/pull/1538
[github-1540]: https://github.com/JuliaDocs/Documenter.jl/pull/1540
[github-1549]: https://github.com/JuliaDocs/Documenter.jl/pull/1549
[github-1551]: https://github.com/JuliaDocs/Documenter.jl/pull/1551
[github-1553]: https://github.com/JuliaDocs/Documenter.jl/pull/1553
[github-1554]: https://github.com/JuliaDocs/Documenter.jl/issues/1554
[github-1556]: https://github.com/JuliaDocs/Documenter.jl/issues/1556
[github-1557]: https://github.com/JuliaDocs/Documenter.jl/pull/1557
[github-1559]: https://github.com/JuliaDocs/Documenter.jl/pull/1559
[github-1561]: https://github.com/JuliaDocs/Documenter.jl/issues/1561
[github-1567]: https://github.com/JuliaDocs/Documenter.jl/pull/1567
[github-1568]: https://github.com/JuliaDocs/Documenter.jl/issues/1568
[github-1569]: https://github.com/JuliaDocs/Documenter.jl/pull/1569
[github-1575]: https://github.com/JuliaDocs/Documenter.jl/issues/1575
[github-1577]: https://github.com/JuliaDocs/Documenter.jl/pull/1577
[github-1590]: https://github.com/JuliaDocs/Documenter.jl/pull/1590
[github-1594]: https://github.com/JuliaDocs/Documenter.jl/issues/1594
[github-1595]: https://github.com/JuliaDocs/Documenter.jl/pull/1595
[github-1596]: https://github.com/JuliaDocs/Documenter.jl/pull/1596
[github-1602]: https://github.com/JuliaDocs/Documenter.jl/issues/1602
[github-1604]: https://github.com/JuliaDocs/Documenter.jl/pull/1604
[github-1609]: https://github.com/JuliaDocs/Documenter.jl/pull/1609
[github-1610]: https://github.com/JuliaDocs/Documenter.jl/issues/1610
[github-1611]: https://github.com/JuliaDocs/Documenter.jl/pull/1611
[github-1615]: https://github.com/JuliaDocs/Documenter.jl/issues/1615
[github-1616]: https://github.com/JuliaDocs/Documenter.jl/pull/1616
[github-1617]: https://github.com/JuliaDocs/Documenter.jl/pull/1617
[github-1625]: https://github.com/JuliaDocs/Documenter.jl/pull/1625
[github-1627]: https://github.com/JuliaDocs/Documenter.jl/pull/1627
[github-1628]: https://github.com/JuliaDocs/Documenter.jl/pull/1628
[github-1629]: https://github.com/JuliaDocs/Documenter.jl/issues/1629
[github-1633]: https://github.com/JuliaDocs/Documenter.jl/pull/1633
[github-1634]: https://github.com/JuliaDocs/Documenter.jl/pull/1634
[github-1639]: https://github.com/JuliaDocs/Documenter.jl/issues/1639
[github-1641]: https://github.com/JuliaDocs/Documenter.jl/pull/1641
[github-1645]: https://github.com/JuliaDocs/Documenter.jl/pull/1645
[github-1647]: https://github.com/JuliaDocs/Documenter.jl/pull/1647
[github-1649]: https://github.com/JuliaDocs/Documenter.jl/pull/1649
[github-1655]: https://github.com/JuliaDocs/Documenter.jl/issues/1655
[github-1657]: https://github.com/JuliaDocs/Documenter.jl/pull/1657
[github-1658]: https://github.com/JuliaDocs/Documenter.jl/pull/1658
[github-1661]: https://github.com/JuliaDocs/Documenter.jl/pull/1661
[github-1665]: https://github.com/JuliaDocs/Documenter.jl/pull/1665
[github-1667]: https://github.com/JuliaDocs/Documenter.jl/issues/1667
[github-1673]: https://github.com/JuliaDocs/Documenter.jl/pull/1673
[github-1687]: https://github.com/JuliaDocs/Documenter.jl/pull/1687
[github-1689]: https://github.com/JuliaDocs/Documenter.jl/pull/1689
[github-1691]: https://github.com/JuliaDocs/Documenter.jl/pull/1691
[github-1693]: https://github.com/JuliaDocs/Documenter.jl/issues/1693
[github-1695]: https://github.com/JuliaDocs/Documenter.jl/issues/1695
[github-1696]: https://github.com/JuliaDocs/Documenter.jl/pull/1696
[github-1698]: https://github.com/JuliaDocs/Documenter.jl/issues/1698
[github-1699]: https://github.com/JuliaDocs/Documenter.jl/pull/1699
[github-1704]: https://github.com/JuliaDocs/Documenter.jl/pull/1704
[github-1706]: https://github.com/JuliaDocs/Documenter.jl/pull/1706
[github-1709]: https://github.com/JuliaDocs/Documenter.jl/pull/1709
[github-1716]: https://github.com/JuliaDocs/Documenter.jl/pull/1716
[github-1727]: https://github.com/JuliaDocs/Documenter.jl/pull/1727
[github-1728]: https://github.com/JuliaDocs/Documenter.jl/issues/1728
[github-1743]: https://github.com/JuliaDocs/Documenter.jl/pull/1743
[github-1746]: https://github.com/JuliaDocs/Documenter.jl/issues/1746
[github-1748]: https://github.com/JuliaDocs/Documenter.jl/pull/1748
[github-1750]: https://github.com/JuliaDocs/Documenter.jl/pull/1750
[github-1751]: https://github.com/JuliaDocs/Documenter.jl/pull/1751
[github-1752]: https://github.com/JuliaDocs/Documenter.jl/pull/1752
[github-1754]: https://github.com/JuliaDocs/Documenter.jl/pull/1754
[github-1756]: https://github.com/JuliaDocs/Documenter.jl/issues/1756
[github-1758]: https://github.com/JuliaDocs/Documenter.jl/issues/1758
[github-1759]: https://github.com/JuliaDocs/Documenter.jl/pull/1759
[github-1760]: https://github.com/JuliaDocs/Documenter.jl/issues/1760
[github-1762]: https://github.com/JuliaDocs/Documenter.jl/pull/1762
[github-1770]: https://github.com/JuliaDocs/Documenter.jl/issues/1770
[github-1771]: https://github.com/JuliaDocs/Documenter.jl/pull/1771
[github-1772]: https://github.com/JuliaDocs/Documenter.jl/issues/1772
[github-1773]: https://github.com/JuliaDocs/Documenter.jl/pull/1773
[github-1774]: https://github.com/JuliaDocs/Documenter.jl/pull/1774
[github-1776]: https://github.com/JuliaDocs/Documenter.jl/pull/1776
[github-1780]: https://github.com/JuliaDocs/Documenter.jl/issues/1780
[github-1784]: https://github.com/JuliaDocs/Documenter.jl/pull/1784
[github-1785]: https://github.com/JuliaDocs/Documenter.jl/pull/1785
[github-1788]: https://github.com/JuliaDocs/Documenter.jl/pull/1788
[github-1795]: https://github.com/JuliaDocs/Documenter.jl/pull/1795
[github-1796]: https://github.com/JuliaDocs/Documenter.jl/pull/1796
[github-1797]: https://github.com/JuliaDocs/Documenter.jl/pull/1797
[github-1802]: https://github.com/JuliaDocs/Documenter.jl/issues/1802
[github-1803]: https://github.com/JuliaDocs/Documenter.jl/pull/1803
[github-1805]: https://github.com/JuliaDocs/Documenter.jl/pull/1805
[github-1806]: https://github.com/JuliaDocs/Documenter.jl/pull/1806
[github-1807]: https://github.com/JuliaDocs/Documenter.jl/pull/1807
[github-1808]: https://github.com/JuliaDocs/Documenter.jl/pull/1808
[github-1810]: https://github.com/JuliaDocs/Documenter.jl/issues/1810
[github-1811]: https://github.com/JuliaDocs/Documenter.jl/pull/1811
[github-1814]: https://github.com/JuliaDocs/Documenter.jl/issues/1814
[github-1816]: https://github.com/JuliaDocs/Documenter.jl/pull/1816
[github-1818]: https://github.com/JuliaDocs/Documenter.jl/pull/1818
[github-1821]: https://github.com/JuliaDocs/Documenter.jl/pull/1821
[github-1825]: https://github.com/JuliaDocs/Documenter.jl/pull/1825
[github-1826]: https://github.com/JuliaDocs/Documenter.jl/pull/1826
[github-1827]: https://github.com/JuliaDocs/Documenter.jl/issues/1827
[github-1828]: https://github.com/JuliaDocs/Documenter.jl/pull/1828
[github-1829]: https://github.com/JuliaDocs/Documenter.jl/pull/1829
[github-1833]: https://github.com/JuliaDocs/Documenter.jl/pull/1833
[github-1834]: https://github.com/JuliaDocs/Documenter.jl/pull/1834
[github-1835]: https://github.com/JuliaDocs/Documenter.jl/issues/1835
[github-1836]: https://github.com/JuliaDocs/Documenter.jl/pull/1836
[github-1838]: https://github.com/JuliaDocs/Documenter.jl/pull/1838
[github-1841]: https://github.com/JuliaDocs/Documenter.jl/pull/1841
[github-1842]: https://github.com/JuliaDocs/Documenter.jl/pull/1842
[github-1844]: https://github.com/JuliaDocs/Documenter.jl/pull/1844
[github-1846]: https://github.com/JuliaDocs/Documenter.jl/pull/1846
[github-1857]: https://github.com/JuliaDocs/Documenter.jl/issues/1857
[github-1861]: https://github.com/JuliaDocs/Documenter.jl/pull/1861
[github-1862]: https://github.com/JuliaDocs/Documenter.jl/pull/1862
[github-1865]: https://github.com/JuliaDocs/Documenter.jl/pull/1865
[github-1870]: https://github.com/JuliaDocs/Documenter.jl/issues/1870
[github-1871]: https://github.com/JuliaDocs/Documenter.jl/pull/1871
[github-1880]: https://github.com/JuliaDocs/Documenter.jl/pull/1880
[github-1881]: https://github.com/JuliaDocs/Documenter.jl/pull/1881
[github-1885]: https://github.com/JuliaDocs/Documenter.jl/issues/1885
[github-1886]: https://github.com/JuliaDocs/Documenter.jl/pull/1886
[github-1890]: https://github.com/JuliaDocs/Documenter.jl/pull/1890
[github-1892]: https://github.com/JuliaDocs/Documenter.jl/pull/1892
[github-1900]: https://github.com/JuliaDocs/Documenter.jl/pull/1900
[github-1903]: https://github.com/JuliaDocs/Documenter.jl/pull/1903
[github-1906]: https://github.com/JuliaDocs/Documenter.jl/pull/1906
[github-1908]: https://github.com/JuliaDocs/Documenter.jl/pull/1908
[github-1909]: https://github.com/JuliaDocs/Documenter.jl/pull/1909
[github-1912]: https://github.com/JuliaDocs/Documenter.jl/pull/1912
[github-1919]: https://github.com/JuliaDocs/Documenter.jl/pull/1919
[github-1924]: https://github.com/JuliaDocs/Documenter.jl/pull/1924
[github-1930]: https://github.com/JuliaDocs/Documenter.jl/issues/1930
[github-1931]: https://github.com/JuliaDocs/Documenter.jl/issues/1931
[github-1932]: https://github.com/JuliaDocs/Documenter.jl/pull/1932
[github-1933]: https://github.com/JuliaDocs/Documenter.jl/issues/1933
[github-1935]: https://github.com/JuliaDocs/Documenter.jl/pull/1935
[github-1936]: https://github.com/JuliaDocs/Documenter.jl/issues/1936
[github-1937]: https://github.com/JuliaDocs/Documenter.jl/pull/1937
[github-1944]: https://github.com/JuliaDocs/Documenter.jl/issues/1944
[github-1946]: https://github.com/JuliaDocs/Documenter.jl/issues/1946
[github-1948]: https://github.com/JuliaDocs/Documenter.jl/pull/1948
[github-1955]: https://github.com/JuliaDocs/Documenter.jl/pull/1955
[github-1956]: https://github.com/JuliaDocs/Documenter.jl/pull/1956
[github-1957]: https://github.com/JuliaDocs/Documenter.jl/pull/1957
[github-1958]: https://github.com/JuliaDocs/Documenter.jl/issues/1958
[github-1962]: https://github.com/JuliaDocs/Documenter.jl/pull/1962
[github-1969]: https://github.com/JuliaDocs/Documenter.jl/pull/1969
[github-1970]: https://github.com/JuliaDocs/Documenter.jl/pull/1970
[github-1977]: https://github.com/JuliaDocs/Documenter.jl/pull/1977
[github-1980]: https://github.com/JuliaDocs/Documenter.jl/pull/1980
[github-1989]: https://github.com/JuliaDocs/Documenter.jl/pull/1989
<!-- end of issue link definitions -->

[julia-29344]: https://github.com/JuliaLang/julia/issues/29344
[julia-38054]: https://github.com/JuliaLang/julia/issues/38054
[julia-38079]: https://github.com/JuliaLang/julia/issues/38079
[julia-39841]: https://github.com/JuliaLang/julia/pull/39841
[julia-43652]: https://github.com/JuliaLang/julia/issues/43652
[julia-45174]: https://github.com/JuliaLang/julia/issues/45174
[julialangorg-1272]: https://github.com/JuliaLang/www.julialang.org/issues/1272

[documenter-issues]: https://github.com/JuliaDocs/Documenter.jl/issues
[documenterlatex]: https://github.com/JuliaDocs/DocumenterLaTeX.jl
[documentermarkdown]: https://github.com/JuliaDocs/DocumenterMarkdown.jl
[json-jl]: https://github.com/JuliaIO/JSON.jl
[juliamono]: https://cormullion.github.io/pages/2020-07-26-JuliaMono/
[liveserver]: https://github.com/tlienart/LiveServer.jl
[markdownast]: https://github.com/JuliaDocs/MarkdownAST.jl

[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-enhancement]: https://img.shields.io/badge/enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg
[badge-security]: https://img.shields.io/badge/security-black.svg
[badge-experimental]: https://img.shields.io/badge/experimental-lightgrey.svg
[badge-maintenance]: https://img.shields.io/badge/maintenance-gray.svg

<!--
# Badges

![BREAKING][badge-breaking]
![Deprecation][badge-deprecation]
![Feature][badge-feature]
![Enhancement][badge-enhancement]
![Bugfix][badge-bugfix]
![Security][badge-security]
![Experimental][badge-experimental]
![Maintenance][badge-maintenance]
-->
