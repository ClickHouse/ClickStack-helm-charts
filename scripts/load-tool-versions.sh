#!/usr/bin/env bash
# Load defaults from scripts/tool-versions.env without overriding existing env vars.
load_tool_versions() {
  local root_dir="${1:?root dir required}"
  local line key default

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    key="${line%%=*}"
    default="${line#*=}"
    if [[ -z "${!key:-}" ]]; then
      export "${key}=${default}"
    fi
  done < "${root_dir}/scripts/tool-versions.env"
}
