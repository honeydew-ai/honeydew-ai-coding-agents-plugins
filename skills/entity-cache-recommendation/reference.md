# Entity Caching — Reference

How Honeydew entity caches work, what makes a calculated attribute worth caching, the entity YAML `delivery` schema, deployment/refresh, and how to read cache usage from query history. Read alongside the `entity-cache-recommendation` SKILL.md.

An **entity cache** materializes an entity as a table in the warehouse so its **calculated attributes are computed once, not on every query**. When a query uses a calculated attribute and a valid cache exists for that entity, Honeydew reads the cache instead of recomputing — and pushes applicable filters down into the cache. Caches are **singular and shared across domains and branches**: one cache per entity serves every context.

This is a different lever from aggregate awareness. Aggregate awareness pre-computes **metric aggregations** (a perspective/dynamic dataset). Entity caching pre-computes **per-row calculated attributes** (configured on the entity). Use the one that matches where the cost is.

---

## What makes an attribute worth caching

Only **calculated** attributes benefit — raw passthrough columns recompute for free. An attribute is a strong entity-cache candidate when its SQL involves:

- **Window functions** (`... OVER (PARTITION BY ... )`) — ranks, running totals, lag/lead.
- **Aggregations feeding a per-row value** — e.g. a per-customer lifetime total surfaced as a dimension.
- **JOINs / multi-hop references** to other entities to derive the value.
- **Large table scans**, or **chained calculated attributes** (a calc attribute built on other calc attributes) — multi-step logic that effectively runs ELT at query time.

Docs note window-function and aggregation attributes benefit the most. **Not worth caching:** raw columns, simple arithmetic, cheap `CASE` expressions — the recomputation cost is negligible.

Judge this by reading the attribute's definition with `get_field`. Rank candidates by **usage frequency × warehouse cost**, and group them **by entity** (the cache is enabled per entity, so hot attributes on one entity are cached together).

---

## How caches are matched and used

- **Automatic** — when an entity cache is enabled and its table exists, Honeydew uses it whenever a query references a cached calculated attribute. There is no query-side opt-in.
- **Filter pushdown** — filters that apply to the entity are pushed into the cache scan.
- **Validity** — Honeydew checks the cache table's update time to decide it is usable; a missing table means the cache is simply not used (the query recomputes).
- **Shared & singular** — one cache per entity, shared across all domains and branches. Design it to hold the entity's expensive attributes broadly, not for one workload.

### Reading cache usage from history

The query-history YAML metadata carries `entity_caches_used` alongside `aggregates_used`. Use it as the coverage/validation signal:

- **empty** on runs that use an expensive attribute → the entity is not cached (or the cache isn't valid) → candidate.
- **lists the cache** → already served → not a candidate; if the attribute still seems to recompute, the cache may pre-date the attribute → rebuild/refresh.

There is **no compile-time debug report** for entity caches (unlike `debug_aggregates` for pre-aggregates). Validate candidacy by the attribute's definition (expensive?) + usage evidence before building, and by `entity_caches_used` after deploying.

---

## Entity YAML `delivery` schema

Enable caching by adding a `delivery` block to the **entity** YAML, then `update_object`. Snowflake:

```yaml
type: entity
# ... existing entity configuration (keep field order; minimal diff)
delivery:
  use_for_cache: snowflake
  snowflake:
    enabled: true
    target: table            # table (materialized) — or view
    name: <table_name>       # target table name
    database: <database>     # WHERE the cache table lands (optional)
    schema: <schema>         # WHERE the cache table lands (optional)
    warehouse: <compute_wh>  # virtual warehouse that MATERIALIZES it (optional)
```

- **`target: table`** — materialized; the right choice when the goal is to avoid expensive recomputation.
- **`target: view`** — use only when the goal is simplified access, not avoided compute (a view still recomputes).

### Target location & compute warehouse (do not skip)

Like a pre-aggregate, an entity cache must be told **where the table lives** and **what compute builds it** — decide these per cache; ask the user if they aren't obvious, don't invent names:

- **`database` + `schema`** — where the cache table is created; fully qualifies it. Optional; when omitted, Honeydew uses the **workspace Snowflake connection's default database/schema**.
- **`warehouse`** — the Snowflake **virtual (compute) warehouse** that runs the materialization/refresh. Optional; when omitted, the connection/session warehouse is used. Running `DEPLOY_ENTITY` yourself builds on the **executing Snowflake session's warehouse** unless this override is set.
- **Databricks** uses `catalog` (instead of `database`) and `http_path` (the SQL warehouse / cluster connection) — the same location + compute pair.

---

## Deployment & refresh (user's step — never automatic)

A cache **does nothing until its table is built**, and Honeydew only uses it while the table exists.

- **Deploy:** Honeydew UI "deploy" action; or the Snowflake Native App API
  `SELECT SEMANTIC_LAYER.API.DEPLOY_ENTITY('workspace','branch','entity_name');`
  or build the table from
  `SELECT SEMANTIC_LAYER.API.GET_SQL_FOR_ENTITY('workspace','branch','entity_name');`
  in your ETL.
- **Refresh is external** — a scheduled job or your ETL/orchestrator rebuilds the table (on a trigger or schedule); Honeydew does not refresh it for you.
- **Logic drift (important):** if you refresh **incrementally**, the attribute's SQL may have changed between runs. Confirm the computation hasn't changed before appending, or you will mix logic versions in one table.

### Freshness & refresh timing (crucial)

An entity cache is a materialized table, so it has **freshness latency** — queries read the values from the *last* refresh, not live source data. Because the cache sits in the transformation path, its refresh timing **relative to the upstream ETL** decides correctness:

- **Sequence the refresh after the feeding ETL.** Make the cache rebuild a dependency *downstream* of the ETL that loads its source data — not an independent timer. A cache that refreshes out of sync with the ETL serves **stale** values right after each load.
- **Match freshness to need.** Ask the user how fresh this attribute must be. Slowly-changing dimensions tolerate lag; attributes that must reflect the latest load do not.
- **Target type governs freshness:**
  - **`table`** — no auto-refresh; freshness depends entirely on when your orchestration rebuilds it, so chain it right after the ETL.
  - **`dynamic_table`** — freshness governed by its `lag` setting; tune the lag to the tolerance and confirm it is tight enough given the ETL cadence.

---

## Entity caching vs. the other performance levers

| Lever | Attacks the cost of… | Configured as |
|---|---|---|
| **Entity caching** | recomputing expensive **calculated attributes** (window/agg/join/large scan) | entity `delivery.use_for_cache` |
| **Aggregate awareness** | **aggregating metrics** by repeating groups (dashboards/pivots) | perspective (dynamic dataset) `use_for_cache` |
| **Materialization** | serving a **fully-known dataset** (DS / 3rd-party) | dynamic dataset materialization |
| **Filtering & sampling** | scanning too much in **unpredictable ad-hoc** exploration | query-time filters / sampling |

They compose: an aggregate that groups by an expensive calculated attribute benefits from caching that attribute first, then pre-aggregating. The `performance-tuning` skill routes among these.
