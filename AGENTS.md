# Honeydew AI Plugins for Coding Agents

## Repo Structure

```
skills/                          # All 13 skills (single honeydew-ai plugin)
  filtering/
  query/
  query-debugging/
  attribute-creation/
  context-item-creation/
  conversation-review/
  domain-creation/
  entity-creation/
  metric-creation/
  model-exploration/
  relation-creation/
  validation/
  workspace-branch/
hooks/                           # PreToolUse hook scripts (shared by Claude Code and Codex)
assets/                          # logo.svg
plugins/honeydew-ai/             # Codex marketplace wrapper path (symlinks to root plugin files)
.agents/plugins/                 # Codex marketplace config (marketplace.json)
.claude-plugin/                  # Claude plugin config (plugin.json, .mcp.json, marketplace.json)
.cursor-plugin/                  # Cursor plugin config (plugin.json, .mcp.json, marketplace.json)
.github/plugin/                  # GitHub Copilot config (plugin.json, marketplace.json)
.codex-plugin/                   # Codex plugin config (plugin.json)
.mcp.json                        # Root-level MCP config (honeydew server, includes docs tools)
gemini-extension.json            # Gemini CLI extension manifest (mcpServers + skills)
```

The repo root IS the single `honeydew-ai` plugin, and also the Gemini CLI extension. Codex marketplace entries must point to a non-empty plugin path, so `plugins/honeydew-ai/` is a wrapper made of relative symlinks back to the canonical root plugin files — including `hooks`, without which Codex has no hooks to discover. `.cursor/skills/` contains symlinks to `skills/<name>`. Gemini CLI loads the extension straight from the repo root: it reads `gemini-extension.json` for the MCP server and auto-discovers skills under `skills/`. Like the Claude plugin, the extension ships skills and the MCP server only — no context file. There is intentionally no `GEMINI.md`; if present at the root, Gemini would auto-load it as extension context.

## Version Bump Checklist

**Source of truth:** `.claude-plugin/plugin.json` — update this first. CI (`validate-versions.sh`) checks that all other version fields match it.

When releasing a new version, update **all** of these files:

1. `.claude-plugin/plugin.json` — `version` **(source of truth — update this first)**
2. `CHANGELOG.md` — add a new entry at the top (format: `## [X.Y.Z] - YYYY-MM-DD`)
3. `.claude-plugin/marketplace.json` — `metadata.version` + plugin `version`
4. `.cursor-plugin/marketplace.json` — `metadata.version` + plugin `version`
5. `.github/plugin/marketplace.json` — `metadata.version` + plugin `version`
6. `.agents/plugins/marketplace.json` — marketplace entry if install policy/category/source changes (Codex source path must stay `./plugins/honeydew-ai`)
7. `.cursor-plugin/plugin.json` — `version`
8. `.github/plugin/plugin.json` — `version`
9. `.codex-plugin/plugin.json` — `version`
10. `gemini-extension.json` — `version`

Run `./scripts/validate-versions.sh` locally to confirm all files are in sync before pushing.

## CHANGELOG Entries

An entry tells someone installing the plugin what changed and whether they care. It is not the PR description and not a record of how the work went.

- **One bullet per user-visible change.** The norm in this file is 1–3 bullets; 7 is a large release. A change needing a sub-list is usually several changes, or belongs in the PR.
- **Two sentences per bullet, ~250–450 characters.** Bolded lead naming the change, then why it matters.
- **Group under `### Added` / `### Changed` / `### Fixed`.**
- **Write for the installer.** Name the skill, tool, or matcher they will notice — not functions, file paths, or line numbers.
- **Fold in work that never shipped.** A bug introduced and fixed inside the same release is invisible to users; it gets no bullet.

Keep in the PR description, out of the CHANGELOG: verification and test results, measurements, alternatives considered, known limitations, follow-up work.

## New Skill Checklist

When adding a new skill, update **all** of these:

1. `skills/<skill-name>/SKILL.md` — create the skill with YAML frontmatter (`name`, `description`)
2. `.cursor/skills/`: `ln -s ../../skills/<skill-name>/ .cursor/skills/<skill-name>`
3. `.github/plugin/plugin.json` — add `"./skills/<skill-name>"` to the `skills` array. This is the **only** plugin config that enumerates skills one by one; miss it and GitHub Copilot does not ship the skill.
4. `README.md` — add row to the Available Skills table and update the skill count
5. `AGENTS.md` — update repo structure listing and skill count
6. Bump the version (see Version Bump Checklist)

Steps 2–4 are the hand-maintained registrations; `./scripts/validate-skills.sh` checks all three against the directories holding a `SKILL.md` and runs in CI. Run it locally before pushing.

`.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json` list no skills at all; `.codex-plugin/plugin.json` points at the directory (`"skills": "./skills/"`); Gemini CLI auto-discovers every `skills/<skill-name>/SKILL.md` under the extension root. None of them take a per-skill entry.

## Skill Conventions

- Each skill lives in `skills/<skill-name>/`
- `.cursor/skills/` contains relative symlinks to every skill directory.
  When adding, renaming, or deleting a skill, update the symlinks:
  - `.cursor/skills/`: `ln -s ../../skills/<skill-name>/ .cursor/skills/<skill-name>`
  Gemini CLI needs no symlinks — its extension auto-discovers skills under the root `skills/` directory.
- `SKILL.md` (uppercase) is required — has YAML frontmatter with `name` and `description`
- Optional companion files: `examples.md`, `reference.md` (lowercase)
- Field references always use `entity.field_name` (fully qualified)
- YAML object names use `snake_case`; display names use Title Case
- Cross-reference other skills by name in backticks (e.g., "see the **filtering** skill")
- Creation skills must end with a "MANDATORY: Validate After Creating" section pointing to the `validation` skill
- After `create_object`/`update_object`, always display the `ui_url` from the response

## .claude-plugin vs .cursor-plugin vs .github/plugin vs .codex-plugin

- `plugin.json`: Cursor adds `displayName` and `logo`; GitHub adds `skills` array and `repository`; Claude has neither
- Codex uses `.codex-plugin/plugin.json` with `skills`, `hooks`, `mcpServers`, and `interface` metadata
- Codex marketplace metadata lives in `.agents/plugins/marketplace.json`
- `.mcp.json`: present in Claude, Cursor, and root (`.mcp.json`); GitHub does not use `.mcp.json`
- `marketplace.json`: all three (`.claude-plugin/`, `.cursor-plugin/`, `.github/plugin/`) must be kept in sync
- Hooks: Claude Code auto-discovers `hooks/hooks.json`; Codex needs the explicit `"hooks": "./hooks/hooks.json"` entry in `.codex-plugin/plugin.json` **and** the `hooks` symlink in `plugins/honeydew-ai/`. Both harnesses use the same event schema, the same `mcp__<server>__<tool>` matchers and the same `permissionDecision` output, so one set of scripts serves both — Cursor, Copilot and Gemini do not run them.

## CI

- GitHub Actions validates YAML frontmatter on PRs (uses `bun` + `.github/scripts/validate-frontmatter.ts`)
- GitHub Actions validates plugin structure and version consistency on PRs (`scripts/validate-versions.sh`)
- GitHub Actions validates skill registration on PRs — the GitHub Copilot `skills` array, the `.cursor/skills/` symlinks, and the README table and count (`scripts/validate-skills.sh`)
