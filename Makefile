JULIA:=julia

default: help

docs/Manifest.toml: docs/Project.toml
	${JULIA} --project=docs -e 'using Pkg; Pkg.instantiate()'

docs-instantiate:
	${JULIA} --project=docs -e 'using Pkg; Pkg.instantiate()'

docs: docs/Manifest.toml
	${JULIA} --project=docs docs/make.jl

changelog: docs/Manifest.toml
	${JULIA} --project=docs docs/changelog.jl

themes:
	$(MAKE) -C assets/html all

test:
	${JULIA} --project -e 'using Pkg; Pkg.test()'

clean:
	rm -f Manifest.toml
	rm -f docs/Manifest.toml
	rm -f docs/src/release-notes.md
	rm -rf docs/dev
	rm -rf docs/build
	rm -rf test/docstring_links
	rm -rf test/docstring_links/build
	rm -rf test/docsxref/build
	rm -rf test/doctests/builds
	rm -rf test/errors/build
	rm -rf test/examples/builds
	rm -rf test/missingdocs/build
	rm -rf test/nongit/build
	rm -rf test/plugins/build
	rm -rf test/quietly-logs
	rm -rf test/workdir/builds


help:
	@echo "The following make commands are available:"
	@echo " - make changelog: update all links in CHANGELOG.md's footer"
	@echo " - make docs: build the documentation"
	@echo " - make test: run the tests"
	@echo " - make themes: compile Documenter's native CSS themes"
	@echo " - make clean: remove generated files"

.PHONY: default docs-instantiate themes help changelog docs test
