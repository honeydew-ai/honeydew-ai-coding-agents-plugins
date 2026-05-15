# Changelog

All notable changes to the Honeydew AI Plugins for Coding Agents are documented in this file.

## [1.0.11] - 2026-05-15

### Changed

- **Add `list_analysis_chats` and `provide_analysis_feedback` to query skill** — the `query` skill now covers browsing past analysis conversations and submitting feedback on completed analyses. Updated `model-exploration` tool reference to include these tools.

## [1.0.10] - 2026-05-14

### Changed

- **Improve description field guidance** — `description` in metrics and attributes should contain business context for non-technical users (WHY it exists, ownership, caveats) and be omitted when there's nothing to add beyond the name. Updated both SKILL.md files and examples to demonstrate the pattern.

## [1.0.9] - 2026-05-11

### Changed

- **Update Honeydew MCP server URL** — all `.mcp.json` configurations now point to `https://mcp.honeydew.cloud/mcp`

## [1.0.8] - 2026-05-09

### Added

- Permanent download URL for the Claude marketplace zip: `releases/latest/download/honeydew-ai-claude.zip`

## [1.0.7] - 2026-05-09

### Added

- Automated GitHub Releases: merging a version bump to `main` now automatically creates a git tag and publishes a GitHub Release with the Claude marketplace zip attached

## [1.0.6] - 2026-05-05

### Changed

- **query skill** — updated deep analysis section to reflect the async `initiate_analysis` + `monitor_analysis` two-step pattern (replacing `ask_deep_analysis_question`); added `get_analysis_step_details` for explaining prior analysis steps; added guidance on meaningful progress reporting during polling

## [1.0.5] - 2026-05-05

### Added

- **workspace-branch skill** — new skill covering all workspace and branch management tools: listing workspaces/branches, setting session context, creating and deleting branches, reviewing branch history, and creating pull requests. Includes new MCP tools `delete_workspace_branch`, `get_branch_history`, and `create_pr_for_working_branch`.
- **abort_deep_analysis_question** — added to the model-exploration skill's AI-Powered Queries section

### Changed

- **model-exploration skill** — condensed Session & Workspace section to reference the new `workspace-branch` skill; updated tool listing to include all new branch management tools
- **All creation and query skills** — updated workspace/branch prerequisite reference from `model-exploration` to `workspace-branch`

## [1.0.4] - 2026-05-05

### Changed

- **metric-creation skill** — expanded named-metric composition guidance (FILTER, GROUP BY, derived arithmetic); added cross-entity count pattern with intent-clarification flow; improved distinct count example to distinguish simple count from join-forcing filter; fixed SKILL.md and reference.md for accuracy and clarity

## [1.0.3] - 2026-05-03

### Added

- **context-item-creation skill** — new skill guiding creation of instructions, skills, knowledge pointers, and memory events; includes strong guidance on the semantic-layer boundary and folder-based organization for agent scoping

## [1.0.2] - 2026-04-25

### Added

- **Codex plugin support** — add `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, and Codex installation documentation

### Changed

- **Agent-neutral documentation** — update README examples and stale skill cross-references to use current skill names

## [1.0.1] - 2026-04-23

### Changed

- **Update search_model documentation across all skills** — document required `search_mode` parameter (`OR`/`AND`/`EXACT`), `entity.field` scoping syntax, and guidance on which mode to use for lookups vs. broad discovery

## [1.0.0] - 2026-04-22

### Changed

- **First stable release** — bumped to 1.0.0

## [0.7.1] - 2026-04-20

### Changed

- **Update query skill** — `ask_deep_analysis_question` now accepts `agent` (optional) instead of `domain`; use `list_agents` to discover available agents
- **Update model-exploration skill** — added Agents & Context discovery tools: `list_agents`, `get_agent`, `list_context_items`, `get_context_item`
- **Update domain-creation skill** — noted that a domain must be exposed through an agent for AI analysis

## [0.7.0] - 2026-04-15

### Changed

- **Combine into single plugin** — merged `data-analysis-tools` and `semantic-modeling-tools` into a single `honeydew-ai` plugin. All 9 skills are now available from one plugin installation.
- **Add Honeydew MCP server** — `https://api.honeydew.cloud/mcp/` is now bundled in all `.mcp.json` configurations alongside the existing Honeydew documentation MCP.

## [0.6.2] - 2026-04-12

### Changed

- **Remove ask-question tools** — removed `ask_question_get_data` and `ask_question_get_sql` from the query skill, model-exploration skill, and hook matcher
- **Expand deep analysis scope** — `ask_deep_analysis_question` now covers simple natural language questions in addition to complex/multi-step analysis, replacing the removed ask-question tools

## [0.6.1] - 2026-03-15

### Changed

- **Gemini CLI support** — skills directory moved from `skills/` to `.gemini/skills/` for native Gemini CLI integration

## [0.6.0] - 2026-03-09

### Added

- **Workspace & branch session tools** — document `list_workspaces`, `list_workspace_branches`, `get_session_workspace_and_branch`, `set_session_workspace_and_branch`, and `create_workspace_branch` MCP tools in model-exploration skill
- **Prerequisites sections** — all creation skills and the query skill now include workspace/branch context prerequisites

## [0.5.5] - 2026-03-08

### Added

- **Domain discovery tools** — document `list_domains` and `get_domain` MCP tools in model-exploration, domain-creation, and query skills

## [0.5.4] - 2026-03-08

### Changed

- **order_by quoted strings** — all `order_by` field references now use double-quoted strings (SQL identifier style) across query, filtering, and model-exploration skills

## [0.5.3] - 2026-03-08

### Added

- **Duplicate values example** in the query skill — find duplicates by fetching a field with its count and filtering on count > 1
- **Order by count** in the distinct values tip for better data exploration
- **Metric value filtering** section in the filtering skill — filtering on aggregated values (post-aggregation), with examples in `examples.md`

## [0.5.2] - 2026-03-05

### Added

- `.cursor/skills/` directory with symlinks to all plugin skills

## [0.5.1] - 2026-03-05

### Changed

- Reuse existing attributes/metrics by reference and avoid `COUNT(*)` across metric-creation, attribute-creation, and query skills

## [0.5.0] - 2026-03-02

### Added

- **GitHub Copilot marketplace** — added `.github/plugin/marketplace.json` for GitHub Copilot plugin discovery

## [0.4.2] - 2026-03-02

### Added

- **PreToolUse hooks** for both plugins — automatically prompt skill loading when Honeydew MCP tools are called

## [0.4.1] - 2026-03-02

### Added

- **Distinct values tip** in the query skill — how to retrieve unique values for a field by combining it as an attribute with a COUNT metric
- Cross-references from the filtering skill (discover filter values) and attribute-creation skill (validate attribute output) to the new tip

## [0.4.0] - 2026-03-01

### Changed

- Updated MCP tool names and added warehouse discovery tools

## [0.3.1] - 2026-03-01

### Changed

- Removed `rollup` and `hidden` fields from all skill documentation, YAML templates, and examples — these fields are not needed for AI-driven modeling

## [0.3.0] - 2026-02-27

### Added

- **Honeydew documentation MCP** (`honeydew-docs`) bundled out of the box in both plugins — provides access to Honeydew documentation search with no authentication required
- **Documentation Lookup** sections in 7 skills (model-exploration, entity-creation, relation-creation, domain-creation, metric-creation, attribute-creation, query) — guiding when and what to search in the docs

## [0.2.0] - 2026-02-27

### Added

- **domain-creation** skill — create, update, and delete Honeydew domains with entity selection, field selectors, semantic filters, source filters, and parameter overrides
- Domain validation section in the **validation** skill

## [0.1.1] - 2026-02-25

### Added

- `import_tables` tool as a new entity creation method in the entity-creation skill

## [0.1.0] - 2026-02-24

### Added

- Plugin marketplace setup with `marketplace.json`
- **Semantic Modeling Tools** plugin with 6 skills:
  - **model-exploration** — explore entities, search fields, inspect relationships
  - **entity-creation** — create entities from data warehouse tables
  - **relation-creation** — define joins between entities with type, cardinality, and conditions
  - **attribute-creation** — create calculated attributes (dimensions) with SQL expressions
  - **metric-creation** — create business metrics (aggregations) like totals, averages, and ratios
  - **validation** — post-creation validation with type-specific sanity checks
- **Data Analysis Tools** plugin with 2 skills:
  - **query** — structured YAML perspectives, natural language questions, and deep analysis
  - **filtering** — advanced filter syntax for comparisons, dates, nulls, and full-text search
