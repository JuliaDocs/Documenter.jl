JULIA:=julia

default: help

docs-instantiate:
	${JULIA} docs/instantiate.jl

docs: docs-instantiate
	${JULIA} --project=docs docs/make.jl

changelog:
	${JULIA} --project=docs docs/changelog.jl

themes: docs-instantiate
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
