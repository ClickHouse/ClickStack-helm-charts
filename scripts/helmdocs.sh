#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_DOCS_BIN="${ROOT_DIR}/.tools/helm-docs"

if [[ ! -x "${HELM_DOCS_BIN}" ]]; then
  "${ROOT_DIR}/scripts/install-helm-docs.sh"
fi

echo "Generating chart README files..."
"${HELM_DOCS_BIN}" \
  --chart-search-root "${ROOT_DIR}/charts" \
  --template-files README.md.gotmpl \
  --badge-style flat \
  --ignore-non-descriptions
