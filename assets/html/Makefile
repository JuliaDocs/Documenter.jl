MAKEFILE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# All theme-independent source files
SRC_FILES =
SRC_FILES += $(shell find scss/documenter/ -type f -name '*.scss')
SRC_FILES += $(shell find scss/bulma/ -type f -name '*.sass')

# Default target: compile all themes
all: themes/documenter-light.css themes/documenter-dark.css
.PHONY: all

# documenter-light
themes/documenter-light.css: scss/documenter-light.scss scss/highlightjs/default.css \
		$(SRC_FILES)
	julia -e 'using DocumenterTools; DocumenterTools.Themes.compile("${MAKEFILE_DIR}/$<", "${MAKEFILE_DIR}/$@")'

# documenter-dark
themes/documenter-dark.css: scss/documenter-dark.scss scss/darkly/_variables.scss \
		scss/darkly/_overrides.scss scss/highlightjs/a11y-dark.css $(SRC_FILES)
	julia -e 'using DocumenterTools; DocumenterTools.Themes.compile("${MAKEFILE_DIR}/$<", "${MAKEFILE_DIR}/$@")'
