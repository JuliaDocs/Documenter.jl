# `ghcr.io/juliadocs/documenter-latex`

A TeX toolchain for Documenter's PDF backend, used by

```julia
makedocs(format = Documenter.LaTeX(platform = "docker"), ...)
```

Documenter itself runs on the host; only the `.tex` → `.pdf` step happens in the
container. The image therefore contains no Julia and is not tied to a Julia or
Documenter version.

## Contents

| Component | Why |
| --- | --- |
| TeX Live, installed from CTAN | `latexmk`, `lualatex`, and the packages in [`texlive-packages.txt`](texlive-packages.txt) |
| DejaVu Sans / Sans Mono | selected by `assets/latex/documenter.sty` via `fontspec` |
| JuliaMono | not used by default; available to custom preambles |
| Pygments (`pygmentize`) | the `minted` backend for source highlighting |

`texlive-packages.txt` is shared with the `zauguin/install-texlive` step in
`.github/workflows/CI.yml`, so the containerised and natively installed TeX
toolchains cannot drift apart.

## Using it

Documenter runs `docker`, which must be in `PATH`; the image is pulled on first use.
On GitHub Actions no setup step is required, since `ubuntu-*` runners ship with
Docker.

To point Documenter at a different image, for instance one adding a LaTeX package
your custom preamble needs:

```julia
makedocs(format = Documenter.LaTeX(platform = "docker", image = "myorg/my-latex:1"), ...)
```

A custom image must provide `bash`, `latexmk`, `lualatex`, the packages listed in
`texlive-packages.txt`, and a writable `/tmp`. Documenter mounts the build tree at
`/mnt`, copies it to `/tmp/build` inside the container, and copies the PDF back out,
so it never writes into the mounted directory.

The mounted directory is `mktempdir()`, so a Docker installation that only shares
selected host paths has to be configured to share the system temporary directory.
An unshared path is bind-mounted as an empty directory rather than refused, which is
what the `was mounted empty` error reports.

## Maintaining it

`.github/workflows/DockerImage.yml` publishes `linux/amd64` and `linux/arm64` on
every push to `master` that touches `docker/`, and weekly to pick up TeX Live and
Debian security updates. Pull requests do not publish: the `latex` job in `CI.yml`
builds the image from source and runs the PDF test suite against it instead.

Tags:

* `:1` — the moving tag pinned by `DOCKER_IMAGE` in `src/latex/LaTeXWriter.jl`.
  Bump both together, and only for a change older Documenter releases cannot cope
  with.
* `:1-YYYYMMDD` — immutable, so a broken rebuild can be rolled back to.
* `:latest`.

To build and test locally:

```bash
docker build -t documenter-latex:test docker/
DOCUMENTER_LATEX_DOCKER_IMAGE=documenter-latex:test \
  julia --project=test/examples test/examples/tests_latex.jl
```

The predecessor, `juliadocs/documenter-latex:0.1` on Docker Hub, is unmaintained;
its Dockerfile lives in the archived `JuliaDocs/DocumenterLaTeX.jl` repository.
