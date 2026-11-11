#!/usr/bin/env bash
set -euo pipefail

BASE="${1:?Usage: check-upgrade-notes.sh <base-ref>}"

changesets=$(git diff --name-only --diff-filter=AM "$BASE"...HEAD -- '.changeset/*.md' | grep -v '^.changeset/README.md$' || true)
[ -n "$changesets" ] || exit 0

if git diff --name-only "$BASE"...HEAD | grep -qx 'docs/UPGRADE.md' && grep -qx '## Unreleased' docs/UPGRADE.md; then
  exit 0
fi

# Matches the bump however the changeset quotes the package name or ends its lines.
bump() {
  # shellcheck disable=SC2086 # one generated path per word
  grep -lE "^[\"']?[^\"':]+[\"']?:[[:space:]]*$1[[:space:]]*$" $changesets >/dev/null
}

if bump major; then
  echo "::error file=docs/UPGRADE.md::A major changeset needs a note under '## Unreleased' in docs/UPGRADE.md saying what breaks and what to do."
  exit 1
fi
if bump minor; then
  echo "::warning file=docs/UPGRADE.md::If this minor change needs action or restarts pods on upgrade, add a note under '## Unreleased' in docs/UPGRADE.md."
fi
