# Domain Examples

## Basic — entity selection only

Call `create_object` with yaml_text:

```yaml
type: domain
name: sales_analytics
display_name: Sales Analytics
description: |-
  Domain for the sales team. Includes orders, customers, and products
  for revenue analysis and customer segmentation.
owner: sales-team
entities:
  - name: orders
  - name: customers
  - name: products
```

## Domain with semantic filters

Semantic filters apply to every query in the domain, even if the filtered entity isn't directly referenced.

Call `create_object` with yaml_text:

```yaml
type: domain
name: completed_orders
display_name: Completed Orders
description: |-
  Scoped to completed orders only. Used by the fulfillment team
  to analyze shipped and delivered orders.
owner: fulfillment-team
entities:
  - name: orders
  - name: customers
  - name: line_items
filters:
  - name: completed_only
    sql: orders.status = 'completed'
    description: Only include completed orders
```

## Domain with source filters

Source filters apply early at the source level — only when the entity is part of the query. Use for performance optimization on partitioned data.

Call `create_object` with yaml_text:

```yaml
type: domain
name: recent_orders
display_name: Recent Orders
description: |-
  Performance-optimized domain. Source filter limits orders to recent
  data to leverage date partitioning.
owner: data-team
entities:
  - name: orders
  - name: customers
  - name: line_items
source_filters:
  - name: recent_data
    sql: orders.order_date >= '2024-01-01'
    description: Limit to recent orders for partition pruning
```

## Domain with field selectors

Field selectors support wildcards and exclusion patterns, evaluated in order.

Call `create_object` with yaml_text:

```yaml
type: domain
name: marketing_view
display_name: Marketing View
description: |-
  Restricted view for marketing team. Hides PII fields
  from customers. Exposes only product category fields.
owner: marketing-team
entities:
  - name: customers
    fields:
      - "*"
      - -ssn
      - -phone_number
      - -email
  - name: orders
  - name: products
    fields:
      - product_id
      - category
      - subcategory
```

## Domain for deep analysis context

Creating a focused domain to use with `ask_deep_analysis_question`.

Call `create_object` with yaml_text:

```yaml
type: domain
name: revenue_analysis
display_name: Revenue Analysis
description: |-
  Focused domain for revenue deep-dives. Semantic filter ensures
  only completed orders are included in all analysis.
owner: finance-team
entities:
  - name: orders
  - name: customers
  - name: products
  - name: line_items
filters:
  - name: completed_orders
    sql: orders.status = 'completed'
source_filters:
  - name: recent_data
    sql: orders.order_date >= '2024-01-01'
    description: Partition pruning for performance
```

Then use the domain for analysis:

```python
ask_deep_analysis_question(
  question="What were the top revenue drivers? Break down by product category and customer segment.",
  domain="revenue_analysis"
)
```

## Domain with parameter-based filter

Call `create_object` with yaml_text:

```yaml
type: domain
name: tenant_scoped
display_name: Tenant Scoped
description: |-
  Multi-tenant domain. Filters all data to the current user's tenant
  via the $TENANT parameter.
owner: platform-team
entities:
  - name: orders
  - name: customers
  - name: products
filters:
  - name: tenant_filter
    sql: dim_tenant.tenant_id = $TENANT
parameters:
  - name: TENANT
    value: "default"
```

## Domain hierarchy — base + extending child

Define a reusable base domain, then extend it for a region-specific view. The child inherits all entities, filters, and metadata, and overrides only the differences.

Base domain — call `create_object` with yaml_text:

```yaml
type: domain
name: base_sales
display_name: Base Sales
description: |-
  Shared sales data model and governance. Other sales domains extend this.
owner: data-team
entities:
  - name: customers
    fields: ["*"]
  - name: orders
    fields: ["*"]
  - name: products
    fields: ["*"]
filters:
  - name: exclude_test
    sql: orders.is_test = false
```

Child domain (extends the base) — call `create_object` with yaml_text:

```yaml
type: domain
name: sales_us
display_name: US Sales
description: |-
  US-region sales view. Inherits base_sales, hides customer SSN,
  and restricts to US customers.
owner: sales-team
extends:
  - base_sales
entities:
  - name: customers
    fields: ["-ssn"]          # extend inherited field list: drop SSN
filters:
  - name: us_region           # new filter (exclude_test is inherited)
    sql: customers.country = 'US'
source_filters:
  - name: recent_data
    sql: orders.order_date >= '2024-01-01'
```

`sales_us` resolves to: all three entities (customers without `ssn`), both `exclude_test` (inherited) and `us_region` (added) filters, plus the source filter.

## Domain hierarchy — multiple inheritance (mixins)

Compose a base data model with separate security and performance mixins. Parents are evaluated left-to-right; the rightmost wins on conflicts, and the child overrides all parents.

Mixins and composed domain — call `create_object` once per domain:

```yaml
# Security mixin
type: domain
name: security_mixin
description: Governance filter shared across secure domains.
owner: data-gov
filters:
  - name: exclude_test
    sql: orders.is_test = false
```

```yaml
# Performance mixin
type: domain
name: performance_mixin
description: Partition-pruning source filter shared across domains.
owner: data-platform
source_filters:
  - name: partition_recent
    sql: orders.order_date >= '2024-01-01'
```

```yaml
# Composed domain
type: domain
name: sales_secure
display_name: Secure Sales
description: |-
  Base sales model composed with security and performance mixins.
  Strips customer PII to ID only.
owner: sales-team
extends:
  - base_sales
  - security_mixin
  - performance_mixin
entities:
  - name: customers
    fields: ["-*", customer_id]   # restrict to ID only (no PII)
filters:
  - name: public_only             # child-specific filter
    sql: customers.visibility = 'PUBLIC'
```

## Domain hierarchy — removing an inherited item

Use `merge: remove` to drop something an extended parent contributes. Call `create_object` with yaml_text:

```yaml
type: domain
name: sales_no_products
display_name: Sales (No Products)
description: |-
  Extends base_sales but excludes the products entity and the
  inherited test filter.
owner: sales-team
extends:
  - base_sales
entities:
  - name: products
    merge: remove
filters:
  - name: exclude_test
    merge: remove
```

## Update existing domain

1. Use `search_model` to find the domain's `object_key`.
2. Call `update_object` with `object_key` and yaml_text:

```yaml
type: domain
name: sales_analytics
display_name: Sales Analytics
description: |-
  Domain for the sales team. Updated to include line items
  and campaign data for deeper analysis.
owner: sales-team
entities:
  - name: orders
  - name: customers
  - name: products
  - name: line_items
  - name: campaigns
```

## Delete domain

1. Use `search_model` to find the domain's `object_key`.
2. Call `delete_object` with that `object_key`.
