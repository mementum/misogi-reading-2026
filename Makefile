###############################################################################
# Specifics for this Makefile
###############################################################################
# Force shell for pipefile with grep
SHELL := /bin/bash

# Base definitions
MKDOCS_DIR := .

YML_EXT := .yml
MKDOCS_YML := $(MKDOCS_DIR)/mkdocs$(YML_EXT)
MKDOCS_YML_TEMPLATE := $(MKDOCS_YML).template
MKDOCS_DOCS_DIR := $(MKDOCS_DIR)/docs
MKDOCS_SITE_DIR := $(MKDOCS_DIR)/site
MKDOCS_CSS_DIR := $(MKDOCS_DOCS_DIR)/stylesheets
MKDOCS_JS_DIR := $(MKDOCS_DOCS_DIR)/js
HTPASSWD := $(MKDOCS_SITE_DIR)/.htpasswd

SRC_EXTENSIONS := .(pdf|md|ppt.|xls.)$$
MKDOCS_SRC_FILES := $(shell find $(MKDOCS_DOCS_DIR) | grep -E '$(SRC_EXTENSIONS)')

###############################################################################
# TOOLING DEFINITION
###############################################################################
# Check if python env/package manager is present. if not mkdocs will be tested
# without it
PDM := uv
ifneq ($(PDM),)
  PDM := $(notdir $(shell which $(PDM) 2>/dev/null))
endif

PDM_RUN := cd $(MKDOCS_DIR) &&
ifneq ($(PDM),)
  PDM_RUN := $(PDM_RUN) $(PDM) run
endif

# to build mkdocs
MKDOCS := mkdocs
MKDOCS_SERVE := $(MKDOCS) serve
MKDOCS_BSERVE := $(MKDOCS_SERVE) &
MKDOCS_BUILD := $(MKDOCS) build
# add --clean to really clean it

###############################################################################
# FUNCTIONS
###############################################################################
define echo_stage =
	@echo "========================================"
	@echo "===== CREATING $(1) ====="
	@echo "========================================"
endef

define echo_header =
	@echo "========================================"
	@echo "===== $(1) ====="
	@echo "========================================"
endef

define makedir_dir =
	[ -d $(1) ] || mkdir -p $(1)
endef

define makedir_for_file =
	[ -d $(dir $(1)) ] || mkdir -p $(dir $(1))
endef

define makedir_for_file_and_move =
	$(call makedir_for_file,$@)
	mv $(notdir $@) $@
endef

define makedir_for_file_and_copy =
	$(call makedir_for_file,$@)
	cp $(notdir $@) $@
endef

define find_tool =
	$(eval tmptool := $(shell $(2) which $(1) 2>/dev/null))
	@[ -n "$(tmptool)" ] || echo "$(1): not found"
	@[ -z "$(tmptool)" ] || echo "$(1): found: $(tmptool)"
endef

define find_tool_or_exit =
	$(eval tmptool := $(shell $(2) which $(1) 2>/dev/null))
	@[ -n "$(tmptool)" ] || (echo "$(1): not found"; exit 1)
endef

###############################################################################
# TARGETS AND RULES
###############################################################################
# target which generates the mkdocs content
# depands on the site definition (mkdocs.ym) and anything in the mkdocs/docs dir
mkdocs: $(MKDOCS_YML)

# Regenerate the mkdocs.yml file if the template has changed
$(MKDOCS_YML): $(MKDOCS_YML_TEMPLATE)
	$(call echo_stage,mkdocs-yml)
	$(eval tmpfile := $(shell mktemp --suffix=$(YML_EXT)))
	cp $(MKDOCS_YML_TEMPLATE) $(tmpfile)
	@# put here any operations that can dynamically change the template
	@# Put our custom mkdocs.yml in the right place
	mv -f $(tmpfile) $(MKDOCS_YML)

# Serve a site
mk-serve: mkdocs-serve

# main serve recipe, it
mkdocs-serve: mkdocs
	$(call echo_header,mkdocs-serve)
	$(call find_tool_or_exit,$(MKDOCS),$(PDM_RUN))
	$(PDM_RUN) $(MKDOCS) serve --livereload

# serve, but first killing it if running and serving in the background
mkdocs-bserve: mkdocs mkdocs-kill
	$(call echo_header,mkdocs-bserve-build-and-serve)
	$(call find_tool_or_exit,$(MKDOCS),$(PDM_RUN))
	$(PDM_RUN) $(MKDOCS_BSERVE)

# Build an mkdocs site
mk-build: mkdocs-build

mkdocs-build: mkdocs
	$(call echo_header,mkdocs-build)
	$(call find_tool_or_exit,$(MKDOCS),$(PDM_RUN))
	$(PDM_RUN) $(MKDOCS_BUILD)

# Deploy site
mk-deploy: mkdocs-deploy

mkdocs-deploy: mkdocs
	$(call echo_header,mkdocs-deploy)
	$(call find_tool_or_exit,$(MKDOCS),$(PDM_RUN))
	$(PDM_RUN) $(MKDOCS) gh-deploy --no-history

# kill a running mkdocs instance (probably serving the site)
mk-kill: mkdocs-kill

mkdocs-kill:
	$(call echo_header,mkdocs-kill)
	$(call find_tool_or_exit,$(PKILL))
	-$(PDM_RUN) $(PKILL) $(MKDOCS)

###############################################################################
# TOUCH to force a rebuild
###############################################################################
ifeq (touch,$(filter touch,$(MAKECMDGOALS)))
$(shell touch $(MKDOCS_YML_TEMPLATE))
touch: ;
endif

###############################################################################
# CLEANING
###############################################################################
# delete files
clean:
	$(call echo_header,clean)
	rm -rf $(MKDOCS_SITE_DIR)

###############################################################################
# UTILITIES
###############################################################################
# count the lines of the chapters
count:
	find $(MKDOCS_DOCS_DIR) *.md | xargs @wc --lines

# list source files
sources:
	find $(MKDOCS_DOCS_DIR) *.md

# check if tools can be found
toolcheck:
	$(call echo_header,Checking Tooling)
	@echo The following commands/tools are considered to be always available
	@echo "  - awk, cp, cut, echo, exit, grep, head, mkdir, mktemp,"
	@echo "  - mv, read, sed, sort, tail, test ([]), tr, wc, which"
	@echo ----------------------------------------------------------------------
	@echo Checking for "$(PDM) for python env/package management for mkdocs"
	$(call find_tool,$(PDM))
	@echo Checking for "$(MKDOCS) for site generation (without pdm)"
	$(call find_tool,$(MKDOCS))
	@echo Checking for "$(MKDOCS) for site generation (WITH pdm if available)"
	$(call find_tool,$(MKDOCS),$(PDM_RUN))
	@echo Checking for "$(PKILL) for killing processes (procps package)"
	$(call find_tool,$(PKILL))

###############################################################################
# HELP
###############################################################################
help:
	@echo
	@echo "Publishing Targets"
	@echo "  mkdocs (Publish for the mkdocs subdirectory configuration)"
	@echo "  mkdocs-serve (Publish and start serving locally)"
	@echo "  mkdocs-bserve (Publish and start serving locally in the background)"
	@echo "  mkdocs-kill (kill a mkdocs running instance)"
	@echo "  mkdocs-build (Build the mkdocs site docs)"
	@echo "  mkdocs-deploy (Deploy to Target)"
	@echo "     (also mk-xxx as shorthand for all actions)"
	@echo
	@echo "Auxiliary Targets"
	@echo "  touch (ensure rebuild even if intermediates are unchanged)"
	@echo
	@echo "Cleaning Targets"
	@echo "  clean - remove everything in all languages"
	@echo
	@echo "Tools"
	@echo "  toolcheck - check if needed tooling is found "
	@echo
	@echo "Count Statistics"
	@echo "  count - count lines of source files "
	@echo
	@echo "List Sources for targets"
	@echo "  sources - list the md files"
	@echo
