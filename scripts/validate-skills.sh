#!/usr/bin/env bash
# Validates the three places a skill has to be registered by hand:
#   - the skills array in .github/plugin/plugin.json  (GitHub Copilot)
#   - the .cursor/skills/ symlinks                    (Cursor)
#   - the skill table and stated count in README.md
# Claude, Codex and Gemini discover skills from the directory, so drift in any
# of these three is invisible until a user reports a skill that never arrived.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

errors=0
fail() {
  echo "$1"
  (( errors++ )) || true
}

# A skill directory is one holding a SKILL.md; anything else under skills/ is
# shipped by no config (e.g. a local, untracked skills/.claude/).
skills=$(find skills -mindepth 2 -maxdepth 2 -name SKILL.md \
  | sed 's|/SKILL.md$||; s|^skills/||' | sort)

if [[ -z "${skills}" ]]; then
  echo "error: no skills/*/SKILL.md found" >&2
  exit 1
fi

count=$(printf '%s\n' "${skills}" | wc -l | tr -d ' ')

# --- GitHub Copilot: .github/plugin/plugin.json skills array ----------------

manifest=".github/plugin/plugin.json"

if [[ ! -f "${manifest}" ]]; then
  echo "error: ${manifest} not found" >&2
  exit 1
fi

declared=$(jq -r '.skills[]' "${manifest}" | sed 's|/$||; s|^\./skills/||' | sort)

while IFS= read -r dup; do
  [[ -z "${dup}" ]] && continue
  fail "DUPLICATE ${manifest}: ${dup} listed more than once"
done < <(printf '%s\n' "${declared}" | uniq -d)

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  fail "MISSING   ${manifest}: add \"./skills/${name}\" to the skills array"
done < <(comm -23 <(printf '%s\n' "${skills}") <(printf '%s\n' "${declared}" | uniq))

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  fail "STALE     ${manifest}: ./skills/${name} is listed but no such skill exists"
done < <(comm -13 <(printf '%s\n' "${skills}") <(printf '%s\n' "${declared}" | uniq))

# --- Cursor: .cursor/skills/ symlinks --------------------------------------

while IFS= read -r name; do
  link=".cursor/skills/${name}"
  if [[ ! -L "${link}" ]]; then
    if [[ -e "${link}" ]]; then
      fail "NOTLINK   ${link} exists but is not a symlink"
    else
      fail "MISSING   ${link}: ln -s ../../skills/${name}/ ${link}"
    fi
    continue
  fi
  target=$(readlink "${link}")
  if [[ "${target%/}" != "../../skills/${name}" ]]; then
    fail "WRONG     ${link} points at ${target}, expected ../../skills/${name}/"
  elif [[ ! -f "${link}/SKILL.md" ]]; then
    fail "BROKEN    ${link} does not resolve to a skill directory"
  fi
done < <(printf '%s\n' "${skills}")

if [[ -d ".cursor/skills" ]]; then
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    fail "STALE     .cursor/skills/${name} has no matching skills/${name}"
  done < <(comm -13 <(printf '%s\n' "${skills}") \
    <(find .cursor/skills -mindepth 1 -maxdepth 1 | sed 's|^.cursor/skills/||' | sort))
fi

# --- README: skill table and stated count ----------------------------------

listed=$(sed -n 's/^| \*\*\([a-z0-9-]*\)\*\* |.*/\1/p' README.md | sort)

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  fail "MISSING   README.md: no Available Skills row for ${name}"
done < <(comm -23 <(printf '%s\n' "${skills}") <(printf '%s\n' "${listed}"))

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  fail "STALE     README.md: Available Skills row for ${name} has no matching skill"
done < <(comm -13 <(printf '%s\n' "${skills}") <(printf '%s\n' "${listed}"))

stated=$(sed -n 's/.*plugin includes \([0-9]\{1,\}\) skills.*/\1/p' README.md | head -n1)

if [[ -z "${stated}" ]]; then
  fail "MISSING   README.md: could not find the \"plugin includes N skills\" line"
elif [[ "${stated}" != "${count}" ]]; then
  fail "MISMATCH  README.md: states ${stated} skills, found ${count}"
fi

# ---------------------------------------------------------------------------

if [[ "${errors}" -eq 0 ]]; then
  echo "All ${count} skills registered in the Copilot array, Cursor symlinks and README."
else
  echo
  echo "error: ${errors} skill registration problem(s) found." >&2
  echo "See the New Skill Checklist in AGENTS.md." >&2
  exit 1
fi
