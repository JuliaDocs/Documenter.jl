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

help:
	@echo "The following make commands are available:"
	@echo " - make changelog: update all links in CHANGELOG.md's footer"
	@echo " - make docs: build the documentation"
	@echo " - make test: run the tests"
	@echo " - make themes: compile Documenter's native CSS themes"

.PHONY: default docs-instantiate themes help changelog docs test
