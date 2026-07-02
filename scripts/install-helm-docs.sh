#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/load-tool-versions.sh"
load_tool_versions "${ROOT_DIR}"
TOOLS_DIR="${ROOT_DIR}/.tools"
HELM_DOCS_BIN="${TOOLS_DIR}/helm-docs"
expected_version="${HELM_DOCS_VERSION#v}"

if [[ -x "${HELM_DOCS_BIN}" ]]; then
  installed_version="$("${HELM_DOCS_BIN}" --version 2>/dev/null | awk '{print $NF}')"
  if [[ "${installed_version}" == "${expected_version}" ]]; then
    echo "helm-docs ${HELM_DOCS_VERSION} already installed at ${HELM_DOCS_BIN}"
    exit 0
  fi
  echo "helm-docs version mismatch (installed: ${installed_version}, wanted: ${expected_version}); reinstalling..."
fi

os="$(uname)"
arch="$(uname -m)"
case "${arch}" in
  x86_64) arch="x86_64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "unsupported architecture for helm-docs: ${arch}" >&2
    exit 1
    ;;
esac

version="${HELM_DOCS_VERSION#v}"
archive="helm-docs_${version}_${os}_${arch}.tar.gz"
url="https://github.com/norwoodj/helm-docs/releases/download/${HELM_DOCS_VERSION}/${archive}"

mkdir -p "${TOOLS_DIR}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

echo "Downloading helm-docs ${HELM_DOCS_VERSION}..."
curl -fsSL "${url}" -o "${tmp_dir}/${archive}"
tar -xzf "${tmp_dir}/${archive}" -C "${tmp_dir}" helm-docs
install -m 0755 "${tmp_dir}/helm-docs" "${HELM_DOCS_BIN}"
echo "Installed helm-docs at ${HELM_DOCS_BIN}"
