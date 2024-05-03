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

!!! warning "Known issue"
    If the `makedocs` argument `pages` is not assigned, Documenter will generate tex documents without contents. ([#2132](@ref))

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
using Documenter
makedocs(
    format = Documenter.LaTeX(platform = "docker"),
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
using Documenter
makedocs(
    format = Documenter.LaTeX(platform = "none"),
    ...
)
```

## [Custom LaTeX style](@id custom-latex)

The PDF/LaTeX backend works by generating a TeX file based on the input Markdown files.
For users who need or want more control over the generated PDF, it is possible to customize
the setup part of the generated TeX code.

### Load custom packages

By default, the generated TeX file loads the [`documenter.sty`](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/latex/documenter.sty)
style file, which loads several packages (such as `fontspec`, `amsmath`, `listings`, `minted`, `tabulary`, `graphicx`)
and otherwise configures the TeX build.

Users can load additional packages and declare additional configuration by adding a
`custom.sty` file to the `assets/` source directory. The custom style file will be loaded
right after the default style (`documenter.sty`).

### Custom preamble

By default, Documenter uses the [`preamble.tex`](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/latex/preamble.tex)
preamble, with only the dynamically generated declarations for the `\DocMainTitle`,
`\DocVersion`, `\DocAuthors`, and `\JuliaVersion` variables preceding it.

For more control, it is possible to fully replace the preamble by adding a `preamble.tex`
file into the `assets/` source directory, which will then be used instead of the default
one. The Documenter tests contain two examples of how a custom preamble can be used:

- [To customize the cover page of the manual.](https://github.com/JuliaDocs/Documenter.jl/tree/master/test/examples/src.cover_page)
- [To customize the TOC style.](https://github.com/JuliaDocs/Documenter.jl/tree/master/test/examples/src.toc_style)

## Markdown & MkDocs

Documenter no longer provides the Markdown/MkDocs output, and this functionality has moved
to the [`DocumenterMarkdown`](https://github.com/JuliaDocs/DocumenterMarkdown.jl) package.
