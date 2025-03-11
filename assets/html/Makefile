MAKEFILE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

JULIA:=julia --project

# All theme-independent source files
SRC_FILES =
SRC_FILES += $(shell find scss/documenter/ -type f -name '*.scss')
SRC_FILES += $(shell find scss/bulma/ -type f -name '*.sass')
SRC_FILES += Manifest.toml

THEMES = documenter-light documenter-dark \
		catppuccin-latte catppuccin-frappe catppuccin-macchiato catppuccin-mocha

# Default target: compile all themes
all: $(addprefix themes/, $(addsuffix .css, $(THEMES)))
.PHONY: all

Manifest.toml: Project.toml
	$(JULIA) --project -e 'using Pkg; Pkg.instantiate()'

# documenter-light
themes/documenter-light.css: scss/documenter-light.scss scss/highlightjs/default.css \
		$(SRC_FILES)
	$(JULIA) -e 'using DocumenterTools; DocumenterTools.Themes.compile("${MAKEFILE_DIR}/$<", "${MAKEFILE_DIR}/$@")'

# documenter-dark
themes/documenter-dark.css: scss/documenter-dark.scss scss/darkly/_variables.scss \
		scss/darkly/_overrides.scss scss/highlightjs/a11y-dark.css $(SRC_FILES)
	$(JULIA) -e 'using DocumenterTools; DocumenterTools.Themes.compile("${MAKEFILE_DIR}/$<", "${MAKEFILE_DIR}/$@")'

# catppuccin-*: template the flavor
scss/catppuccin-%.scss: scss/catppuccin.scss
	IS_DARK_THEME=$$(if [ "$*" = "latte" ]; then echo false; else echo true; fi) \
	CATPPUCCIN_FLAVOR=$* envsubst '$${IS_DARK_THEME} $${CATPPUCCIN_FLAVOR}' < $< > $@

# catppuccin-*
themes/catppuccin-%.css: scss/catppuccin-%.scss scss/catppuccin/_%.scss \
		scss/catppuccin/_overrides.scss scss/catppuccin/_variables.scss \
		scss/highlightjs/catppuccin.scss $(SRC_FILES)
	$(JULIA) -e 'using DocumenterTools; DocumenterTools.Themes.compile("${MAKEFILE_DIR}/$<", "${MAKEFILE_DIR}/$@")'
