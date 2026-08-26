# ghcr.io/juliadocs/documenter-latex
#
# A TeX toolchain for Documenter.jl's PDF backend. It deliberately contains no
# Julia: Documenter runs on the host and only shells out to a container for the
# .tex -> .pdf step. See docker/README.md.
FROM debian:trixie-slim

# `image.source` is what links the published package to this repository on GHCR,
# so the package inherits its permissions and links back to the Dockerfile.
LABEL org.opencontainers.image.source="https://github.com/JuliaDocs/Documenter.jl"
LABEL org.opencontainers.image.description="TeX toolchain for Documenter.jl's PDF backend"
LABEL org.opencontainers.image.licenses="MIT"

# Installed from CTAN rather than from Debian, whose texlive-* packages trail
# upstream by a year or more.
ARG TEXLIVE_MIRROR=https://mirror.ctan.org/systems/texlive/tlnet
ARG JULIAMONO_VERSION=0.63.2

ENV DEBIAN_FRONTEND=noninteractive

# fonts-dejavu-core: documenter.sty selects DejaVu Sans / Sans Mono via fontspec.
# python3-pygments: provides the `pygmentize` that minted shells out to.
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        fontconfig \
        fonts-dejavu-core \
        perl \
        python3-pygments \
        wget \
        xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY texlive-packages.txt /tmp/texlive-packages.txt

# scheme-infraonly installs only tlmgr itself; the actual package set then comes
# from texlive-packages.txt, so it stays in sync with the native CI install. That
# file must stay a bare list: zauguin/install-texlive passes it to tlmgr verbatim,
# so a comment in it becomes a package name (see docker/README.md).
# `tlmgr path add` symlinks the binaries into /usr/local/bin, which keeps the image
# architecture-independent (no .../bin/x86_64-linux on PATH). It has to run after
# the packages, since it only links what is installed at the time.
RUN set -eux; \
    mkdir /tmp/install-tl; \
    wget -qO- "$TEXLIVE_MIRROR/install-tl-unx.tar.gz" | \
        tar xz --strip-components=1 -C /tmp/install-tl; \
    printf '%s\n' \
        'selected_scheme scheme-infraonly' \
        'TEXDIR /usr/local/texlive' \
        'TEXMFLOCAL /usr/local/texlive/texmf-local' \
        'TEXMFSYSCONFIG /usr/local/texlive/texmf-config' \
        'TEXMFSYSVAR /usr/local/texlive/texmf-var' \
        'instopt_adjustpath 1' \
        'tlpdbopt_install_docfiles 0' \
        'tlpdbopt_install_srcfiles 0' \
        'tlpdbopt_sys_bin /usr/local/bin' \
        > /tmp/texlive.profile; \
    /tmp/install-tl/install-tl \
        --profile=/tmp/texlive.profile \
        --repository="$TEXLIVE_MIRROR"; \
    tlmgr install $(cat /tmp/texlive-packages.txt); \
    tlmgr path add; \
    rm -rf /tmp/install-tl /tmp/texlive.profile /tmp/texlive-packages.txt

# Not used by the default template, but available to anyone overriding the
# monospace font in a custom preamble.
RUN set -eux; \
    mkdir -p /usr/local/share/fonts/juliamono; \
    wget -qO- "https://github.com/cormullion/juliamono/releases/download/v${JULIAMONO_VERSION}/JuliaMono-ttf.tar.gz" | \
        tar xz -C /usr/local/share/fonts/juliamono; \
    fc-cache -f

# Documenter copies the build tree to /tmp/build inside the container and copies
# the PDF back out, so nothing here ever writes into the host's mounted tree.
# Running as a non-root user keeps that true even for a custom entrypoint.
RUN useradd --create-home documenter
USER documenter
WORKDIR /home/documenter
