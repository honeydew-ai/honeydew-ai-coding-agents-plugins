---
name: performance-tuning
description: Use as the front door for Honeydew performance work when the user wants to make the model or queries faster but hasn't chosen an approach — diagnoses where a slow/costly workload spends its time from query history and routes to the right lever (aggregate awareness, entity caching, materialization, or filtering/sampling). Triggers on "make my queries/model faster", "why is this slow and what should I do", "performance review", "which performance approach should I use", "aggregate awareness vs entity cache", "speed up Honeydew". For building a specific lever use aggregate-recommendation or entity-cache-recommendation directly.
---

## Prerequisites

Ensure a workspace and branch are set — `get_session_workspace_and_branch`, else `list_workspaces` + `set_session_workspace_and_branch` (see the `workspace-branch` skill). Read the model on `prod`. This skill **diagnoses and routes**; the lever skills it hands off to make the changes on a branch.

Query history is scoped to the session's workspace. Non-admin callers see only their own queries.

---

## Overview

Honeydew offers several performance levers, each aimed at a different cost. Picking the wrong one wastes effort, so this skill **diagnoses where a workload spends its time and routes to the right lever** — it does not build anything itself.

**Your job is to classify the bottleneck, then hand off.** Reach for this skill when the user asks generally to speed things up, wants a performance review, or is unsure whether they need aggregate awareness or entity caching. If the user has already chosen a lever, skip straight to that skill.

The levers (from the Honeydew performance docs):

| Workload | Queries | Lever | Skill / doc |
|---|---|---|---|
| Dynamic dashboards & BI — aggregating metrics by repeating groups | Predictable | **Aggregate awareness** | `aggregate-recommendation` |
| Expensive **calculated attributes** (window/aggregation/JOIN/large scan) recomputed often | Predictable | **Entity caching** | `entity-cache-recommendation` |
| Fully-known dataset for data science / 3rd-party | Known | **Materialization** | docs: dynamic-datasets materialization |
| Ad-hoc exploration over large data | Unpredictable | **Filtering & sampling** | docs: performance/filtering-and-sampling |

Honeydew also auto-optimizes every query (filter pushdown, join pruning) — so before recommending a lever, confirm the cost is real and structural, not a missing filter.

---

## Diagnosis Workflow

### Phase 1: Scope the problem

Anchor on what's slow: a specific query the user names, a dashboard/client, a domain, or "the model in general." If a specific run is named, pull it (`list_query_history`, then `include_yaml`/`include_sql` on that run — see `query-debugging`). Otherwise sample recent history.

### Phase 2: Pull the signal (token discipline)

Use `list_query_history` in **batches of ≤25**, `include_yaml`/`include_sql` off for the scan; `jq`/subagent on any saved oversized file. For each real run (ignore `FAILED`/`RUNNING`/`CANCELED`/compile-only) capture: warehouse cost (`dwh_end_at − compile_end_at`), `accelerated`, and — from YAML metadata on representatives — `aggregates_used` and `entity_caches_used`, plus the `metrics` and `attributes` used.

### Phase 3: Classify the bottleneck

Read where the cost is and route:

| Signal in the costly runs | Bottleneck | Route to |
|---|---|---|
| Metric aggregations (`SUM`/`COUNT`/…) over a large fact, repeating groups/metrics, `aggregates_used` empty | Aggregating a fact | **`aggregate-recommendation`** |
| Expensive **calculated attributes** (window/aggregation/JOIN/large scan) referenced often, `entity_caches_used` empty | Recomputing a dimension | **`entity-cache-recommendation`** |
| Both — an aggregate that groups by an expensive calculated attribute | Compound | Cache the attribute first (**entity-cache**), then pre-aggregate (**aggregate**) |
| Unpredictable ad-hoc scans, no repeating shape | Over-scanning | Filtering & sampling (docs) |
| A single fully-known dataset consumed as-is | Serving a dataset | Materialization (docs) |
| Missing/ineffective filter; small data | Not structural | Fix the query first (`filtering` skill) — no cache needed |

Distinguish the two main levers by **where the SQL cost lives**: aggregation of measures → aggregate awareness; computation of a per-row calculated attribute → entity caching. Inspect a metric with `get_field` (additive? big fact?) and an attribute with `get_field` (window/agg/join?) when unsure.

### Phase 4: Recommend and hand off

Summarize: the costly workloads, the diagnosed bottleneck per workload, and the recommended lever with a one-line reason. Then invoke the target skill(s) to design/build on a branch. For compound cases, sequence entity-cache before aggregate. For the docs-only levers (materialization, filtering/sampling), point the user to the doc and outline the change rather than building it here.

When routing to **entity caching**, flag freshness up front: the cache is a materialized table with latency, so its refresh must be sequenced after the upstream ETL or queries read stale data — the `entity-cache-recommendation` skill walks the user through this.

When routing to **aggregate awareness**, expect **usage-aligned, entity-key-grained** caches: one aggregate per usage cluster, split when a combined grain's reduction ratio is poor — not one monolith. The `aggregate-recommendation` skill measures the ratio and decides the splits.

---

## Discovery Helpers

- `list_query_history` — the workload source; YAML metadata exposes `aggregates_used` and `entity_caches_used` (see `query-debugging`)
- `get_field` — inspect a metric (additivity, fact size) or a calculated attribute (window/agg/join) to classify the cost
- `get_entity` — entity keys, attributes, and current cache `delivery` config
- `search_model` — find existing perspectives (pre-aggregates) and entities

---

## Documentation Lookup

Use `search_docs` / `query_docs_filesystem` (from the `honeydew` MCP server). Topics: "performance overview", "aggregate awareness", "entity caching", "filtering and sampling", "dataset materialization", "order of computation", "join pruning".

---

## Best Practices

- **Diagnose before prescribing.** Confirm the cost is structural (big scan / heavy compute), not a missing filter — Honeydew already pushes filters down and prunes joins.
- **Match the lever to the cost.** Aggregating metrics → aggregate awareness; recomputing a calculated attribute → entity caching. Don't reach for a cache when a query fix suffices.
- **Sequence compound cases.** Cache an expensive attribute first, then pre-aggregate over it.
- **Hand off, don't reimplement.** This skill routes; the lever skills own the build, validation, and branch/PR.
- **Say what you're not covering.** If you route to a docs-only lever (materialization, filtering/sampling), say so explicitly rather than silently narrowing.

---

## Related Skills

- `aggregate-recommendation` — build/extend pre-aggregate caches (aggregate awareness lever)
- `entity-cache-recommendation` — cache expensive calculated attributes (entity caching lever)
- `query-debugging` — read query history and inspect a run's semantics/SQL
- `filtering` — fix an over-scanning or mis-filtered query before caching
