# Attribute Examples

## Basic — net price after discount

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: net_price
display_name: Net Price
owner: data-team
datatype: float
sql: |-
  orders.amount * (1 - orders.discount_rate)
```

## Boolean flag — high spender

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: users
name: is_high_spender
display_name: Is High Spender
description: Threshold defined by Marketing; used for premium campaign targeting
owner: data-team
datatype: bool
sql: |-
  CASE WHEN users.total_spent > 1000 THEN TRUE ELSE FALSE END
```

## Grouping / Binning — order size tier

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: order_size_tier
display_name: Order Size Tier
description: Thresholds set by Operations for fulfillment routing; Small < $100, Medium < $1000, Large ≥ $1000
owner: data-team
datatype: string
sql: |-
  CASE
    WHEN orders.amount < 100 THEN 'Small'
    WHEN orders.amount < 1000 THEN 'Medium'
    ELSE 'Large'
  END
```

## Multi-Entity — extended cost using product price

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: line_items
name: extended_cost
display_name: Extended Cost
owner: data-team
datatype: float
sql: |-
  line_items.quantity * products.unit_cost
```

## Date truncation — order month

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: order_month
display_name: Order Month
owner: data-team
datatype: date
sql: |-
  DATE_TRUNC('month', orders.order_date)
timegrain: month
```

## Window Function — customer revenue rank

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: customers
name: revenue_rank
display_name: Revenue Rank
description: Ranked within each region separately; rank 1 = highest revenue customer in that region
owner: data-team
datatype: number
sql: |-
  RANK() OVER (PARTITION BY customers.region ORDER BY customers.total_revenue DESC)
```

## Running total — cumulative revenue

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: cumulative_revenue
display_name: Cumulative Revenue
owner: data-team
datatype: float
sql: |-
  SUM(orders.amount) OVER (
    ORDER BY orders.order_date ROWS
    BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )
```

## Semi-Structured — shipping city from JSON

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: shipping_city
display_name: Shipping City
owner: data-team
datatype: string
sql: |-
  GET_PATH(orders.metadata, 'shipping.city')::string
```

## Safe division — conversion rate

Call `create_object` with yaml_text:

```yaml
type: calculated_attribute
entity: campaigns
name: conversion_rate
display_name: Conversion Rate
description: Returns 0 (not null) when there are no impressions; campaigns with no spend are included in aggregations
owner: data-team
datatype: float
sql: |-
  DIV0(campaigns.conversions, campaigns.impressions)
```

## Update existing attribute

1. Use `get_entity` or `search_model` to find the attribute's `object_key`.
2. Call `update_object` with `object_key` and yaml_text:

```yaml
type: calculated_attribute
entity: orders
name: net_price
display_name: Net Price
owner: data-team
datatype: float
sql: |-
  orders.amount * (1 - orders.discount_rate) - orders.fees
```

## Delete attribute

1. Use `search_model` to find the attribute's `object_key`.
2. Call `delete_object` with that `object_key`.
