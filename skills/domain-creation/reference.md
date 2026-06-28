# Domain Reference

## Full YAML Schema

```yaml
type: domain
name: <snake_case_name>
display_name: <Human Readable Name>
description: |-
  <business description — include purpose and intended audience>
owner: <owner_email_or_team>
labels: []
extends:                      # optional — inherit from one or more parent domains
  - <parent_domain_name>
entities:
  - name: <entity_name>
    fields:                   # optional — omit to include all fields
      - <field_selector>
      - ...
filters:                      # optional — semantic filters on every query
  - name: <filter_name>
    sql: <entity.field expression>
    display_name: <optional display name>
    description: <optional description>
source_filters:               # optional — source-level filters
  - name: <filter_name>
    sql: <entity.field expression>
    display_name: <optional display name>
    description: <optional description>
parameters:                   # optional — override global parameter defaults
  - name: <global_parameter_name>
    value: <value>
```

## Entity Selection

Each entry in the `entities` list specifies an entity to include in the domain using the `name` field:

```yaml
entities:
  - name: orders
  - name: customers
  - name: products
```

Omitting an entity from the list makes it invisible within the domain. All entities needed for joins should be included.

## Field Selectors

The `fields` list controls which attributes and metrics are visible for an entity within the domain. If omitted, all fields are visible. Selectors are string patterns evaluated **in the order they are listed** — the last matching selector determines inclusion.

**Selector syntax:**

| Pattern | Meaning |
|---------|---------|
| `*` | Include all fields |
| `field_name` | Include a specific field |
| `-field_name` | Exclude a specific field |
| `pattern*`, `*pattern`, `*mid*` | Include fields matching wildcard |
| `-pattern*`, `-*pattern`, `-*mid*` | Exclude fields matching wildcard |

**Examples:**

```yaml
entities:
  # Include all fields (default behavior)
  - name: customers

  # Include only specific fields
  - name: orders
    fields:
      - order_id
      - order_date
      - order_total

  # Include all fields except specific ones
  - name: employees
    fields:
      - "*"
      - -salary
      - -ssn

  # Include fields matching a pattern
  - name: products
    fields:
      - product_*

  # Complex: all fields, exclude internal, re-include one
  - name: transactions
    fields:
      - "*"
      - -internal_*
      - internal_status
```

> **Important:** Never exclude key columns or foreign key columns — this breaks joins and queries. Always keep them visible.

## Filters

Domains support two types of filters. Both use structured objects with `name` and `sql` fields.

### Semantic Filters (`filters`)

Semantic filters apply to **every query** in the domain, regardless of which entities the query references. They may introduce additional JOINs.

```yaml
filters:
  - name: ground_shipping
    sql: lineitem.l_shipmode in ('MAIL', 'RAIL', 'TRUCK')
    display_name: Ground Shipping Only
    description: Only include shipments via ground transportation
```

**Use semantic filters for:** governance rules, access control, tenant isolation, business logic that must always apply.

**Caveat:** Semantic filters can slow queries by introducing extra JOINs. For example, a filter on `lineitem.shipmode` will cause a JOIN to `lineitem` even in queries that don't otherwise reference it.


### Source Filters (`source_filters`)

Source filters are applied **early, at the source level** — only when the source entity is actually part of the query. They do not introduce extra JOINs.

```yaml
source_filters:
  - name: recent_shipments
    sql: lineitem.l_shipdate >= '1994-01-01' and lineitem.l_shipdate < '1995-01-01'
```

**Use source filters for:** performance optimization on partitioned data, removing duplicate data, conditional filtering.

> **Caution:** Source filters apply before any computation, which can change the values of calculated attributes. When in doubt, use a semantic filter instead.

### Choosing Between Filter Types

| Aspect | Semantic (`filters`) | Source (`source_filters`) |
|--------|---------------------|--------------------------|
| **Scope** | Every query in the domain | Only when source entity is queried |
| **Timing** | After semantic resolution, may add JOINs | Early, directly on source tables |
| **Purpose** | Governance & access control | Performance optimization, deduplication |
| **Caveats** | Can slow queries via extra JOINs | May alter computed values |
| **Best use** | Consistent rules (tenant, access filters) | Large/partitioned data |

### Filter SQL Syntax

Both filter types use the same expression syntax in the `sql` field. All field references must be fully qualified (`entity.field`).

See the `filtering` skill for the full filter expression reference, including comparisons, IN lists, pattern matching, date filters, NULL checks, and combining conditions.

## Domain Hierarchy (Inheritance)

> **Beta:** Domain hierarchy is a Beta feature and may require activation for the account (contact Honeydew support).

A domain extends one or more parents with the `extends` field. The child inherits the parents' configuration and overrides only what it redefines.

```yaml
type: domain
name: child_domain
extends:
  - parent_domain
```

### What gets inherited

From each parent, a child inherits:

- All **entities** and their field selections
- All **filters** (semantic) and **source_filters**
- All **parameters**
- All **tags**
- All **labels** (additive)
- All **metadata** sections

### Merge rules

List items are matched by `name` (tags by `key`; metadata sections by `name`, then items within by `key`). When the child defines an item that already exists in a parent:

| Item kind | Behavior when child redefines it |
|-----------|----------------------------------|
| Scalar fields (e.g. filter `sql`) | **Replaced** by the child's value |
| Collection fields (e.g. entity `fields`) | **Extended** — child selectors apply on top of the inherited list |
| `labels` | **Additive** — child labels appended to parent labels |
| `tags` (by `key`) | Same key **replaces**; new keys are **added** |
| `metadata` items (by `key`) | Same key **overrides**; new keys are **added** |

### Field inheritance

Child field selectors apply on top of the inherited field list:

```yaml
# Parent
entities:
  - name: customers
    fields: ["*"]
  - name: orders
    fields: [order_id, order_date, order_status]

# Child
entities:
  - name: customers
    fields: ["-ssn", "-salary"]   # remove from inherited (all-except)
  - name: orders
    fields: [order_total]         # add to inherited

# Result:
#   customers: all fields except ssn, salary
#   orders:    [order_id, order_date, order_status, order_total]
```

If the parent uses `fields: ["*"]`, the child already inherits all fields. To restrict to a specific subset, reset with `-*` first, then list the fields to keep:

```yaml
entities:
  - name: customers
    fields: ["-*", id, name, email]   # only these three
```

### Removing inherited items

Use `merge: remove` to drop an item inherited from a parent. Works for `entities`, `filters`, `source_filters`, `parameters`, and `tags`:

```yaml
entities:
  - name: sensitive_entity
    merge: remove
filters:
  - name: legacy_filter
    merge: remove
parameters:
  - name: OLD_PARAM
    merge: remove
tags:
  - key: deprecated_tag
    merge: remove
```

### Multiple inheritance

List several parents under `extends`. **Parents are evaluated left-to-right: if multiple parents define the same item, the rightmost parent wins.** The child then overrides all parents. This supports a mixin pattern — compose a base data model with separate security and performance mixins:

```yaml
extends:
  - base_sales          # data model
  - security_mixin      # governance filters
  - performance_mixin   # source filters
```
