JULIA:=julia
RUNIC:=@runic

default: help

docs/Manifest.toml: docs/Project.toml
	${JULIA} --project=docs -e 'using Pkg; Pkg.instantiate()'

docs-instantiate:
	${JULIA} --project=docs -e 'using Pkg; Pkg.instantiate()'

docs: docs/Manifest.toml
	${JULIA} --project=docs docs/make.jl

# Same as `make docs`, but meant to be used when testing things
# while developing etc., while you want to avoid builds erroring.
docs-warn-only: docs/Manifest.toml
	${JULIA} --project=docs docs/make.jl strict=false

changelog: docs/Manifest.toml
	${JULIA} --project=docs docs/changelog.jl

themes:
	$(MAKE) -C assets/html all

format-julia:
	julia --project=$(RUNIC) -e 'using Runic; exit(Runic.main(ARGS))' -- --inplace .

install-runic:
	julia --project=$(RUNIC) -e 'using Pkg; Pkg.add("Runic")'

test:
	${JULIA} --project -e 'using Pkg; Pkg.test()'

search-benchmarks:
	cd test/search && ${JULIA} --project=../.. run_benchmarks.jl

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
	rm -f test/search/search_benchmark_results_*.txt


help:
	@echo "The following make commands are available:"
	@echo " - make changelog: update all links in CHANGELOG.md's footer"
	@echo " - make docs: build the documentation"
	@echo " - make docs-warn-only: build the documentation, but do not error on failures"
	@echo " - make docs-instantiate: instantiate the docs/ Julia environment"
	@echo " - make format-julia: formats the Julia source code with Runic"
	@echo " - make install-runic: installs Runic.jl into the @runic shared Julia environment (for make format)"
	@echo " - make test: run the tests"
	@echo " - make search-benchmarks: run search functionality benchmarks"
	@echo " - make themes: compile Documenter's native CSS themes"
	@echo " - make clean: remove generated files"

.PHONY: default docs-instantiate themes help changelog docs test format-julia install-runic search-benchmarks
