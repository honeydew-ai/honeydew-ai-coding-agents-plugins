---
name: aggregate-awareness
description: Use when queries through the semantic layer are slow and should be accelerated with a pre-aggregation (aggregate awareness), when building or changing a pre-aggregation dynamic dataset, or when a pre-aggregation exists but a query is not using it. For inspecting past query executions use the query-debugging skill; for running queries use the query skill.
---

## Overview

A pre-aggregation is a dynamic dataset whose result is materialized as a table. Once it is built, Honeydew rewrites incoming queries to read from it instead of the raw data, without the user asking for it — that rewrite is called aggregate awareness. One pre-aggregation can serve many different queries, so the goal is always the widest one that stays correct, not one per dashboard.

Reach for this skill on questions like:

- "This dashboard is slow — can we pre-aggregate it?"
- "Build a pre-aggregation for revenue by month and region."
- "I built a pre-aggregation but the query still scans the fact table."
- "Why isn't my aggregate being used?"

Honeydew decides whether a pre-aggregation can answer a query; you cannot force it. So the work is: make the pre-aggregation *matchable*, then verify it actually matched.

## Prerequisites

Queries run against the workspace and branch set for the current session. Use `get_session_workspace_and_branch` to check the current context. If no workspace/branch is set, use `list_workspaces`, `list_workspace_branches`, and `set_session_workspace_and_branch` to select one. See the `workspace-branch` skill for the full workspace/branch tool reference.

Create and change pre-aggregations on a working branch, not on the main branch.

## Step 1 — Decide what to accelerate

Do not guess at the workload. Use `list_query_history` (see the `query-debugging` skill) to find what actually runs: which groups and metrics repeat, from which client, and how often. Build for the repeating shape.

Prefer one pre-aggregation that many queries can roll up from over several narrow ones.

## Step 2 — Make it matchable

These decisions determine whether the pre-aggregation will ever be used. Get them wrong and it will sit there, built and ignored.

| Decision | Why |
| --- | --- |
| Use additive metrics (`SUM`, `COUNT`, `MIN`, `MAX`) | Only additive metrics can roll up. A pre-aggregation by day can then serve month and year; a non-additive metric like a ratio or a distinct count can only serve its exact grain. |
| Group by entity keys where you can | A query grouping by any attribute of that entity can still be served, because Honeydew joins from the key. Grouping by a display attribute serves only that attribute. |
| Avoid filters on the data | Every filter narrows which queries can use it — a query must have the same filter. To accelerate a subset, build the pre-aggregation in a filtered `domain` instead (see the `domain-creation` skill). |
| Keep the grain no finer than the queries need | A finer grain means a bigger table with no extra queries served. |
| Never pre-aggregate non-deterministic metrics | A metric over something like `RANDOM()` returns different results from the table than from the raw data. |

## Step 3 — Create it

A pre-aggregation is a dynamic dataset (`type: perspective`) with cache delivery settings. Create it with `create_object` (validate first with `validate_object`), then show the `ui_url` from the response. The example below is for Snowflake:

```yaml
type: perspective
name: revenue_by_month_and_region
attributes:
  - date.month
  - regions.region_id
metrics:
  - order_lines.revenue
delivery:
  # enable Snowflake as preaggregate cache
  use_for_cache: snowflake
  # Snowflake delivery settings (where the cache table resides)
  snowflake:
    enabled: true
    name: <name of table>
    schema: <name of schema>
    target: table
```

Building and refreshing the table itself is not an MCP operation — it happens through the Honeydew UI deploy action, the deploy API, or an orchestrator such as dbt or ETL code. Until the table is built, the pre-aggregation cannot serve queries, and the report in step 4 says so.

## Step 4 — Verify it is actually used

Never assume a pre-aggregation matched. Ask for the report: call `get_sql_from_fields` with `debug_aggregates: true` and the fields of the query you want accelerated. Honeydew puts a report at the top of the generated SQL saying what it did with every pre-aggregation in the workspace.

The report puts each pre-aggregation in exactly one section, ordered by how close it came to being used:

| Section | Meaning | What to do |
| --- | --- | --- |
| `Match detail by CTE` | Per CTE of the query, per metric: `matched <name>` or `no matches`, and for each pre-aggregation that did not match, why | Nothing, if your pre-aggregation says `matched`. Otherwise read its reason below. |
| `Not ready to use` | The table has not been built, or the model changed since it was built | Rebuild or refresh it. A reason ending `it would otherwise have matched ...` means this is the only thing standing in the way. |
| `Ready, but not applicable to this query` | A query-level mismatch: a different domain, different source filters, different domain parameters, or a limitation such as a time metric | Run the query in the pre-aggregation's domain, or build the pre-aggregation in the domain the query uses. |
| `Ready, but none of this query's metrics are in them` | It contains none of the metrics the query asks for | Add the metrics that need acceleration. |

Reasons under a CTE point at a specific fix:

- `does not contain this metric` — add that metric to the pre-aggregation.
- `cannot roll up: has neither group <group> nor the key of entity <entity>` — add that group, preferring the entity key.
- `cannot roll up: group <group> comes from entity <entity>, which is in a fan-out` — the query's joins make a roll-up from this pre-aggregation unsafe; a pre-aggregation at the query's own grain is needed.
- `has filters the query does not have` — the filter you baked in is the problem; see step 2.
- `groups don't match the query's, and matching on groups alone is exact` — a query with no metrics matches only a pre-aggregation with exactly the same groups.
- `matched, but <name> was preferred` — it would have worked; another pre-aggregation was chosen.
- `No pre-aggregation was used: ...` on its own line — the query shape never reached matching at all, and the line says which shape (for example a query with no metrics that does not set `group_by_all`).

A report line naming `<name> (short term cache of a previous query)` is Honeydew's automatic short-term caching, not a pre-aggregation you manage.

Once the report shows `matched`, confirm the numbers are unchanged: run the query with `get_data_from_fields` and compare against the same query with `use_cache: no`.

## Common Mistakes

- **Assuming it worked because it exists.** A built pre-aggregation that matches nothing is pure cost. Always check the report.
- **Baking a filter in.** It feels efficient and it silently disqualifies every query that does not carry the same filter. Use a filtered domain.
- **Grouping by display attributes instead of keys.** Serves one query instead of many.
- **Building one pre-aggregation per dashboard.** Additive metrics on entity keys let a single one serve the whole workload.
- **Pre-aggregating a ratio.** Ratios and distinct counts do not roll up; pre-aggregate their additive components instead and let the ratio compute on top.

## MANDATORY: Validate After Creating

**After creating ANY pre-aggregation, you MUST invoke the `validation` skill to test and validate that it works correctly.**

See `validation` skill for the full validation workflow.

### Validation steps:

1. **Verify the dynamic dataset exists** using `search_model` (with `search_mode: EXACT`) to find it by name.
2. **Check for errors** on the returned object before going further.
3. **Confirm it compiles** with `get_sql_from_fields` on the pre-aggregation's own fields.
4. **Confirm it is used** with `debug_aggregates: true` on a query it is meant to accelerate, as in step 4.
5. **Confirm results are unchanged** against the same query with `use_cache: no`.
