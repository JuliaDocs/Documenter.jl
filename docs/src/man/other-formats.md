# Other Output Formats

In addition to the default native HTML output, Documenter also provides [a built-in
LaTeX-based PDF output](@ref pdf-output). Additional output formats are provided through
plugin packages. Once the corresponding package is loaded, the output format can be
specified using the `format` option in [`makedocs`](@ref).

## [PDF Output via LaTeX](@id pdf-output)

`makedocs` can be switched over to use the PDF/LaTeX backend by passing a
[`Documenter.LaTeX`](@ref) object as the `format` keyword:

```julia
using Documenter
makedocs(format = Documenter.LaTeX(), ...)
```

Documenter will then generate a PDF file of the documentation using LaTeX, which will be
placed in the output (`build/`) directory.

The `makedocs` argument `sitename` will be used for the `\title` field in the tex document,
and if the build is for a release tag (i.e. when the `"TRAVIS_TAG"` environment variable is set)
the version number will be appended to the title.
The `makedocs` argument `authors` should also be specified, it will be used for the
`\authors` field in the tex document.

### Compiling using natively installed latex

The following is required to build the documentation:

* You need `pdflatex` and `latexmk` commands to be installed and available to Documenter.
* You need the [minted](https://ctan.org/pkg/minted) LaTeX package and its backend source
  highlighter [Pygments](https://pygments.org/) installed.
* You need the [_DejaVu Sans_ and _DejaVu Sans Mono_](https://dejavu-fonts.github.io/) fonts installed.

### Compiling using Tectonic

The documentation can be also built using the
[Tectonic](https://tectonic-typesetting.github.io) LaTeX engine. It is required to have a `tectonic`
available in `PATH`, or to provide a path to the binary using the `tectonic` keyword:

```
using Documenter

# Executable `tectonic` is present in `PATH`
makedocs(
    format = Documenter.LaTeX(platform="tectonic"),
    ...)

# The path to `tectonic` is provided by the tectonic_jll package
using tectonic_jll: tectonic
makedocs(
    format = Documenter.LaTeX(platform="tectonic", tectonic=tectonic()),
    ...)
```

### Compiling using docker image

It is also possible to use a prebuilt [docker image](https://hub.docker.com/r/juliadocs/documenter-latex/)
to compile the `.tex` file. The image contains all of the required installs described in the section
above. The only requirement for using the image is that `docker` is installed and available for
the builder to call. You also need to tell Documenter to use the docker image, instead of natively
installed tex which is the default. This is done with the `LaTeX` specifier:

```
using DocumenterLaTeX
makedocs(
    format = LaTeX(platform = "docker"),
    ...
)
```

If you build the documentation on Travis you need to add

```
services:
  - docker
```

to your `.travis.yml` file.

### Compiling to LaTeX only

There's a possibility to save only the `.tex` file and skip the PDF compilation.
For this purpose use the `platform="none"` keyword:

```
using DocumenterLaTeX
makedocs(
    format = LaTeX(platform = "none"),
    ...
)
```

## [Custom LaTeX style](@id custom-latex)

### Load custom packages

We have loaded many common packages in LaTeX,
such as `fontspec`, `amsmath`, `listings`, `minted`, `tabulary`, `graphicx`,
and more detailed configurations can be found in [`documenter.sty`](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/latex/documenter.sty).

Users can load more custom packages by adding a `custom.sty` to the `assets/` folder,
and the custom style (`custom.sty`) will be loaded after the default style (`documenter.sty`).

### Custom preamble

If you wish to fully customize the package loading, you need to write a custom preamble.

The default preamble is currently defined in [`preamble.tex`](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/latex/preamble.tex).
You can override the default preamble completely by adding a custom `preamble.tex` to the `assets/` folder.

There are two examples of custom preambles:
- Custom [cover page][cover_page_src], ([make.jl][cover_page_makejl])
- Customizing [the TOC display][toc_display_src], ([make.jl][toc_display_makejl])

[cover_page_src]: https://github.com/JuliaDocs/Documenter.jl/tree/master/test/examples/src.cover_page
[toc_display_src]: https://github.com/JuliaDocs/Documenter.jl/tree/master/test/examples/src.toc_style
[cover_page_makejl]: https://github.com/JuliaDocs/Documenter.jl/blob/master/test/examples/make.jl#L492-L502
[toc_display_makejl]: https://github.com/JuliaDocs/Documenter.jl/blob/master/test/examples/make.jl#L511-L521


## Markdown & MkDocs

Documenter no longer provides the Markdown/MkDocs output, and this functionality has moved
to the [`DocumenterMarkdown`](https://github.com/JuliaDocs/DocumenterMarkdown.jl) package.
