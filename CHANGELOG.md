# Changelog

All notable changes to the Honeydew AI Plugins for Coding Agents are documented in this file.

## [1.3.7] - 2026-08-14

### Added

- **`entity-creation` hands off to `relation-creation` once an entity validates** — new entities, especially a batch from `import_tables`, used to land with their foreign keys exposed but nothing joined. The skill now looks for FK candidates on either side of the new entity, including many-to-many links through a bridge table, and asks which relations to create rather than leaving the entities unconnected.
- **`relation-creation` covers many-to-many** — the skill documented no way to express one, though `rel_type` offers only `many-to-one` and `one-to-many`. A bridge table is now a worked example: keep the junction table as its own entity at one row per pair and give it two `many-to-one` relations in a single update.

### Fixed

- **Honeydew object writes are now gated on every skill that governs them** — a relation lives inside its source entity's YAML, and the hook stopped at the first match, so those writes always resolved to `entity-creation` and `relation-creation` could never be required. Payloads matching more than one skill now name them all in a single prompt.

## [1.3.6] - 2026-08-14

### Changed

- **The `create_object` attribute type is named "calculated attribute"** — the conversation-review skill called it plain "attribute" where the YAML literal is `calculated_attribute`, matching the wording now used in the Honeydew docs. Wording only; no change to the YAML or tool parameters.

## [1.3.5] - 2026-08-13

### Changed

- **`metric-creation` says what each grouping form returns** — a fixed `GROUP BY (dim)` groups by `dim` alone, regardless of the query's own groups, while `GROUP BY (*, dim)` adds `dim` to them. The skill presented the fixed form as complete on its own, so a metric built from it returned one row per `dim` value where a per-group value was intended.

## [1.3.4] - 2026-08-12

### Added

- **Codex runs the guide hooks too** — the Codex wrapper now ships the `hooks` directory and the Codex manifest declares `hooks/hooks.json`, so Honeydew MCP calls from Codex are gated on their skill. Codex lists every installed skill at session start without loading any of them, so the first call per skill is blocked once there; the retry then proceeds as on Claude Code.

## [1.3.3] - 2026-08-11

### Changed

- **Honeydew tool calls now require their skill rather than suggesting it** — query, exploration and typed create/update calls are blocked once per session when the matching skill is not loaded, and the reason names the skill to load before retrying. Injected context could not do this: it arrives with the tool result, after the call has already run.
- **A block can never wedge a workflow** — it happens at most once per skill, so a retry always goes through, and anything uncertain (skill not installed, unwritable state, unparseable payload) lets the call proceed.

### Fixed

- **Skill reminders no longer repeat on every tool call** — they rendered in the transcript and kept no state, so four consecutive queries produced four identical notices. Guidance now fires at most once per session per skill, and not at all once the skill is loaded.
- **Deep analysis was never covered** — the query matcher named `ask_deep_analysis_question`, which this MCP server does not expose, so `initiate_analysis` matched no hook and got no guidance.

## [1.3.2] - 2026-08-11

### Changed

- **Frame deep analysis as an analyst sub-agent you delegate to** — `initiate_analysis` was documented as a tool to call, so the rules around it (redirect instead of aborting, a fresh conversation on topic change, follow-ups by `conversation_id`) read as API conventions with nothing behind them. Method 2 now opens by describing it as a stateful, resumable analyst sub-agent that plans its own investigation.
- **Ask for the goal, not the plan** — a new `Asking the Question` section, because an over-constrained question suppresses the semantic-layer context that is the reason to use deep analysis at all. Mirrored in `model-exploration` at the handoff point, and the two worked examples that prescribed dimensions and correlations to the analyst are rewritten.
- **Document what to do once inside an analysis** — a new `Continuing Inside an Analysis` section: follow up when the next step needs reasoning or reuses groups the conversation already computed, drop out to `get_data_from_fields` for deterministic slices. `Combining Methods` now records the investigate → query direction, since a finished analysis reports the exact field names a structured query needs.
- **Document abort as an interrupt, not a cancel** — the section never named `abort_analysis` and told the reader to let a misdirected analysis finish. Abort preserves conversation state and the question sent on resume is the correction, so interrupt-and-resume is how to steer mid-flight; self-initiated aborts are gated on a contradiction with what the user asked for, not on a plan differing from the one the caller had in mind.
- **Sync the routing summary with the decision flow** — the Overview table and the deep-analysis `Use when` list still led with field knowledge, the discriminator 1.3.1 removed from the flow itself.
- **Stop pointing debugging at the generated SQL** — its output is long machine-generated SQL, and the model it compiled from is the better source for what a field computes. `get_sql_from_fields` is now scoped to handing the SQL onwards and to bisecting a failing query, with debugging pointed at `get_field` / `get_entity`.
- **Gate `provide_analysis_feedback` on evidence rather than satisfaction** — it sat inline in the analysis lifecycle as a closing step, and an agent rating an analysis it asked for itself is self-assessment. Now its own section: there is one entry per conversation, so the user's judgement must never be overwritten, and agent-initiated feedback is allowed only from a check it can name, tagged `[agent]`.

## [1.3.1] - 2026-08-04

### Changed

- **Route investigative questions to deep analysis** — the `query` skill's decision flow asked whether the exact field names were known before asking whether the question was an investigation, so an investigative question arriving from model exploration (which is what surfaces field names) took the structured-query branch and never reached `initiate_analysis`. The investigation check now comes first, and the structured-query `Do NOT use` list covers understand/explain goals and answers that would take several queries to assemble.
- **Scope `model-exploration` to the model, not the data** — its description offered "running simple structured queries to inspect data", which reads as self-sufficient once exploration is underway. It now describes structured queries as spot-checks and states, above the discovery steps, that any question about the data belongs to the `query` skill's deep analysis even mid-exploration with known field names.

## [1.3.0] - 2026-07-14

### Added

- **New `query-debugging` skill** — covers the `list_query_history` MCP tool for reviewing and inspecting past query executions: what ran, from which client (BI tools, SQL interface, MCP, deep analysis), who ran it and when, the semantic YAML (`include_yaml`) and compiled SQL (`include_sql`) behind a run, and the original SQL text for SQL-interface clients. Documents filtering by status/client/domain/user/time, a review flow, a failure-triage flow, and a bisection technique for isolating internal errors down to a minimal reproduction. Cross-linked from the `query`, `model-exploration`, and `validation` skills.

## [1.2.0] - 2026-07-09

### Removed

- **Remove the separate `honeydew-docs` MCP server** — the Honeydew MCP server now embeds documentation access via the `search_docs` and `query_docs_filesystem` tools, so the standalone documentation server is no longer bundled. Removed `honeydew-docs` from all `.mcp.json` configurations and `gemini-extension.json`.

### Changed

- **Update skills to use the embedded documentation tools** — all "Documentation Lookup" sections now point to `search_docs` and `query_docs_filesystem` on the `honeydew` MCP server instead of the `honeydew-docs` tools.

## [1.1.2] - 2026-06-28

### Changed

- **`context-item-creation` skill: generate skill bodies with deep analysis** — for a `subtype: skill` item, the skill now directs you to have deep analysis (`initiate_analysis` + `monitor_analysis`) author the playbook and return a generalized markdown workflow, then wrap that as the context item — since the same engine consumes it and follows playbooks grounded in the constructs it executes. Adds a short authoring workflow: because the builder is an AI with full schema access and its own analysis-planning skills, prompt it by goal with only external business context it can't derive — over-specifying steps or semantic objects can suppress its skills and derail it, so prescribe those only when the user explicitly asked.

## [1.1.1] - 2026-06-28

### Changed

- **`domain-creation` skill: document domain hierarchy** — added coverage of `extends` (extending one or more parent domains), what gets inherited (entities, filters, parameters, tags, labels, metadata), merge rules (scalar replace vs. collection extend, additive labels), `merge: remove` for dropping inherited items, and multiple inheritance with left-to-right precedence. Updated SKILL.md, reference.md, and examples.md.

## [1.1.0] - 2026-05-15

### Added

- **New `conversation-review` skill** — guides semantic/context layer curators through bulk-reviewing past analysis conversations, categorizing user feedback into actionable improvement areas (missing metrics, wrong calculations, missing context items, etc.), and applying targeted changes to the semantic model or context layer on a branch.
- **`query` skill: add `get_stored_conversation`** — retrieve the full message history of a past conversation, with optional step-level detail via `with_step_ids`.

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
