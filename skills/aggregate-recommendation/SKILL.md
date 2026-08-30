---
name: aggregate-recommendation
description: Use when a semantic layer curator or data engineer wants to build aggregate-awareness pre-aggregations from Honeydew query history — analyzing what ran, ranking recurring costly metric+grain shapes, checking coverage against existing pre-aggregates, and designing/building new or extended pre-aggregate caches on a branch. Triggers on "find aggregates to build", "what should I pre-aggregate", "build/extend a pre-aggregate cache", "aggregate awareness recommendations", "pre-aggregation from query history". For choosing between performance levers use the performance-tuning skill; for caching expensive calculated attributes use entity-cache-recommendation.
---

## Prerequisites

Before starting, ensure you are on the correct workspace and branch. Use `get_session_workspace_and_branch` to check the session context; if nothing is set, use `list_workspaces` and `set_session_workspace_and_branch` (see the `workspace-branch` skill). Read the model on `prod`; apply changes on a development branch later.

Query history is scoped to the session's workspace. Non-admin callers see only their own queries; admins see all and can filter by `user_in`.

---

## Overview

A Honeydew **pre-aggregate cache** is a dynamic dataset (perspective) materialized as a table in the warehouse. When a query's groups, filters, and aggregations can be satisfied from that table, aggregate awareness rewrites the query to read the cache instead of re-scanning the fact — often orders of magnitude faster.

**Your job is to turn query history into pre-aggregations**: find the aggregation workloads worth accelerating, check whether an existing cache already covers them, and — for genuine gaps — design and build a cache on a branch for the user to review and deploy.

This is the **aggregate-awareness lever** — one of Honeydew's performance levers. Reach for it when the user wants to:

- "Find aggregates I should build" / "what should I pre-aggregate?"
- Build or extend a pre-aggregate cache from what actually ran
- Get aggregate-awareness recommendations grounded in query history

**Not the right tool when:** the user asks generally to *speed up the model* or *which approach to use* — start with the `performance-tuning` router, which diagnoses the bottleneck and routes here or elsewhere. If the cost is in an expensive **calculated attribute** (window/aggregation/join), use `entity-cache-recommendation` instead. For running a *new* query use `query`; for debugging a failure use `query-debugging`; for defining a metric/attribute/entity use those creation skills.

See [reference.md](reference.md) for the matching rules, additivity/decomposition logic, perspective YAML schema, deployment mechanics, and annotated `debug_aggregates` report examples for each classification. This body is the workflow; that file is the detail.

---

## The Analysis Workflow

### Phase 1: Collect query history

Use `list_query_history` (see also the `query-debugging` skill). Scope by the user's window / `domain_in` / `client_in` if given; otherwise take a recent window.

**Token-size discipline (hard rule).** `list_query_history` payloads are large and will fail or flood context if pulled wide:

- Page in **batches of ≤25** (`limit`/`offset`), or narrow with `from_execution_time` / `to_execution_time`.
- Keep `include_yaml` and `include_sql` **off** during the scan — enable them only on the specific runs you drill into (Phase 2).
- If a result is saved to a file for exceeding the token limit, **do not read it whole** — use `jq` on the file, or hand it to a subagent with explicit extraction instructions.

Ignore `FAILED` / `RUNNING` / `CANCELED` and compile-only (`status: null`) runs — they produced no real warehouse aggregation.

### Phase 2: Reduce to query shapes

Collapse runs into distinct **shapes**: `(metrics, group-by grain, filters, domain)`, each tagged with occurrence count and warehouse cost.

- **Semantic shape** — prefer the YAML over parsing SQL. Re-list a representative run with `include_yaml=true` and read `attributes`, `metrics`, `filters` (for AI/deep-analysis runs, `llm_response_json`'s `group_by`/`metrics`/`filters`). For raw BI clients with only `original_sql`, read the semantic column names in the SQL.
- **Cost proxy** — `dwh_end_at − compile_end_at`. Bytes-scanned is out of scope; duration is the v1 cost signal.
- **Already accelerated** — note `accelerated` and, from YAML metadata, `aggregates_used`. Shapes already served are not candidates.

Produce a shape table (metrics · grain · filter · domain · runs · cost · accelerated?) before ranking.

### Phase 3: Rank by cost × repetition

The goal is performance, so **rank — don't hard-filter**. Score each shape by repetition × cost. A slow, repeating shape is the top target — including a single expensive shape that recurs. In v1, do not aggressively filter noise: metric-less shapes (dimension/slicer queries, BI metadata indexing) have nothing to accelerate and score ~0 on their own. **Drop only** shapes with no metric and shapes already accelerated. Present the ranked candidates with run count, cost, and rationale.

### Phase 4: Coverage gate & classify

Discover existing caches with `search_model`, then run each top candidate's fields through the aggregate debug report **in that shape's own domain** (domain is part of the shape — running the gate in the wrong domain gives a misleading result):

```
get_sql_from_fields(attributes=[...grain...], metrics=[...], filters=[...],
                    domain="<the shape's domain>", debug_aggregates=true)
```

Read the `# Pre-aggregation report` header and classify each candidate:

- **Already covered** — a cache matches (directly or via roll-up). No action; report it.
- **Model / context fix** — a cache *could* serve it but a mismatch blocks it (e.g. a filter on the fact date instead of the `date` entity). Fix via the `filtering` / `context-item-creation` skills, **not** a new aggregate.
- **Extend an existing cache** — a cache on the **same entity-key grain** is missing only a metric or a key. Prefer extending.
- **New cache** — nothing is close; design one in Phase 5.

### Phase 5: Design the pre-aggregate

Design to the rules in reference.md:

- **Group by entity keys, not attributes (firm rule)** — keying on `menu.menu_item_id` serves every `menu.*` attribute via roll-up; include full composite keys. Never drop to attribute-level grain to shrink a cache — control size by **splitting into usage-aligned aggregates** instead (below).
- **Additive metrics only** — `SUM`/`COUNT`/`MIN`/`MAX` roll up. For a **non-additive ratio, store its additive components** (average → sum + count; margin → revenue + cost); the ratio recomputes from rolled-up parts. `COUNT(DISTINCT)` is exact-grain only. Use `get_field` to judge additivity; set the metric `rollup` property where auto-detection misses it. **Ask the user** when a ratio's components are ambiguous.
- **No explicit filters** — a filter limits what the cache can serve; for a data subset, build the cache in a **filtered domain**.
- **Match the domain (a cache is scoped to its domain)** — a pre-aggregate only serves queries whose domain source-filters match the cache's `domain`. Group the candidate shapes by domain: if they span **multiple domains with different source filters**, either build **one cache per domain** (multiply the dataset) or build in a **shared parent / no-source-filter domain** all the target queries inherit from. Set the perspective's `domain` accordingly. (Entity caches don't have this constraint — this is aggregate-only.)
- **One entity-key aggregate per usage cluster** — group the target shapes into clusters by *which entities they group by*, then build one aggregate per cluster, keyed on that cluster's entity keys. **Extend** an aggregate within its cluster (add a metric or key on the same grain); **split** off a new aggregate when combining clusters would balloon the key cross-product. A portfolio of usage-fit entity-key aggregates beats one monolith.
- **Measure the reduction ratio (it decides splits, not the grain)** — for each candidate aggregate compute the exact row count of its entity-key grain vs the fact → `ratio = fact_rows / aggregate_rows` (how-to in reference.md). A low ratio never means coarsen below entity keys — it means the cluster is too broad, so split it into narrower usage-aligned aggregates. Report the ratio and absolute fact size as the worthwhileness evidence.
- **Pin the delivery target** — decide where the cache table lands and what builds it: `database` + `schema` (target location) and, for Snowflake, the `warehouse` (compute that materializes/refreshes it); Databricks uses `catalog` + `http_path`. Ask the user for these if not obvious; if omitted they fall back to the workspace connection's defaults. See reference.md.

### Phase 6: Validate the design

Prove the design serves its target shapes **before** writing anything: run `get_sql_from_fields(..., debug_aggregates=true)` against the proposed grain/metrics and confirm the report shows the cache **used** (matched or rolled up). Iterate until the intended shapes match, and report the evidence with the recommendation.

---

## Creation Method

Build the validated design as a dynamic dataset (perspective) configured as a cache. **Never write to `prod`.**

1. **Branch** — `create_workspace_branch(workspace_id="...", branch_name="preagg-<descriptor>-<date>")` (the session switches automatically), or switch to an existing dev branch.
2. **Create or extend the perspective:**
   - *New:* `create_object` with `yaml_text` (type `perspective`) — the target `domain`, grain in `attributes`, additive metrics/components in `metrics`, empty `filters`, and the `delivery`/`use_for_cache` block **including the target `database`/`schema` and Snowflake `warehouse` (or Databricks `catalog`/`http_path`)**. Full schema in reference.md.
   - *Extend:* read the existing perspective (`search_model` → `get_field`/model read), add the metric or key, and `update_object` with its `object_key`.

   > **Minimal diff rule:** when extending, preserve the existing field order and formatting — objects are versioned in git, so only change what you must.
3. **Validate** — `validate_object` on the YAML; fix errors. **Always display the returned `ui_url`** so the user can open the object.
4. **Confirm on the branch** — re-run the Phase 6 `debug_aggregates` checks against the branch to confirm the built cache matches its target shapes.
5. **PR** — review with `get_branch_history`, then `create_pr_for_working_branch(title="Pre-aggregate(s) from query-history review — <date>", description="...top shapes, validated acceleration...")`. Display the PR URL.

### After creating: deploy & refresh (the user's step)

A cache **does nothing until its table is built**, and Honeydew only uses it while that table exists. Do not deploy automatically — it touches the warehouse and costs money. Tell the user the deploy path (Honeydew UI "deploy", the Snowflake `DEPLOY_DYNAMIC_DATASET` API, or building from `GET_SQL_FOR_DYNAMIC_DATASET` in your ETL) and a refresh cadence. Note **which compute warehouse runs the build**: the `warehouse` set in `delivery`, or — if you run the deploy API yourself — the executing Snowflake session's warehouse. Caches go stale — the `debug_aggregates` report prints each cache's last-refresh time; flag a large gap as a correctness issue. See reference.md.

---

## Discovery Helpers

- `list_query_history` — the workload source (see the `query-debugging` skill for reading results)
- `search_model` — find existing perspectives/caches, metrics, and entities (`search_mode: EXACT` for known names, `OR` for discovery)
- `get_entity` — an entity's keys, metrics, and relations (to pick grain keys)
- `get_field` — a metric's YAML, to judge additivity and find ratio components
- `get_sql_from_fields` with `debug_aggregates=true` — the coverage gate and design-validation report

---

## Documentation Lookup

Use `search_docs` and `query_docs_filesystem` (from the `honeydew` MCP server) when you need more than reference.md covers — e.g. cache delivery internals, roll-up edge cases, or orchestration. Search for: "aggregate awareness", "pre-aggregation", "dynamic dataset", "use_for_cache", "rollup", "additive metrics", "incremental aggregate updates", "entity caching", "short term aggregate cache".

---

## Best Practices

- **Rank, don't filter.** In v1 the ranking handles noise — a metric-less slicer or a BI indexing scan sinks to ~0 on its own. Only drop no-metric and already-accelerated shapes.
- **Lean on the YAML.** `include_yaml` gives clean `attributes`/`metrics`/`filters`; parse `original_sql` only for BI clients that lack a semantic field list.
- **Prefer entity keys.** One cache keyed on entity keys serves far more queries via roll-up than one keyed on specific attributes.
- **Decompose ratios, don't store them.** Store the additive components; let the ratio compute from rolled-up parts.
- **One aggregate per usage cluster; extend within, split across.** Add a metric to an existing same-grain cache; build a separate aggregate when combining usage clusters would balloon the key cross-product. A few usage-fit aggregates is the intended tradeoff.
- **Some "misses" aren't aggregate problems.** A query that won't accelerate because it filters the fact date instead of the `date` entity is a filtering/context fix — see the `filtering` and `context-item-creation` skills.
- **Always prove it.** Recommend only what a `debug_aggregates` report shows matching — recommendations without that evidence are guesses.
- **Flag staleness.** A cache serving weeks-old data is a correctness problem, not just a speed one.

---

## MANDATORY: Validate the Aggregate

**After building or extending ANY pre-aggregate, you MUST validate it two ways:**

1. **Acceleration** — re-run the Phase 6 `get_sql_from_fields(..., debug_aggregates=true)` checks on the branch and confirm the report shows the cache **used** for each target shape.
2. **Correctness** — invoke the `validation` skill (or run `get_data_from_fields`) to confirm the accelerated result matches the un-accelerated query. A cache that returns wrong or stale numbers is worse than no cache. If they diverge, do not recommend deploying — investigate grain, additivity, or refresh.

---

## Common Pitfalls to Avoid

- **Pulling history wide** — batch ≤25 rows, YAML/SQL off during the scan; `jq`/subagent on saved files.
- **Recommending without proof** — every recommendation must be backed by a `debug_aggregates` "used" report.
- **Caching non-deterministic metrics** (e.g. `SUM(RANDOM())`) — never; results won't reproduce.
- **Putting explicit filters on the cache** — limits what it can serve; use a filtered domain for subsets.
- **Ignoring domain scope** — a cache only serves queries whose domain source-filters match its `domain`; when target shapes span domains, multiply per domain or build in a shared domain.
- **Storing a ratio/average directly** — store additive components and let it recompute.
- **Keying on attributes instead of entity keys** — narrows roll-up coverage; misses composite-key parts.
- **One monolith aggregate holding every entity key** — the key cross-product can approach fact cardinality (poor reduction ratio, little speedup); split into usage-aligned entity-key aggregates.
- **Treating a filter/model mismatch as a new-aggregate need** — route it to `filtering` / `context-item-creation`.
- **Proposing near-duplicate caches** — extend an existing same-grain cache instead.
- **Forgetting deploy/refresh** — a perspective isn't used until its table exists, and a stale table serves old data.
