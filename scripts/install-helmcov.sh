#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/load-tool-versions.sh"
load_tool_versions "${ROOT_DIR}"
TOOLS_DIR="${ROOT_DIR}/.tools"
# helmcov has no --version flag, so the version lives in the file name.
HELMCOV_BIN="${TOOLS_DIR}/helmcov-${HELMCOV_VERSION}"

if [[ -x "${HELMCOV_BIN}" ]]; then
  echo "helmcov ${HELMCOV_VERSION} already installed at ${HELMCOV_BIN}"
  exit 0
fi

os="$(uname | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "${arch}" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "unsupported architecture for helmcov: ${arch}" >&2
    exit 1
    ;;
esac

archive="helmcov_${HELMCOV_VERSION#v}_${os}_${arch}.tar.gz"
base_url="https://github.com/ClickHouse/helmcov/releases/download/${HELMCOV_VERSION}"

mkdir -p "${TOOLS_DIR}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}" "${HELMCOV_BIN}.tmp"' EXIT

if command -v sha256sum >/dev/null; then sha256=(sha256sum); else sha256=(shasum -a 256); fi

echo "Downloading helmcov ${HELMCOV_VERSION}..."
curl -fsSL "${base_url}/checksums.txt" -o "${tmp_dir}/checksums.txt"
curl -fsSL "${base_url}/${archive}" -o "${tmp_dir}/${archive}"

# Pinning checksums.txt pins every platform archive, since release assets can be replaced.
echo "${HELMCOV_CHECKSUMS_SHA256}  checksums.txt" > "${tmp_dir}/checksums.txt.sha256"
(
  cd "${tmp_dir}"
  "${sha256[@]}" -c checksums.txt.sha256
  grep " ${archive}\$" checksums.txt > archive.sha256
  "${sha256[@]}" -c archive.sha256
)

tar -xzf "${tmp_dir}/${archive}" -C "${tmp_dir}" helmcov
# Stage beside the target so the rename is atomic; an interrupted install never leaves a binary that looks installed.
install -m 0755 "${tmp_dir}/helmcov" "${HELMCOV_BIN}.tmp"
mv "${HELMCOV_BIN}.tmp" "${HELMCOV_BIN}"
echo "Installed helmcov at ${HELMCOV_BIN}"
