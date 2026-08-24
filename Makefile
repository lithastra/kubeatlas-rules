# kubeatlas-rules — community rule packs for the KubeAtlas Rego
# engine. The Makefile is the single entry point for `opa check`,
# `opa test`, and the `kubeatlas rules-test` integration step CI
# wires up.
#
# Usage:
#   make check                    # syntax + reference check ALL packs
#   make test                     # opa unit tests ALL packs
#   make integration              # rules-test CLI ALL packs
#   make check PACK=openshift     # single pack
#   make test PACK=openshift
#   make all                      # check + test + integration
#
# Required tools: opa (https://www.openpolicyagent.org/) and either
# kubeatlas built locally (`go build ./cmd/kubeatlas`) or available
# on PATH for `make integration`. CI installs both via dedicated
# steps.

OPA ?= opa
KUBEATLAS ?= kubeatlas

# When PACK= is set the targets operate on a single directory; with
# no PACK we walk every top-level dir that has a metadata.yaml.
ifeq ($(PACK),)
# GNU make's wildcard functions behave consistently on Linux and macOS.
# Avoid GNU find-only flags such as -printf: BSD find rejects them and used to
# leave PACK_DIRS empty while the targets still reported success.
PACK_DIRS := $(patsubst %/metadata.yaml,%,$(wildcard */metadata.yaml))
else
PACK_DIRS := $(PACK)
endif

.PHONY: help check test integration all clean

help: ## Show this help.
	@awk -F':.*##' '/^[a-zA-Z_-]+:.*##/ {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --ignore '*.yaml' keeps OPA from loading metadata.yaml and the
# samples/*.yaml CRD fixtures as Rego data — both live in pack
# directories on purpose but neither is a Rego data source. Without
# the ignore, `opa test` walks them and emits "conflicting rule" /
# unhelpful data clashes.
OPA_IGNORE_FLAGS := --ignore '*.yaml' --ignore '*.yml'

check: ## opa check: syntax + reference validation.
	@if [ -z "$(PACK_DIRS)" ]; then \
	  echo "no packs found" >&2; exit 1; \
	fi; \
	for d in $(PACK_DIRS); do \
	  echo "==> opa check $$d"; \
	  $(OPA) check $(OPA_IGNORE_FLAGS) $$d || exit $$?; \
	done

test: ## opa test: per-pack unit tests under tests/.
	@if [ -z "$(PACK_DIRS)" ]; then \
	  echo "no packs found" >&2; exit 1; \
	fi; \
	for d in $(PACK_DIRS); do \
	  echo "==> opa test $$d"; \
	  $(OPA) test $(OPA_IGNORE_FLAGS) $$d || exit $$?; \
	done

integration: ## kubeatlas rules-test: load + evaluate against samples/.
	@if [ -z "$(PACK_DIRS)" ]; then \
	  echo "no packs found" >&2; exit 1; \
	fi; \
	for d in $(PACK_DIRS); do \
	  if [ ! -d $$d/samples ]; then \
	    echo "==> $$d: no samples/, skipping integration"; \
	    continue; \
	  fi; \
	  echo "==> kubeatlas rules-test $$d"; \
	  $(KUBEATLAS) rules-test --pack=$$d --samples=$$d/samples || exit $$?; \
	done

all: check test integration ## Run check + test + integration.

clean: ## Remove build / test caches.
	@find . -name '.opa' -type d -prune -exec rm -rf {} + 2>/dev/null || true
