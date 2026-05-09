#!/usr/bin/env bash
# Validates that all plugin version fields match the canonical version in
# .claude-plugin/plugin.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

canonical_file=".claude-plugin/plugin.json"
canonical=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "${REPO_ROOT}/${canonical_file}" | head -n1)

if [[ -z "${canonical}" ]]; then
  echo "error: could not read version from ${canonical_file}" >&2
  exit 1
fi

echo "Canonical version: ${canonical} (from ${canonical_file})"
echo

files=(
  ".claude-plugin/marketplace.json"
  ".cursor-plugin/plugin.json"
  ".cursor-plugin/marketplace.json"
  ".github/plugin/plugin.json"
  ".github/plugin/marketplace.json"
  ".codex-plugin/plugin.json"
  "gemini-extension.json"
)

errors=0
for rel in "${files[@]}"; do
  file="${REPO_ROOT}/${rel}"
  if [[ ! -f "${file}" ]]; then
    echo "MISSING  ${rel}"
    (( errors++ )) || true
    continue
  fi
  # Extract every version value in the file and check each one.
  while IFS= read -r found; do
    if [[ "${found}" != "${canonical}" ]]; then
      echo "MISMATCH ${rel}: expected ${canonical}, found ${found}"
      (( errors++ )) || true
    fi
  done < <(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${file}")
done

if [[ "${errors}" -eq 0 ]]; then
  echo "All version fields match ${canonical}."
else
  echo
  echo "error: ${errors} version mismatch(es) found." >&2
  exit 1
fi
