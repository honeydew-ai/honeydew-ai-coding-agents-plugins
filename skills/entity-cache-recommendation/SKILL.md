---
name: entity-cache-recommendation
description: Use when a semantic layer curator or data engineer wants to speed up expensive calculated attributes (dimensions built from window functions, aggregations, JOINs, or large table scans) by finding entity-caching opportunities in Honeydew query history — ranking costly, frequently-used calculated attributes, checking which entities are already cached, and enabling/building an entity cache on a branch. Triggers on "cache an entity", "entity cache recommendations", "speed up a slow calculated attribute/dimension", "materialize an entity to avoid recomputation". For pre-aggregating metrics use aggregate-recommendation; for choosing between performance levers use performance-tuning.
---

## Prerequisites

Before starting, ensure you are on the correct workspace and branch. Use `get_session_workspace_and_branch` to check the session context; if nothing is set, use `list_workspaces` and `set_session_workspace_and_branch` (see the `workspace-branch` skill). Read the model on `prod`; apply changes on a development branch later.

Query history is scoped to the session's workspace. Non-admin callers see only their own queries; admins see all and can filter by `user_in`.

---

## Overview

A Honeydew **entity cache** materializes an entity as a table so its **calculated attributes are computed once instead of on every query**. By default every access to a calculated attribute recomputes it; when the attribute is expensive — built from window functions, aggregations, JOINs, or large table scans — that recomputation dominates query time. When an entity cache exists, Honeydew automatically reads it (and pushes filters down into it) instead of recomputing.

**Your job is to turn query history into entity caches**: find the expensive, frequently-used calculated attributes worth materializing, check which entities are already cached, and — for genuine gaps — enable and build an entity cache on a branch for the user to review and deploy.

This is the **entity-caching lever** — one of Honeydew's performance levers. Reach for it when the user wants to:

- "Cache the `<entity>` entity" / "enable an entity cache"
- Speed up a slow **calculated attribute / dimension** that recomputes on every query
- Materialize an entity to avoid recomputing complex logic

**Not the right tool when:** the cost is in **aggregating metrics** over a large fact by repeating groups — that is the `aggregate-recommendation` (aggregate-awareness) lever. If the user asks generally to *speed up the model* or *which approach to use*, start with the `performance-tuning` router. For running a *new* query use `query`; for defining an attribute use `attribute-creation`.

See [reference.md](reference.md) for what makes an attribute expensive, how caches are used and matched, the entity YAML `delivery` schema, deployment/refresh mechanics, and how to read `entity_caches_used` from history. This body is the workflow; that file is the detail.

---

## The Analysis Workflow

### Phase 1: Collect query history

Use `list_query_history` (see also the `query-debugging` skill). Scope by the user's window / `domain_in` / `client_in` if given; otherwise take a recent window.

**Token-size discipline (hard rule).** `list_query_history` payloads are large:

- Page in **batches of ≤25** (`limit`/`offset`), or narrow with `from_execution_time` / `to_execution_time`.
- Keep `include_yaml` / `include_sql` **off** during the scan — enable them only on the runs you drill into.
- If a result is saved to a file for exceeding the token limit, **do not read it whole** — use `jq` on the file or a subagent.

Ignore `FAILED` / `RUNNING` / `CANCELED` and compile-only (`status: null`) runs.

### Phase 2: Find the calculated attributes in play

Reduce runs to the **attributes** they reference (from the YAML `attributes` list — enable `include_yaml` on representatives). Count how often each attribute appears and attach the runs' warehouse cost (`dwh_end_at − compile_end_at`). Note `entity_caches_used` from the YAML metadata — attributes on entities already cached are not candidates.

### Phase 3: Judge which attributes are expensive

Only **calculated** attributes benefit — raw passthrough columns do not. Inspect each candidate's definition with `get_field` (and `get_entity` for grain). An attribute is an entity-cache candidate when its SQL uses:

- **window functions** (`OVER (...)`) or **aggregations** feeding a per-row value,
- **JOINs / multi-hop references** to other entities, or
- **large table scans** / multi-step calculated-attribute chains.

Raw columns, simple arithmetic, and cheap `CASE` expressions are **not** worth caching.

### Phase 4: Rank by cost × usage

Score candidate attributes by usage frequency × warehouse cost — an expensive attribute hit by many queries (or a few very slow ones) ranks highest. Group candidates **by entity**: the cache is enabled on the entity, so several hot attributes on the same entity are cached together in one move. Drop attributes that are cheap, rarely used, or already cache-served. Present the ranked list.

### Phase 5: Coverage & design

- **Coverage** — check `entity_caches_used` in history and the entity's current `delivery` config (`get_entity`). If the entity is already cached and the attribute still recomputes, the attribute may post-date the cache — a **refresh/rebuild**, not a new cache.
- **Design** — decide, per entity: cache **target** (`table` for heavy compute; `view` only when it mainly simplifies access), the **target `database` + `schema`** where the table lands, and the Snowflake **`warehouse`** (compute that materializes/refreshes it) — Databricks uses `catalog` + `http_path`. Ask the user for the location/warehouse if not obvious; if omitted they fall back to the workspace connection's defaults. Caches are **singular and shared across domains and branches** — one cache per entity serves everyone; design it to hold the entity's expensive attributes broadly, not per-workload. See reference.md for the YAML.
- **Freshness & refresh timing (crucial — discuss with the user)** — a cache is a materialized table with **freshness latency**: queries read the last refresh, not live data. Ask how fresh the attribute must be, and **sequence the refresh after the upstream ETL** that loads its source — a rebuild on an independent timer serves stale values right after each load. Match the target: `table` = no auto-refresh (chain it after the ETL); `dynamic_table` = tune its `lag` to the tolerance. See reference.md.

### Phase 6: Validate the plan

Before writing, confirm the cache will actually be exercised: the candidate attributes are calculated (not raw), expensive by definition, and used by real queries. There is no compile-time debug flag for entity caches as there is for aggregates — validation is by definition + usage evidence now, and by `entity_caches_used` after the cache is built and deployed (Phase 7 / MANDATORY section).

---

## Creation Method

Enable the cache on the **entity** and build it on a branch. **Never write to `prod`.**

1. **Branch** — `create_workspace_branch(workspace_id="...", branch_name="entity-cache-<entity>-<date>")` (session switches automatically), or switch to an existing dev branch.
2. **Enable caching on the entity** — read the entity YAML (`get_entity`), add the `delivery` / `use_for_cache` block **including the target `database`/`schema` and Snowflake `warehouse` (or Databricks `catalog`/`http_path`)** (see reference.md), and `update_object` with its `object_key`.

   > **Minimal diff rule:** preserve the existing field order and formatting — objects are versioned in git, so change only the `delivery` block.
3. **Validate** — `validate_object` on the entity YAML; fix errors. **Always display the returned `ui_url`.**
4. **PR** — review with `get_branch_history`, then `create_pr_for_working_branch(title="Entity cache for <entity> — <date>", description="Caches expensive calculated attributes <list> used by <N> queries.")`. Display the PR URL.

### After creating: deploy & refresh (the user's step)

An entity cache **does nothing until its table is built**, and Honeydew only uses it while that table exists. Do not deploy automatically. Tell the user the deploy path (Honeydew UI "deploy"; the Snowflake `DEPLOY_ENTITY` API; or building from `GET_SQL_FOR_ENTITY` in your ETL) and the refresh setup. **Refresh timing is the critical part**: the rebuild must run *after* the upstream ETL that feeds the cache — an orchestration dependency, not an independent timer — or queries read stale, pre-load values. Note **which compute warehouse runs the build**: the `warehouse` set in `delivery`, or — if you run `DEPLOY_ENTITY` yourself — the executing Snowflake session's warehouse. Because the calculation logic can change, an incremental refresh must check whether the logic changed between runs — see reference.md.

---

## Discovery Helpers

- `list_query_history` — the workload source (see the `query-debugging` skill for reading results); YAML metadata exposes `entity_caches_used`
- `get_field` — a calculated attribute's YAML/SQL, to judge whether it is expensive (window/agg/join)
- `get_entity` — an entity's attributes, keys, relations, and current `delivery` config
- `search_model` — find entities and attributes across the model

---

## Documentation Lookup

Use `search_docs` and `query_docs_filesystem` (from the `honeydew` MCP server) for more than reference.md covers. Search for: "entity caching", "calculated attribute", "use_for_cache", "DEPLOY_ENTITY", "dataset materialization", "incremental aggregate updates", "Power BI data caching".

---

## Best Practices

- **Cache calculated attributes, not raw columns.** Passthrough columns recompute for free; only window/aggregation/JOIN/large-scan attributes pay off.
- **Cache per entity, broadly.** The cache is singular and shared across domains/branches — design it to serve all of an entity's hot attributes, not one workload.
- **Prefer `table` for heavy compute.** Use `view` only when the goal is simplified access rather than avoided recomputation.
- **Rank by cost × usage.** A cheap attribute, however popular, is not worth a cache; a very expensive one used occasionally may be.
- **Watch logic drift on refresh.** If the attribute's SQL changes, an incremental refresh can mix logic versions — validate the computation matches before trusting the cache.
- **Right lever check.** If the slow part is aggregating a metric, not producing a dimension, this is the wrong lever — use `aggregate-recommendation`.

---

## MANDATORY: Validate the Cache

**After enabling and deploying an entity cache, you MUST validate it two ways:**

1. **Cache is used** — re-run a representative query with `include_yaml=true` and confirm `entity_caches_used` now lists the cache. If it doesn't, the cache isn't deployed, isn't valid (table missing/stale), or the attribute isn't actually served by it.
2. **Correctness** — invoke the `validation` skill (or `get_data_from_fields`) to confirm cached results match the un-cached computation. A cache that returns wrong or stale values is worse than none; if they diverge, investigate logic drift or refresh.
3. **Freshness** — confirm the cache reflects the latest ETL load (check it after a refresh). If the rebuild isn't sequenced after the feeding ETL, it will serve stale values right after each load — fix the ordering, not just the data.

---

## Common Pitfalls to Avoid

- **Pulling history wide** — batch ≤25 rows, YAML/SQL off during the scan; `jq`/subagent on saved files.
- **Caching raw or cheap attributes** — no recomputation to save; wasted storage and refresh cost.
- **Building per-workload caches** — the cache is singular per entity and shared; design it broadly.
- **Confusing the levers** — aggregating metrics → `aggregate-recommendation`; recomputing a dimension → here.
- **Forgetting deploy/refresh** — an entity isn't cached until its table exists, and a stale table serves old values.
- **Ignoring logic drift** — refreshing incrementally after changing the attribute's SQL mixes versions.
- **Refreshing out of sync with the ETL** — schedule the rebuild *after* the feeding ETL; a cache on an independent timer serves stale, pre-load values.
