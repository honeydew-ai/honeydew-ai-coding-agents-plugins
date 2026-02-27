---
name: domain-creation
description: Guides you through creating a Honeydew domain — a governance object that scopes entity/field visibility and applies mandatory filters — ideal for setting up contexts for deep analysis.
---

## Overview

A Honeydew **domain** is a lightweight governance object that defines a scoped business context over the semantic model.

Domains control:

- **Which entities** are visible (and optionally which fields within them via field selectors)
- **Semantic filters** (`filters`) — applied to every query in the domain, for governance and access control
- **Source filters** (`source_filters`) — applied early at the source level, for performance optimization

Domains are the primary mechanism for creating focused, governed views of the model for specific teams, use cases, or analysis contexts.

> This skill focuses on domain creation and management.
> Use `entity-creation` to create entities and `attribute-creation` / `metric-creation` to add fields before scoping them into a domain.

---

## Creation Method

### create_object with YAML

Domains are created using `create_object` with domain YAML. There is no specialized `create_domain` tool.

Parameters:

- `yaml_text` — YAML defining the domain

Required permission: Editor or higher.

### Update: update_object

1. Use `search_model` to find the domain's `object_key`.
2. Call `update_object` with the full updated YAML (`yaml_text`) and the `object_key`.

> **Minimal diff rule:** When updating, preserve the existing field order and formatting from the current YAML. Only change the fields you need to modify.

### Delete: delete_object

1. Use `search_model` to find the domain's `object_key`.
2. Call `delete_object` with that `object_key`.

### After Creation/Update: Display the UI Link

After a successful `create_object` or `update_object` call, the response includes a `ui_url` field. **Always display this URL to the user** so they can quickly open the object in the Honeydew application.

---

## Decision Flow

```text
Need to create a domain?
    │
    ├─► Which entities should be included?
    │       └─► Use list_entities / search_model to discover available entities
    │
    ├─► Should all fields be visible, or only a subset?
    │       ├─► All fields → omit fields for that entity
    │       └─► Subset → use field selectors (supports wildcards and exclusions)
    │
    ├─► Are governance/access filters needed (apply to ALL queries)?
    │       └─► Use filters (semantic) with name + sql
    │
    └─► Are performance/source-level filters needed (apply only when entity is queried)?
            └─► Use source_filters with name + sql
```

---

## Examples

See [examples.md](examples.md) for full worked examples covering: basic entity selection, semantic filters, source filters, field selectors, deep analysis context and update/delete.

---

## Discovery Helpers

Use these MCP tools before creating domains:

- `list_entities` — List all entities in the model to decide which to include
- `get_entity` — Get detailed info for a specific entity (attributes, metrics, relations)
- `search_model` — Search for entities, fields, domains, or other objects by name
- `get_field` — Get detailed info about a specific field (attribute or metric)

---

See [reference.md](reference.md) for: full YAML schema, entity selection syntax, field selectors, filter types and syntax, and parameter overrides.

---

## Best Practices

- **Name domains after the business context**, not technical details. `sales_analytics` is better than `filtered_orders_v2`.
- **Start broad, then narrow.** Include all relevant entities first, then add filters and field selectors as governance requirements emerge.
- **Always set `owner`** to identify the responsible team or person for governance and accountability.
- **Prefer semantic filters (`filters`) over source filters** for governance rules. Source filters apply before computation and can change calculated values.
- **Use source filters for performance** — they're ideal for partition pruning on large datasets.
- **Use `description`** to document the domain's purpose and intended audience clearly.
- **Keep domains focused.** A domain for "Sales Team" should only include entities and fields relevant to sales analysis.
- **Use field selectors sparingly.** Only restrict fields when there's a clear governance need (e.g. hiding PII from certain teams).
- **All filter `sql` references must be fully qualified.** Always use `entity.field` notation — unqualified references fail validation.

---

## MANDATORY: Validate After Creating

**After creating ANY domain, you MUST validate that it works correctly.**

### Validation steps:

1. **Verify domain exists** using `search_model` to find the new domain by name.

2. **Test with a perspective query** — use `preview_data_from_yaml` with the `domain` parameter:

```yaml
type: perspective
name: validate_domain
domain: <domain_name>
metrics:
  - <entity>.count
```

Call with `domain: "<domain_name>"` to verify that the domain settings (e.g. filter) apply.
