SHELL := /bin/bash

include scripts/tool-versions.env
export HELM_DOCS_VERSION HELM_UNITTEST_VERSION HELMCOV_IMAGE HELMCOV_VERSION COVERAGE_THRESHOLD

CHART ?= charts/clickstack
HELM_UNITTEST_PLUGIN := https://github.com/helm-unittest/helm-unittest.git
# COVERAGE_THRESHOLD comes from scripts/tool-versions.env; override with `make coverage COVERAGE_THRESHOLD=N`.

.PHONY: help setup ci-setup hooks chart-deps install-helm-unittest install-helm-docs validate test coverage docs docs-check ci

help:
	@echo "Targets:"
	@echo "  make setup     Install helm-unittest, helm-docs, chart deps, and git hooks"
	@echo "  make test      Run helm-unittest and example values validation"
	@echo "  make coverage  Run helmcov template coverage via Docker (min $(COVERAGE_THRESHOLD)%)"
	@echo "  make docs      Regenerate chart README files from values.yaml via helm-docs"
	@echo "  make ci        Run test, coverage, and docs verification"
	@echo ""
	@echo "Variables:"
	@echo "  CHART=$(CHART)"
	@echo "  HELMCOV_IMAGE=$(HELMCOV_IMAGE)"
	@echo "  HELM_UNITTEST_VERSION=$(HELM_UNITTEST_VERSION)"
	@echo "  COVERAGE_THRESHOLD=$(COVERAGE_THRESHOLD)"

setup: hooks ci-setup
	@echo "Setup complete."

ci-setup: install-helm-unittest install-helm-docs chart-deps

hooks:
	./scripts/install-hooks.sh

install-helm-docs:
	./scripts/install-helm-docs.sh

chart-deps:
	@command -v helm >/dev/null || { echo "helm is required; install Helm 3 first." >&2; exit 1; }
	helm repo add mongodb https://mongodb.github.io/helm-charts >/dev/null 2>&1 || true
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
	helm dependency build $(CHART)

install-helm-unittest:
	@command -v helm >/dev/null || { echo "helm is required; install Helm 3 first." >&2; exit 1; }
	@want="$(HELM_UNITTEST_VERSION:v%=%)"; \
	installed=$$(helm plugin list 2>/dev/null | awk '$$1=="unittest"{print $$2}'); \
	if [ "$$installed" = "$$want" ]; then \
		echo "helm-unittest $(HELM_UNITTEST_VERSION) already installed"; \
	else \
		[ -n "$$installed" ] && { echo "Replacing helm-unittest $$installed with $(HELM_UNITTEST_VERSION)..."; helm plugin uninstall unittest >/dev/null 2>&1 || true; } || true; \
		echo "Installing helm-unittest $(HELM_UNITTEST_VERSION)..."; \
		helm plugin install $(HELM_UNITTEST_PLUGIN) --version $(HELM_UNITTEST_VERSION); \
	fi

validate: chart-deps
	helm template clickstack-example $(CHART) -f examples/alb-ingress/values.yaml >/dev/null
	helm template clickstack-example $(CHART) -f examples/api-only/values.yaml >/dev/null

test: chart-deps validate
	helm unittest $(CHART)

coverage: chart-deps
	THRESHOLD=$(COVERAGE_THRESHOLD) HELMCOV_IMAGE=$(HELMCOV_IMAGE) ./scripts/helmcov.sh

docs: install-helm-docs
	./scripts/helmdocs.sh

docs-check: docs
	@git diff --exit-code -- charts/clickstack/README.md charts/clickstack-operators/README.md; \
		rc=$$?; \
		git checkout -- charts/clickstack/README.md charts/clickstack-operators/README.md; \
		exit $$rc

ci: test coverage docs-check
