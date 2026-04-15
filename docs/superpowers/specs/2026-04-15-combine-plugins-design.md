# Combine Plugins into Single `honeydew-ai` Plugin

**Date:** 2026-04-15  
**Status:** Approved

## Summary

Merge `data-analysis-tools` and `semantic-modeling-tools` into a single `honeydew-ai` plugin living at the repo root. The root-level plugin config files (`.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.github/plugin/plugin.json`, `hooks/`, `assets/`, `.mcp.json`) were already prepared for this change. What remains is moving the skills, updating the marketplaces, and removing the old plugin directories.

## Final Structure

```
/
  .claude-plugin/
    plugin.json         # honeydew-ai v0.7.0 — already done
    marketplace.json    # updated: single plugin, source "."
    .mcp.json           # updated: add honeydew MCP server
  .cursor-plugin/
    plugin.json         # honeydew-ai v0.7.0 — already done
    marketplace.json    # updated: single plugin, source "."
    .mcp.json           # updated: add honeydew MCP server
  .github/plugin/
    plugin.json         # honeydew-ai v0.7.0 with skills list — already done
    marketplace.json    # updated: single plugin, source "."
  .mcp.json             # updated: add honeydew MCP server
  assets/
    logo.svg            # already done
  hooks/
    hooks.json          # already done (references honeydew-ai:* skills)
    guide-creation.sh   # already done
    guide-exploration.sh
    guide-query.sh
  skills/               # NEW: all 9 skills at repo root
    filtering/
    query/
    attribute-creation/
    domain-creation/
    entity-creation/
    metric-creation/
    model-exploration/
    relation-creation/
    validation/
  .cursor/skills/       # symlinks updated to ../../skills/<name>
  .gemini/skills/       # symlinks updated to ../../skills/<name>
  gemini-extension.json # version bumped to 0.7.0
  CHANGELOG.md          # new entry for v0.7.0
```

`plugins/` directory is deleted entirely.

## Steps

1. **Move skills** — copy all 9 skill directories from the two old plugins into `skills/` at repo root.
2. **Update skill references in hooks** — the root-level hook scripts already use `honeydew-ai:*` names, no changes needed.
3. **Update `.cursor/skills/` symlinks** — repoint each symlink from `../../plugins/.../skills/X` to `../../skills/X`.
4. **Update `.gemini/skills/` symlinks** — same as above.
5. **Update marketplace files** — all three marketplace files: set `pluginRoot` to `"."`, replace two-plugin list with a single `honeydew-ai` entry with `source: "."`.
6. **Update `.mcp.json` files** — add the `honeydew` MCP server to the three `.mcp.json` files (root, `.claude-plugin/`, `.cursor-plugin/`):
   ```json
   "honeydew": {
     "type": "http",
     "url": "https://api.honeydew.cloud/mcp/"
   }
   ```
7. **Bump version** — `gemini-extension.json` to `0.7.0`; all marketplace `metadata.version` fields (already 0.7.0 in root plugin.json files).
8. **Add CHANGELOG entry** — document v0.7.0 consolidation.
9. **Delete old plugins** — remove `plugins/data-analysis-tools/` and `plugins/semantic-modeling-tools/`.
10. **Update CLAUDE.md** — reflect new single-plugin structure, updated skill conventions, updated version bump checklist, add `.mcp.json` files to checklist.

## What Does Not Change

- All `plugin.json` content (name, description, version, keywords, license, author)
- All `.mcp.json` structure (the `honeydew` server is added, existing `honeydew-docs` entry unchanged)
- All `hooks/` scripts and `hooks.json`
- All `assets/`
- All skill content (SKILL.md, examples.md, reference.md files)
- `gemini-extension.json` (version bump only)

## Version

`0.7.0` — already set in the four root-level `plugin.json` files. Needs to be propagated to `gemini-extension.json` and `CHANGELOG.md`.
