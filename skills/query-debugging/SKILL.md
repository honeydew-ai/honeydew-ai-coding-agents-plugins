---
name: query-debugging
description: Use when the user wants to review or inspect past query executions in Honeydew — what ran, from which client (BI tools, SQL interface, MCP, deep analysis), the semantic definition or compiled SQL behind a run, who ran it and when — and to debug failures. Uses the list_query_history MCP tool. For running new queries or analysis use the query skill.
---

## Overview

Honeydew records every query executed through the semantic layer — MCP tools, BI tools over the SQL/XMLA interfaces (Tableau, Power BI, …), scheduled jobs, and deep analysis. Use `list_query_history` (from the `honeydew` MCP server) to see **what ran, who ran it, from which client, and how**, and to drill into any run's semantic definition or compiled SQL. Debugging failures is one use, not the only one.

Reach for this skill on questions like:

- "What ran against this domain today, and from which clients?"
- "Which BI tool queried this model, and what did it send?"
- "Show me the queries my last deep analysis generated."
- "Why did my query fail? Show me its SQL."

For running a *new* query, use the **query** skill. This skill inspects queries that already ran.

The tool's description and parameter schema cover the exact arguments and response fields; this skill covers what they can't — **when to reach for it, how to read the results, and the workflows.**

---

## Prerequisites

Query history is scoped to the session's workspace — check with `get_session_workspace_and_branch`, and set one via the **workspace-branch** skill if needed. Non-admin callers see only their own queries; admins see all and can filter by `user_in`.

---

## Reading the Results

- **client** — where the query came from (`Tableau`, `Power BI`, `MCP`, …); how you tell a dashboard's query from an MCP or deep-analysis run.
- **original SQL vs. compiled SQL** — SQL-interface clients (Tableau, Power BI) carry the *original* SQL the client sent, before compilation; the *compiled* warehouse SQL comes from `include_sql`. Clients that submit a semantic field list (MCP, deep analysis) have no original SQL.
- **semantic definition** — `include_yaml` returns the attributes/metrics/filters the run resolved to — what you reproduce or alter a query from.
- **app link** — always **show it** so the user can open the query in Honeydew.

Keep `include_yaml` / `include_sql` off for the initial scan; enable them only on the run you're drilling into. **Deep analysis lands here too** — each `initiate_analysis` step runs semantic-layer queries, so this is where you inspect what an analysis actually computed per step.

---

## Workflows

**Review / audit:** list the relevant slice (by domain, client, user, or time window) and read `client`, `owner`, status, and timestamps. Add `include_yaml` / `include_sql` on a specific run to reproduce or explain it.

**Debug a failure:** list with `status_in="FAILED"`, read the error message, then re-list that query with `include_yaml=true` to see the fields that failed (add `include_sql=true` for warehouse-side errors — permissions, missing table). Reproduce with `get_data_from_fields` from the YAML and fix (see the **query** and **filtering** skills), then report what failed, the app link, and the fix.

**Isolate an internal error (minimal reproduction):** when the error is generic ("internal error"/compilation crash) and names no field, bisect:

1. Pull the failed query's YAML (`include_yaml=true`) and rebuild it verbatim as an ad-hoc `get_data_from_fields` call. Confirm it still errors — if not, the cause is environmental (branch, data, transient), not the query.
2. Drop attributes/metrics/filters and re-run, halving the field set each round; keep whichever half still errors.
3. Converge to the smallest failing query. The field whose removal clears the error — or the minimal combination that only fails together — is the culprit.
4. Report that minimal field list plus its compiled SQL — far more actionable than the original wide query.

Use `get_sql_from_fields` between rounds to watch the offending SQL fragment appear or disappear with the culprit field.
