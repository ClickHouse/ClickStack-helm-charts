#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/load-tool-versions.sh"
load_tool_versions "${ROOT_DIR}"
CHART_PATH="${CHART_PATH:-charts/clickstack}"
TESTS_PATH="${TESTS_PATH:-charts/clickstack/tests}"
COVERAGE_OUT="${COVERAGE_OUT:-coverage.out}"
COVERAGE_XML="${COVERAGE_XML:-coverage.xml}"
THRESHOLD="${THRESHOLD:-${COVERAGE_THRESHOLD:-30}}"
MAX_SCENARIOS="${MAX_SCENARIOS:-20}"
SEED="${SEED:-42}"
VERBOSE="${VERBOSE:-}"

"${ROOT_DIR}/scripts/install-helmcov.sh"
HELMCOV_BIN="${ROOT_DIR}/.tools/helmcov-${HELMCOV_VERSION}"

chart_abs="${ROOT_DIR}/${CHART_PATH}"
tests_abs="${ROOT_DIR}/${TESTS_PATH}"

if [[ ! -f "${chart_abs}/Chart.yaml" ]]; then
  echo "Chart not found: ${chart_abs}/Chart.yaml" >&2
  exit 1
fi
if ! compgen -G "${tests_abs}/*_test.yaml" >/dev/null; then
  echo "No helm-unittest suites found in ${tests_abs}" >&2
  exit 1
fi

helmcov_args=(
  --chart "${ROOT_DIR}/${CHART_PATH}"
  --tests "${ROOT_DIR}/${TESTS_PATH}"
  --format go
  --format cobertura
  --go-coverprofile "${ROOT_DIR}/${COVERAGE_OUT}"
  --cobertura-file "${ROOT_DIR}/${COVERAGE_XML}"
  --max-scenarios "${MAX_SCENARIOS}"
  --seed "${SEED}"
)

# The threshold is the coverage gate; refuse to run with it disabled (0/empty)
# so a config change can't silently neutralize enforcement.
if [[ -z "${THRESHOLD}" || "${THRESHOLD}" == "0" ]]; then
  echo "COVERAGE_THRESHOLD must be a positive integer; refusing to run with the coverage gate disabled." >&2
  exit 1
fi
helmcov_args+=(--threshold "${THRESHOLD}")
if [[ "${VERBOSE}" == "1" ]]; then
  helmcov_args+=(--verbose)
fi

"${HELMCOV_BIN}" "${helmcov_args[@]}"
