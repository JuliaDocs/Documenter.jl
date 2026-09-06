# SPDX-License-Identifier: MIT OR CC0-1.0
# build image:
#   docker build -t juliadocs/documenter-latex:1.0  .
FROM ubuntu:18.04

RUN useradd --create-home zeptodoctor
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
    # minimal texlive
        texlive-luatex \
        texlive-latex-base \
        texlive-latex-recommended \
        texlive-latex-extra \
    # latexmk: LaTeX build tool
        latexmk \
    # code highlighting
        python-pygments \
    # refresh the font cache
        fontconfig \
        ; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get purge -y --auto-remove;

WORKDIR /home/zeptodoctor/
