#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="$repo_root/.githooks"

if [ ! -d "$hooks_dir" ]; then
  echo "missing hooks directory: $hooks_dir" >&2
  exit 1
fi

# Point git at .githooks instead of copying into .git/hooks, so we never
# clobber an existing hook (husky, pre-commit framework, etc.).
git -C "$repo_root" config core.hooksPath .githooks
echo "configured core.hooksPath -> .githooks"
