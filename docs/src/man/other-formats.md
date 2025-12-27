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
right after the default template, allowing you to override constants and add custom styling.

#### Overriding font settings

You can customize fonts by redefining the font constants:

```typst
// custom.typ - Override default fonts
#let text-font = ("Noto Sans", "Arial")
#let code-font = ("Fira Code", "JetBrains Mono", "Courier New")
```

#### Overriding font sizes

Font sizes can be customized by redefining size constants:

```typst
// custom.typ - Use larger fonts
#let text-size = 12pt
#let code-size = 10pt
#let heading-size-section = 16pt
```

Available size constants include:
- `text-size` - Body text (default: 11pt)
- `code-size` - Code blocks (default: 9pt)
- `heading-size-title` - Document title (default: 24pt)
- `heading-size-part` - Part headings (default: 18pt)
- `heading-size-chapter` - Chapter headings (default: 18pt)
- `heading-size-section` - Section headings (default: 14pt)
- `heading-size-subsection` - Subsection headings (default: 13pt)
- `heading-size-subsubsection` - Subsubsection headings (default: 12pt)
- `header-size` - Page header text (default: 10pt)
- `admonition-title-size` - Admonition titles (default: 12pt)
- `metadata-size` - Title page metadata (default: 12pt)

#### Overriding colors

Colors can be customized by redefining color constants:

```typst
// custom.typ - Custom color scheme
#let dark-blue = rgb("0066cc")
#let dark-purple = rgb("663399")
#let codeblock-background = rgb("f0f0f0")
```

Available color constants include:
- `light-blue`, `dark-blue` - Link colors and accents
- `light-red`, `dark-red` - Error and warning colors
- `light-green`, `dark-green` - Success colors
- `light-purple`, `dark-purple` - External link colors
- `codeblock-background` - Code block background (default: `rgb("f6f6f6")`)
- `codeblock-border` - Code block border (default: `rgb("e6e6e6")`)
- Admonition colors: `admonition-colors.default`, `admonition-colors.danger`, 
  `admonition-colors.warning`, `admonition-colors.note`, `admonition-colors.info`, 
  `admonition-colors.tip`, `admonition-colors.compat`

#### Adding custom show rules

You can add custom styling rules that will apply throughout the document:

```typst
// custom.typ - Custom styling
#show strong: set text(fill: rgb("cc0000"))
#show link: underline
#show raw.where(block: false): box.with(
  fill: rgb("f0f0f0"),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 2pt,
)
```

#### Adding custom functions

You can define custom functions for use in your documentation:

```typst
// custom.typ - Custom admonition
#let my-custom-box(title: "Note", body) = {
  rect(
    width: 100%,
    fill: rgb("e3f2fd"),
    stroke: 2pt + rgb("2196f3"),
    radius: 5pt,
    inset: 10pt
  )[
    *#title:* #body
  ]
}
```

!!! note
    The `custom.typ` file is imported after `documenter.typ`, so any constants you redefine
    will override the defaults. However, you cannot modify the core `documenter()` function
    itself, as it is invoked automatically by the generated template.

!!! tip "Example: Complete custom styling"
    Here's a complete example of a `custom.typ` file that customizes the look of your documentation:
    
    ```typst
    // docs/src/assets/custom.typ
    
    // Use a custom font family
    #let text-font = ("Libertinus Serif", "Georgia", "Times New Roman")
    #let code-font = ("Fira Code", "Consolas")
    
    // Slightly larger text for better readability
    #let text-size = 12pt
    #let code-size = 10pt
    
    // Custom color scheme (blue theme)
    #let dark-blue = rgb("0066cc")
    #let dark-purple = rgb("6633cc")
    
    // Style inline code with a subtle background
    #show raw.where(block: false): box.with(
      fill: rgb("f5f5f5"),
      inset: (x: 3pt, y: 0pt),
      outset: (y: 3pt),
      radius: 2pt,
    )
    ```

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
