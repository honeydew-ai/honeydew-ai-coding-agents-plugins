---
name: relation-creation
description: Guides you through defining a relationship between two Honeydew entities — covering join type, direction, cross-filtering, and connection method — then pushes the updated entity YAML to Honeydew via the MCP tools.
---

## Prerequisites

Before creating relations, ensure you are on the correct workspace and branch. Use `get_session_workspace_and_branch` to check the current session context. For development work, create a branch with `create_workspace_branch` (the session switches automatically). See the `workspace-branch` skill for the full workspace/branch tool reference.

---

## Overview

A Honeydew **relation** defines how two entities join together.
Relations are not standalone objects — they live inside the **source entity's YAML** as a `relations:` block.
Every relation connects the "many" side to the "one" side: for example, `orders` (many) → `customers` (one).

Relations enable:

- Metrics on one entity to reference attributes from another
- Cross-entity calculated attributes (Multi-Entity type)
- Filter propagation between entities in BI queries

> Relations are defined on the source entity. To add a relation, use `update_object` on the entity that holds the foreign key (the "many" side).

---

## Creation Methods

### Primary: update_object on the Source Entity

There is no `create_relation` tool. Adding a relation means updating the source entity's YAML to include the `relations:` block.

Call `update_object` with:

- `yaml_text` — the full updated entity YAML with the `relations:` block
- `object_key` — the entity's object key (find via `list_entities` or `get_entity`)

Required permission: Editor or higher.

### After Creation/Update: Display the UI Link

After a successful `update_object` call, the response includes a `ui_url` field. **Always display this URL to the user** so they can quickly open the object in the Honeydew application.

### Remove a Relation: update_object

There is no `delete_object` for relations. To remove a relation, update the source entity's YAML with the relation removed from the `relations:` block.

1. **Find which entity defines the relation.** The relation lives in only one entity's YAML, but it could be on either side. Use `get_entity` on both entities and check which one has the relation in its `relations:` block.
2. Remove the target relation from that entity's `relations:` list (keep all other relations intact).
3. Call `update_object` with the updated YAML and the entity's `object_key`.

---

## Decision Flow

```
Need to define a relation?
    │
    ├─► Simple FK join (equality on one or more columns)?
    │       └─► Use field-based connection
    │               connection:
    │                 - src_field: <fk_column>
    │                   target_field: <pk_column>
    │
    ├─► Complex join (range, filter, SCD Type 2, multi-entity)?
    │       └─► Use expression-based connection
    │               connection_expr:
    │                 sql: |-
    │                   <custom SQL>
    │
    └─► Removing an existing relation?
            └─► Use update_object — remove relation from entity YAML
```

---

## Examples

See [examples.md](examples.md) for full worked examples covering: field-based join, composite key, expression-based (SCD Type 2), multiple relations, many-to-many through a bridge table, and removing a relation.

---

## Discovery Helpers

Use these MCP tools before defining relations:

- `get_entity` — Get entity details including existing relations, attributes, and YAML definition
- `list_entities` — List all entities (to identify source and target)
- `search_model` — Search for entities or fields by name (use `search_mode: EXACT` for known names, `OR` for broad discovery)

---

See [reference.md](reference.md) for: YAML schema, relation direction (rel_type), join types, cross-filtering options, and connection methods.

---

## Finding Candidate Relations

When you arrive from `entity-creation` with a freshly validated entity, or a batch of them from `import_tables`, nothing is connected yet and there is no list of joins to work from. Build one:

- **The new entity is the many side** — an FK column among its attributes points at an existing entity's key.
- **The new entity is the one side** — an existing entity holds an FK matching the new entity's key. This is the usual shape when a dimension is imported into a model that already has facts, and it is invisible if you only scan the new entity.
- **Between new entities** — when several tables arrive together, check the batch against itself.
- **Through a bridge table** — a junction table holding an FK to each side connects two entities that share no FK, so check whether a third entity points at both before calling them unrelated. If the junction table is not an entity yet, create it with `entity-creation` and validate it first.
- **With no key pair at all** — a missing FK is not proof of independence. Weigh the entity's grain and its date columns; if you find an effective-dated dimension, a range join or a similar shape, it may need an expression-based connection.

Confirm the one side actually has a key — an `import_tables` entity may arrive with none, and validation checks key uniqueness, not key presence. Set the key before relating to it.

Search for the FK with `search_model` in `OR` mode, since an attribute is often renamed from the column it maps to and `EXACT` matches the attribute name only; narrow a large model with `entity.field` syntax (`orders.` returns every field of matching entities). If an entity yields no candidate at all, `get_table_info` on its source table will show whether the FK exists in the warehouse but was never mapped as an attribute.

### Role Playing vs Conformed Dimension

One entity often connects to a fact more than once in different roles — a `users` entity that is the salesperson on one relation, the support agent on another. Those roles are not the same thing, and a single shared entity makes them look like one.

- **Conformed dimension** — the same business concept meaning the same thing everywhere (one `customers` entity used by orders and by tickets). Relate all of them to the one entity.
- **Role playing** — the same table standing in for different concepts, distinguished only by which FK reaches it. Create a copy of the entity per role with `entity-creation` (`sales_reps`, `support_agents`) and give each its own relation, so each role carries its own name, filters and metrics.

The tell is whether the two paths would ever be filtered or reported on together as one population. If not, it is role playing.

---

## Pre-Implementation: Present Modeling Options

**IMPORTANT: Before creating any relations, analyze the modeling options and present them to the user for decision.**

Steps:

1. **Examine the existing model** — Review current entities and relations using `list_entities` and `get_entity`
2. **Identify viable approaches** — There are often multiple valid ways to connect entities (e.g., direct connections, through intermediate entities, different join types, cross-filtering choices)
3. **Present trade-offs** — Explain the pros/cons of each approach in context of the user's data and use cases
4. **Get user confirmation** — Ask the user which approach they prefer before implementing

**Do not assume a single correct answer.** Relationship modeling involves trade-offs (query performance, maintainability, analytical flexibility) that depend on the user's specific needs.

> **Confirm anything non-trivial with the user before building it.** SCD Type 2 and other effective-dated joins, range joins, multiple paths between the same two entities, and role playing are all easy to infer confidently and get wrong. The developer knows facts about the schema that are not visible in it — which of two paths is the intended one, whether a date range is inclusive, which role a given FK plays. Propose, then ask; do not build a chain of inferred relations in one pass.

---

## Documentation Lookup

Use the `search_docs` and `query_docs_filesystem` tools from the `honeydew` MCP server to search the Honeydew documentation when:

- You need to understand join types, cross-filtering behavior, or relationship modeling patterns in more depth
- The user asks about how relations affect query behavior or metric calculations
- You need guidance on advanced modeling scenarios like SCD Type 2 joins, self-referencing relations, or multi-path joins
- The user asks about relation performance implications or troubleshooting join issues
- The user needs advanced modeling patterns for complex relationship topologies

Search for topics like: "relations", "joins", "cross-filtering", "many-to-one", "relationship modeling".

---

## Best Practices

- **Define relations on the "many" side.** The entity holding the FK is the source; use `rel_type: many-to-one`.
- **Use field-based connections for simple FK joins.** Reserve `connection_expr` for cases that genuinely require custom SQL.
- **Include all key columns in field-based connections.** If the "one" side has a composite key, all parts must be listed in `connection`.
- **Default to `cross_filtering: both`** unless performance is a concern. Restrict to `one-to-many` or `none` for large entities.
- **Always include existing relations when using update_object.** Updating an entity's YAML replaces the full `relations:` block — omitting an existing relation will delete it.
- **Use get_entity before modifying.** Always inspect current entity YAML and relations before updating to avoid accidentally removing existing ones.
- **Minimize YAML changes.** Preserve the existing field order and formatting. Only change what you need to. Objects are versioned in git, so unnecessary reordering or reformatting creates noisy diffs.

---

## MANDATORY: Validate After Creating

**After creating ANY relation, you MUST invoke the `validation` skill to test and validate.**

See the `validation` skill (Entities → "Validating Relations") for:

- How to verify relation exists via `get_entity`
- How to test cross-entity queries work
- Sanity checks (join works, no fan-out, NULLs reasonable)
- When to alert the user about issues

**Quick validation:**

1. Verify relation exists using `get_entity` on the source entity, check its relations list.
2. Test cross-entity query using `get_data_from_fields`:

- `attributes`: `["<target_entity>.<attribute>"]`
- `metrics`: `["<source_entity>.<metric>"]`

---

## Common Pitfalls to Avoid

- **Replacing existing relations unintentionally.** `update_object` replaces the full entity YAML. If the entity already has relations, fetch the current YAML first (via `get_entity`) and include all of them in the update.
- **Defining relation on the wrong entity.** Relations should be defined on the entity that holds the FK (the "many" side). Defining on the "one" side inverts the semantics.
- **Missing key columns in field-based connections.** If the target entity has a composite key, all columns must appear in `connection`. A partial key join produces fan-out and incorrect aggregations.
- **Using `connection_expr` without enforcing cardinality.** Custom SQL joins bypass Honeydew's cardinality validation. A poorly written expression can silently produce many-to-many joins.
- **`many-to-one` cross-filtering on large tables.** Filtering from the "many" side back to the "one" side requires a reverse join and is expensive. Use `none` or `one-to-many` unless the use case requires it.
