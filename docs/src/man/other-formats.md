# Other outputs

In addition to the default native HTML output, Documenter can also generate output in other
formats. The output format can be specified using the `format` option in [`makedocs`](@ref).

## Markdown & MkDocs

By specifying `format = :markdown` in [`makedocs`](@ref), Documenter will output a set of
Markdown files to the `build` directory that can then further be processed with
[MkDocs](https://www.mkdocs.org/) into HTML pages.

MkDocs, of course, is not the only option you have -- any markdown to HTML converter should
work fine with some amount of setting up.

!!! note

    Markdown output used to be the default option (i.e. when leaving the `format` option
    unspecified). The default now is the HTML output.

!!! warning

    Markdown output will be moved to a separate package in future versions of Documenter.
    Automatic documentation deployments should not rely on it unless they fix Documenter to a
    minor version.

### The MkDocs `mkdocs.yml` File

A MkDocs build is controlled by the `mkdocs.yml` configuration file. Add the file with the
following content to the `docs/` directory:

```yaml
site_name:        PACKAGE_NAME.jl
repo_url:         https://github.com/USER_NAME/PACKAGE_NAME.jl
site_description: Description...
site_author:      USER_NAME

theme: readthedocs

extra_css:
  - assets/Documenter.css

extra_javascript:
  - https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS_HTML
  - assets/mathjaxhelper.js

markdown_extensions:
  - extra
  - tables
  - fenced_code
  - mdx_math

docs_dir: 'build'

pages:
  - Home: index.md
```

If you have run Documenter and it has generated a `build/` directory, you can now try running
`mkdocs build` -- this should now generate the `site/` directory.
You should also add the `docs/site/` directory into your `.gitignore` file, which should now
look like:

```
docs/build/
docs/site/
```

This is only a basic skeleton. Read through the MkDocs documentation if you would like to
know more about the available settings.


### Deployment with MkDocs

To deploy MkDocs on Travis, you also need to provide additional keyword arguments to
[`deploydocs`](@ref). Your [`deploydocs`](@ref) call should look something like

```julia
deploydocs(
    repo   = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
    deps   = Deps.pip("mkdocs", "pygments", "python-markdown-math"),
    make   = () -> run(`mkdocs build`)
    target = "site"
)
```

* `deps` serves to provide the required Python dependencies to build the documentation
* `make` specifies the function that calls `mkdocs` to perform the second build step
* `target`, which specified which files get copied to `gh-pages`, needs to point to the
  `site/` directory

In the example above we include the dependencies [mkdocs](https://www.mkdocs.org)
and [`python-markdown-math`](https://github.com/mitya57/python-markdown-math).
The former makes sure that MkDocs is installed to deploy the documentation,
and the latter provides the `mdx_math` markdown extension to exploit MathJax
rendering of latex equations in markdown. Other dependencies should be
included here.


### ``\LaTeX``: MkDocs and MathJax

To get MkDocs to display ``\LaTeX`` equations correctly we need to update several of this
configuration files described in the [Package Guide](@ref).

`docs/make.jl` should add the `python-markdown-math` dependency to allow for equations to
be rendered correctly.

```julia
# ...

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    # ...
)
```

This package should also be installed locally so that you can preview the generated
documentation prior to pushing new commits to a repository.

```sh
$ pip install python-markdown-math
```

The `docs/mkdocs.yml` file must add the `python-markdown-math` extension, called `mdx_math`,
as well as two MathJax JavaScript files:

```yaml
# ...
markdown_extensions:
  - mdx_math
  # ...

extra_javascript:
  - https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS_HTML
  - assets/mathjaxhelper.js
# ...
```

**Final Remarks**

Following this guide and adding the necessary changes to the configuration files should
enable properly rendered mathematical equations within your documentation both locally and
when built and deployed using the Travis built service.


## LaTeX

By setting `format = :latex`, you can use LaTeX to generate a PDF version of your
documentation.

* You need `pdflatex` command to be installed and available to Documenter.
* You need the [minted](https://ctan.org/pkg/minted) LaTeX package and its backend source
  highlighter [Pygments](http://pygments.org/) installed.
* You need the [Lato](http://www.latofonts.com/lato-free-fonts/) and
  [Roboto Mono](https://fonts.google.com/specimen/Roboto+Mono) fonts installed.

You should also specify the `sitename` and `authors` keywords for `makedocs` when using the
LaTeX output.

!!! warning

    The LaTeX output will be moved to a separate package in future versions of Documenter.
    Automatic documentation deployments should not rely on it unless they fix Documenter to a
    minor version.
