# Other Output Formats

In addition to the default native HTML output, Documenter also provides [a built-in
LaTeX-based PDF output](@ref pdf-output) and [a Typst-based PDF output](@ref typst-output). 
Additional output formats are provided through plugin packages. Once the corresponding package 
is loaded, the output format can be specified using the `format` option in [`makedocs`](@ref).

## [PDF Output via Typst](@id typst-output)

`makedocs` can be switched over to use the Typst backend by passing a
[`Documenter.Typst`](@ref) object as the `format` keyword:

```julia
using Documenter
makedocs(format = Documenter.Typst(), ...)
```

Documenter will then generate a PDF file of the documentation using Typst, which will be
placed in the output (`build/`) directory.

The `makedocs` argument `sitename` will be used for the document title, and if a version
is specified via the `version` keyword, it will be appended to the title. The `makedocs` 
argument `authors` should also be specified for proper document metadata.

### Compiling using Typst_jll

The default (and recommended) option is to use the `Typst_jll` package, which provides
precompiled Typst binaries for all major platforms:

```julia
using Documenter
makedocs(
    format = Documenter.Typst(platform="typst"),
    ...
)
```

This is the default platform setting and requires `Typst_jll` to be added to your environment.

### Compiling using natively installed typst

You can also use a system-installed Typst compiler:

```julia
using Documenter
makedocs(
    format = Documenter.Typst(platform="native"),
    ...
)
```

This requires the `typst` executable to be available in your `PATH`. Optionally, you can
specify a custom path to the executable:

```julia
using Documenter
makedocs(
    format = Documenter.Typst(platform="native", typst="/path/to/typst"),
    ...
)
```

### Compiling using docker image

For CI/CD environments, you can use a Docker-based compilation:

```julia
using Documenter
makedocs(
    format = Documenter.Typst(platform="docker"),
    ...
)
```

This requires `docker` to be installed and available in your `PATH`.

### Compiling to Typst source only

To generate only the `.typ` file without PDF compilation:

```julia
using Documenter
makedocs(
    format = Documenter.Typst(platform="none"),
    ...
)
```

This is useful for debugging or when you want to manually compile the Typst source.

### Math rendering in Typst output

By default, mathematical formulas written using standard ``` ```math ``` blocks or inline ```` ``...`` ```` syntax are treated as LaTeX and converted to Typst using the [MiTeX](https://github.com/mitex-rs/mitex) package. This ensures compatibility across all output formats (HTML, PDF/LaTeX, PDF/Typst).

**Example - Standard LaTeX math:**

````markdown
```math
\sum_{i=1}^n i = \frac{n(n+1)}{2}
```

Inline: ``\alpha + \beta = \gamma``
````

This generates Typst code using `#mitex()` for LaTeX compatibility.

### Native Typst math syntax

For documentation that only targets Typst/PDF output, you can use Typst's native mathematical syntax by using ``` ```math typst``` ``` code blocks. Native Typst math syntax is often more concise and natural than LaTeX.

**Example - Native Typst math:**

````markdown
```math typst
sum_(i=1)^n i = (n(n+1))/2
```
````

This generates native Typst math blocks (`$ ... $`), avoiding the LaTeX-to-Typst conversion layer.

!!! note "LaTeX vs Typst math syntax"
    Key differences between LaTeX and Typst math syntax:
    
    | Feature | LaTeX | Typst |
    |---------|-------|-------|
    | Fractions | `\frac{a}{b}` | `a/b` or `frac(a, b)` |
    | Summation | `\sum_{i=1}^n` | `sum_(i=1)^n` |
    | Integration | `\int_0^\infty` | `integral_0^oo` |
    | Greek letters | `\alpha` | `alpha` (no backslash) |
    | Subscripts | `x_{i}` | `x_i` (braces optional) |
    | Infinity | `\infty` | `oo` |
    
    See the [Typst math documentation](https://typst.app/docs/reference/math/) for complete syntax reference.

!!! tip "When to use native Typst math"
    - **Use LaTeX syntax** (``` ```math ```) when generating multiple output formats (HTML + PDF)
    - **Use Typst syntax** (``` ```math typst```) when:
        - Only generating Typst/PDF output
        - You prefer Typst's more intuitive syntax
        - You need Typst-specific math features

## [Custom Typst style](@id custom-typst)

The PDF/Typst backend works by generating a `.typ` file based on the input Markdown files.
For users who need or want more control over the generated PDF, it is possible to customize
the styling and configuration of the generated Typst document.

### Customizing with `custom.typ`

By default, the generated Typst file imports the [`documenter.typ`](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/typst/documenter.typ)
template, which provides the default styling and configuration for the PDF output.

Users can override default settings and add custom configuration by adding a
`custom.typ` file to the `assets/` source directory. The custom file will be imported
right after the default template, allowing you to override settings using deep merge.

#### Quick start

Create `docs/src/assets/custom.typ` and define only the settings you want to override:

```typst
// Only define what you want to change
#let config = (
  text-size: 13pt,
  dark-blue: rgb("1e40af"),
  admonition-colors: (
    info: rgb("0066cc"),
  )
)
```

That's it! The system automatically deep-merges your configuration with the defaults, 
preserving all unspecified settings.

#### How deep merge works

The configuration system uses intelligent deep merging:

**Your config:**
```typst
#let config = (
  text-size: 15pt,
  admonition-colors: (
    info: rgb("00ff00"),
  )
)
```

**Final effective config:**
- `text-size`: `15pt` (your value)
- `code-size`: `9pt` (default preserved)
- `dark-blue`: `rgb("4266d5")` (default preserved)
- `admonition-colors.info`: `rgb("00ff00")` (your value)
- `admonition-colors.danger`: `rgb("da0b00")` (default preserved)
- `admonition-colors.warning`: `rgb("ffdd57")` (default preserved)
- ... all other settings preserved

#### Available configuration options

##### Font settings

```typst
text-size: 11pt,                    // Body text size
code-size: 9pt,                     // Code block text size
text-font: ("Inter", "DejaVu Sans"),
code-font: ("JetBrains Mono", "DejaVu Sans Mono"),

// Heading sizes
heading-size-title: 24pt,           // Document title
heading-size-part: 18pt,            // Part headings
heading-size-chapter: 18pt,         // Chapter headings
heading-size-section: 14pt,         // Section headings
heading-size-subsection: 13pt,      // Subsection headings
heading-size-subsubsection: 12pt,   // Subsubsection headings
```

##### Color scheme

```typst
// Link and accent colors
light-blue: rgb("6b85dd"),
dark-blue: rgb("4266d5"),
light-red: rgb("d66661"),
dark-red: rgb("c93d39"),
light-green: rgb("6bab5b"),
dark-green: rgb("3b972e"),
light-purple: rgb("aa7dc0"),
dark-purple: rgb("945bb0"),

// Code block styling
codeblock-background: rgb("f6f6f6"),
codeblock-border: rgb("e6e6e6"),

// Admonition colors (nested dictionary)
admonition-colors: (
  default: rgb("363636"),
  danger: rgb("da0b00"),
  warning: rgb("ffdd57"),
  note: rgb("209cee"),
  info: rgb("209cee"),
  tip: rgb("22c35b"),
  compat: rgb("1db5c9"),
),
```

##### Layout settings

```typst
// Table of contents
outline-number-spacing: 0.5em,
outline-indent-step: 1em,
outline-part-spacing: 0.5em,
outline-filler-spacing: 10pt,
outline-line-spacing: -0.2em,

// Tables
table-stroke-width: 0.5pt,
table-stroke-color: rgb("cccccc"),
table-inset: 8pt,

// Quote blocks
quote-background: rgb("f8f8f8"),
quote-border-color: rgb("cccccc"),
quote-border-width: 4pt,
quote-inset: (left: 15pt, right: 15pt, top: 10pt, bottom: 10pt),
quote-radius: (right: 3pt),

// Headers and footers
header-line-stroke: 0.5pt,
```

##### Admonition styling

```typst
admonition-title-size: 12pt,
admonition-title-color: white,
admonition-title-inset: (left: 1em, right: 5pt, top: 5pt, bottom: 5pt),
admonition-title-radius: (top: 5pt),
admonition-content-inset: 10pt,
admonition-content-radius: (bottom: 5pt),

// Customize admonition titles (nested dictionary)
admonition-titles: (
  default: "Note",
  danger: "Danger",
  warning: "Warning",
  note: "Note",
  info: "Info",
  tip: "Tip",
  compat: "Compatibility",
),
```

#### Configuration examples

##### Academic paper style

```typst
#let config = (
  text-size: 12pt,
  text-font: ("Times New Roman", "DejaVu Serif"),
  code-font: ("Courier New", "DejaVu Sans Mono"),
  heading-size-chapter: 16pt,
  heading-size-section: 14pt,
)
```

##### Large fonts for accessibility

```typst
#let config = (
  text-size: 14pt,
  code-size: 12pt,
  heading-size-chapter: 22pt,
  heading-size-section: 18pt,
)
```

##### Custom brand colors (using deep merge)

```typst
#let config = (
  dark-blue: rgb("1e40af"),      // Brand primary
  dark-purple: rgb("7c3aed"),    // Brand secondary
  
  // Override only specific admonition colors
  admonition-colors: (
    info: rgb("1e40af"),         // Use brand color
    tip: rgb("059669"),          // Custom green
    // danger, warning, note, etc. keep defaults
  ),
)
```

!!! note "Deep merge vs shallow merge"
    Unlike traditional dictionary spreading (`..default-config`), deep merge intelligently
    handles nested dictionaries. When you override `admonition-colors.info`, other admonition
    colors are preserved. With shallow merge, the entire `admonition-colors` dictionary would
    be replaced, losing all other colors.

!!! warning "Limitations"
    The `custom.typ` file is used for configuration only. You can override settings via the
    `config` dictionary, but you **cannot** add custom show rules or functions, as they will
    be overridden by the `documenter()` function. For complete customization, you would need
    to modify the `documenter.typ` template itself.

## [PDF Output via LaTeX](@id pdf-output)

`makedocs` can be switched over to use the PDF/LaTeX backend by passing a
[`Documenter.LaTeX`](@ref) object as the `format` keyword:

```julia
using Documenter
makedocs(format = Documenter.LaTeX(), ...)
```

Documenter will then generate a PDF file of the documentation using LaTeX, which will be
placed in the output (`build/`) directory.

The `makedocs` argument `sitename` will be used for the `\title` field in the tex document.
The `makedocs` argument `authors` should also be specified, it will be used for the
`\authors` field in the tex document.

To specify a version number for the document, use the `version` keyword argument of the
`LaTeX` constructor (see the [`Documenter.LaTeX`](@ref) documentation for details).

!!! note "Deprecated: TRAVIS_TAG environment variable"
    The `version` parameter defaults to the `TRAVIS_TAG` environment variable for backwards
    compatibility, but this behavior is deprecated. It is recommended to explicitly specify
    the version using the `version` keyword argument instead.

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

```julia
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

```julia
using Documenter
makedocs(
    format = Documenter.LaTeX(platform = "docker"),
    ...
)
```

If you build the documentation on Travis CI, you need to add

```yaml
services:
  - docker
```

to your `.travis.yml` file. For GitHub Actions, ensure your workflow has appropriate
Docker permissions configured.

### Compiling to LaTeX only

There's a possibility to save only the `.tex` file and skip the PDF compilation.
For this purpose use the `platform="none"` keyword:

```julia
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
