# Aggregate Awareness — Reference

How Honeydew matches queries to pre-aggregate caches, how to design one, the perspective YAML schema, and deployment. Read alongside the `aggregate-recommendation` SKILL.md.

A pre-aggregate cache is a **dynamic dataset (perspective)** whose result is materialized as a table in the warehouse. When a query's groups, filters, join paths, and aggregations can be satisfied from that table, Honeydew reads it instead of re-scanning the fact — often orders of magnitude faster on large data.

---

## How matching works

Honeydew verifies **groups, filters, and join paths** before deciding a pre-agg can serve a query.

### Groups

- **Roll-up (additive metrics).** If the metric is additive, the cache matches when the query's groups can be computed by rolling up from the cache's groups. A cache for `revenue` by `year, city` serves `revenue` by `city`, by `year`, or grand total.
- **Exact match (non-additive metrics).** `COUNT(DISTINCT)`-style metrics match **only** when the query's groups are exactly the cache's groups. `revenue` distinct-count by `year, city` will **not** serve a query by `city` alone.
- **Entity-key grain (the big lever).** A cache grouped on an **entity key** serves queries grouped by **any attribute of that entity**, via roll-up. A cache of `revenue` by `customer.id` serves `revenue` by `customer.name`, by `customer.name, customer.age`, or total. For a **composite key, all key parts must be in the cache**. Always prefer entity keys over specific attributes — one cache then covers a whole family of queries.

### Filters

- A cache matches only when **its filters match the query fully**. A cache built for `year = 2023` serves only queries also filtered to `year = 2023`.
- A query may add **further filters on groups that exist in the cache** (e.g. cache by `year, city`; query filters `year = 2023 AND city = 'Seattle'`).
- A filter on a field **not present in the cache's grain blocks the match.** Common real failure: filtering the fact's own date (`order_header.order_date`) when the cache is grouped on the `date` entity (`date.date`). The debug report says: *"the query filter … needs an attribute the aggregate does not group by."* Fix by filtering through the `date` entity (`date.year`, `date.date`) — a filtering/context fix, not a new aggregate.

### Domains

A pre-agg matches a query only when the **source filters of the query's domain and the cache's domain are the same**. Queries run in the same domain as the cache always match its source filters. Use this to build caches for a subset of data: put the cache in a filtered domain, and every query in that domain uses it.

**Design implication (a cache is scoped to its domain).** If the target query shapes run across **multiple domains with different source filters**, one cache will not serve them all. Two options:

1. **Multiply the dataset** — build one cache per domain (same grain/metrics, different `domain`). Simple, but N caches to deploy and refresh.
2. **Build in a shared domain** — put the cache in a parent / no-source-filter domain that the target queries inherit from, so a single cache serves all of them.

Group candidate shapes by domain in design (Phase 5) and pick one of these per group. Note the asymmetry with **entity caches**, which are singular and shared across all domains — the domain decision applies to aggregates only.

---

## Additivity & decomposition

| Metric kind | Additive? | In a pre-agg |
|---|---|---|
| `SUM`, `COUNT`, `MIN`, `MAX` (and simple derivatives) | Yes (auto-detected) | Store directly; rolls up |
| Ratio / average / margin | No, **but decomposable** | Store the **additive components**; ratio recomputes from rolled-up parts |
| `COUNT(DISTINCT)` | No | Exact-grain match only; or use an approximate-distinct metric |
| Non-deterministic (`SUM(RANDOM())`) | No | **Never** pre-aggregate |

**Decomposition is the key modeling move.** A non-additive metric that is built from additive metrics rolls up if its components are in the cache:

- `average = SUM(x) / COUNT(x)` → put the sum metric and the count metric in the cache.
- `profit_margin = profit / revenue` → put `profit` (or its `revenue` and `cost` components) and `revenue` in the cache.

Honeydew computes the ratio from the rolled-up components, so one cache serves the ratio at every grain. This is why you **store components, not ratios**.

**Configuring additivity.** Honeydew auto-detects simple additive metrics. For complex metrics that are additive but not detected, set the `rollup` property on the metric:

```yaml
type: metric
# ... metric definition
rollup: sum        # sum | min | max | hll (approx-distinct, coming soon) | no_rollup
```

Inspect a metric's definition with `get_field` to decide additivity. If a ratio's components are ambiguous, ask the user rather than guessing.

---

## Design checklist

1. **Grain = entity keys** of every entity the target shapes group by (full composite keys). Not specific attributes.
2. **Metrics = additive metrics + decomposed components** covering every target shape's measures.
3. **No explicit filters.** For a data subset, build the cache in a **filtered domain** instead.
4. **One aggregate per usage cluster.** Extend within a cluster (same grain + missing metric); split into a separate aggregate when combining clusters would balloon the key cross-product.
5. **Measure the reduction ratio** = `fact_rows / distinct entity-key tuples` (exact count, pre-deploy). Use it to decide how far to split — a low ratio means split the cluster, never coarsen below entity keys.
6. **Never** cache non-deterministic metrics.

---

## Reduction ratio & splitting by usage

Aggregate benefit is bounded by the **row-reduction ratio** — `ratio = fact_rows / aggregate_rows`. The higher the ratio, the more scanning the cache saves; a ratio near 1 (the aggregate is nearly as large as the fact) means little speedup for the storage + refresh cost.

**Measure it exactly, before deploying** (no need to build the table):

- **Fact rows** — the fact entity's count metric with no grouping (e.g. `order_detail.count`).
- **Aggregate rows** — the number of distinct entity-key tuples at the candidate grain: run a `COUNT(DISTINCT key1 || '|' || key2 || …)` over the fact (one number). That is exactly how many rows the cache will have.
- **ratio = fact_rows / aggregate_rows.** Also note the **absolute** fact size — a big ratio only matters when the fact is large enough that scan time dominates.

**The grain is always entity keys — the ratio decides how to *split*, not whether to coarsen.** A single aggregate keyed on *every* entity key (date × product × location × customer …) can have a cross-product approaching fact cardinality → poor ratio → not worth it. The fix is **not** attribute-level grain; it is to **split into multiple aggregates aligned to actual usage**, each keyed on the entity keys of one usage cluster:

- Cluster the target query shapes by *which entities they group by*.
- Build one entity-key aggregate per cluster (e.g. `menu × date`, `location × date`, `customer × date` as separate caches).
- Each is smaller, keeps a healthy ratio, still rolls up to any attribute of its entities, and matches real demand.
- The tradeoff — more caches to deploy and refresh — is intended and worth it.

High-cardinality keys (customer, order / order-line) are the usual reason a combined aggregate's ratio collapses; isolating them into their own usage-aligned cache keeps the others lean.

---

## Perspective (pre-aggregate) YAML

Create with `create_object` (`yaml_text`), validate with `validate_object`. Type is `perspective`. Example modeled on a working cache:

```yaml
type: perspective
name: preagg_orders_core
domain: analytics               # cache is SCOPED to this domain — must match the target queries' domain
# Grain: entity keys so any attribute of these entities rolls up
attributes:
  - date.date
  - menu.menu_item_id
  - location.location_id
  - customer_loyalty.customer_id
# Additive metrics + components for any ratios (e.g. revenue & cost → margin)
metrics:
  - order_detail.revenue
  - order_detail.order_cost
  - order_detail.profit
  - order_detail.count
  - order_detail.sum_quantity
# No explicit filters — keep the cache broadly usable
filters: []
# Cache delivery (Snowflake shown)
delivery:
  use_for_cache: snowflake
  snowflake:
    enabled: true
    target: table                 # table | view | dynamic_table | interactive_table
    name: preagg_orders_core      # target table name
    database: <target_database>   # WHERE the cache table lands (optional)
    schema: <target_schema>       # WHERE the cache table lands (optional)
    warehouse: <compute_wh>       # virtual warehouse that MATERIALIZES it (optional)
```

### Target location & compute warehouse (do not skip)

A cache table has to be told **where to live** and **what compute builds it**. These are separate from the semantic definition and must be decided per cache — ask the user if they aren't obvious, don't invent names:

- **`database` + `schema`** — where the cache table is created. Fully qualifies the table (e.g. `bi.dev.preagg_orders_core`). Optional in YAML; when omitted, Honeydew uses the **workspace Snowflake connection's default database/schema**.
- **`warehouse`** — the Snowflake **virtual (compute) warehouse** that runs the materialization/refresh. Optional; when omitted, the connection/session warehouse is used. When you run the deploy API (`DEPLOY_DYNAMIC_DATASET`) yourself, the build runs on the **executing Snowflake session's warehouse** unless this override is set.
- **`initialization_warehouse`** (under `dynamic_table_settings`, dynamic tables only) — a larger warehouse used **only** for building/rebuilding from scratch, so incremental refreshes don't pay for it. Defaults to the delivery `warehouse`.

**Databricks** uses `catalog` (instead of `database`) and `http_path` (the SQL warehouse / cluster connection — the Databricks equivalent of the compute warehouse):

```yaml
delivery:
  use_for_cache: databricks
  databricks:
    enabled: true
    target: table
    name: preagg_orders_core
    catalog: <target_catalog>     # optional
    schema: <target_schema>       # optional
    http_path: <sql_warehouse_http_path>   # compute connection (optional)
```

For a **filtered-domain** cache, define the perspective inside the domain (see the **domain-creation** skill); the domain's filters apply to both the cache and the queries it serves — do not put the filter in the perspective's `filters`.

---

## Deployment & refresh (user's step — never automatic)

A perspective configured as a cache is **not used until its table exists** in the warehouse.

- **Deploy:** Honeydew UI "deploy" action; or Snowflake Native App API
  `SELECT SEMANTIC_LAYER.API.DEPLOY_DYNAMIC_DATASET('workspace','branch','dataset_name');`
  or build the table from
  `SELECT SEMANTIC_LAYER.API.GET_SQL_FOR_DYNAMIC_DATASET('workspace','branch','dataset_name');`
  in your ETL.
- **Validity:** Honeydew checks the table's update time to decide the cache is usable.
- **Refresh:** caches go stale. The `debug_aggregates` report prints each cache's last-refresh timestamp and the gap before compilation — surface a large gap as a correctness issue. Periodic refresh needs an external orchestrator (scheduled job). Short-term automatic aggregate caching for live pivot/slice-and-dice workloads can be enabled per domain (`short_term_aggregate_cache_ttl_seconds`, Beta — contact support@honeydew.ai).

---

## Reading the `debug_aggregates` report

`get_sql_from_fields(..., debug_aggregates=true)` prepends a `# Pre-aggregation report` to the SQL. Use it in two places: the **coverage gate** (does an existing cache already serve this candidate?) and **design validation** (does my proposed cache serve the target shapes?). The four outcomes, with real report text and how to classify each:

### Used — the cache matched (classification: *already covered*, or a validated design)

```
# Pre-aggregation report (1 pre-aggregation: 1 used)
### aggregate_preagg_demo_18
Groups: menu.item_category
- order_detail.revenue: matched preagg_demo
```

The cache is keyed on entity keys (`menu.menu_item_id`, `date.date`, …), so grouping by `menu.item_category` and filtering by `date.year` both roll up. In the coverage gate this means **no action — report it as covered**. In design validation it means the design **works** — proceed to build.

### Rejected on filter (classification: *model / context fix — not a new aggregate*)

Same metric and grain, but filtered on the fact's own date instead of the `date` entity:

```
# Pre-aggregation report (1 pre-aggregation: 1 rejected per CTE)
### metrics_order_detail_13
- order_detail.revenue: no matches
  * preagg_demo: the query filter order_header.order_date <= '2021-12-31'
    needs an attribute the aggregate does not group by
```

The cache is fine; the query filters a field it isn't grouped by. **Do not build a new aggregate** — fix the query to filter through the `date` entity (`date.year`/`date.date`), or add a context instruction preferring `date.*` filters. Route to the `filtering` / `context-item-creation` skills.

### No relevant metrics (classification: *new or extended cache*)

```
# Pre-aggregation report (1 pre-aggregation: 1 with no relevant metrics)
## Ready, but contain none of this query's metrics (order_header.count)
- preagg_demo
```

The cache is ready but carries none of the query's metrics — here `order_header.count` lives on the `order_header` entity (order grain) while `preagg_demo` holds `order_detail`-grain metrics. Different grain → build a **new** order-grain cache. If the missing metric were on the *same* grain as an existing cache, **extend** that cache instead.

### Non-additive but decomposed (classification: *served from components*)

```
# Pre-aggregation report (1 pre-aggregation: 1 used)
### aggregate_preagg_demo_16
- order_detail.order_cost, order_detail.revenue: matched preagg_demo
### metrics_order_detail_22
- order_detail.profit: no matches
  * preagg_demo: ... this metric is not additive, so it cannot be rolled up
```

`profit` shows "no matches" as a stored metric, yet the compiled SQL derives it as `SUM(revenue) − SUM(order_cost)` **from the cache** — no fact scan. Lesson: don't store the ratio/derived metric; store its additive **components** and let it recompute from rolled-up parts. This still counts as accelerated.
