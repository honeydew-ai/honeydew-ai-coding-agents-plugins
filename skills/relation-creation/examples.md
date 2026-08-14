# Relation Examples

## Many-to-one — orders → customers (field-based)

Call `update_object` with `object_key` for the orders entity and yaml_text:

```yaml
type: entity
name: orders
display_name: Orders
keys:
  - order_id
key_dataset: orders_source
relations:
  - target_entity: customers
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: customer_id
        target_field: customer_id
```

## Many-to-one — orders → customers (composite key)

Call `update_object` with `object_key` for the orders entity and yaml_text:

```yaml
type: entity
name: orders
display_name: Orders
keys:
  - order_id
key_dataset: orders_source
is_time_spine: false
relations:
  - target_entity: customers
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: customer_id
        target_field: customer_id
      - src_field: region_id
        target_field: region_id
```

## Many-to-one — expression-based (SCD Type 2 dimension)

Call `update_object` with `object_key` for the orders entity and yaml_text:

```yaml
type: entity
name: orders
display_name: Orders
keys:
  - order_id
key_dataset: orders_source
is_time_spine: false
relations:
  - target_entity: dim_customers
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection_expr:
      sql: |-
        orders.customer_id = dim_customers.customer_id
        AND orders.order_date >= dim_customers.valid_from
        AND orders.order_date < dim_customers.valid_to
```

## Multiple relations on one entity

Call `update_object` with `object_key` for the orders entity and yaml_text:

```yaml
type: entity
name: orders
display_name: Orders
keys:
  - order_id
key_dataset: orders_source
is_time_spine: false
relations:
  - target_entity: customers
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: customer_id
        target_field: customer_id
  - target_entity: locations
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: location_id
        target_field: location_id
```

## Many-to-many through a bridge table

`rel_type` has no many-to-many form. Model the junction table as its own entity at the grain of one row per pair — its key is usually the composite of both foreign keys — and give it one `many-to-one` relation to each side. Both live in the bridge entity's YAML, so they go in a single `update_object`.

If the junction table is not an entity yet, create it with the `entity-creation` skill and validate it first; only then add the relations.

Call `update_object` with `object_key` for the product_tags entity and yaml_text:

```yaml
type: entity
name: product_tags
display_name: Product Tags
keys:
  - product_id
  - tag_id
key_dataset: product_tags_source
is_time_spine: false
relations:
  - target_entity: products
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: product_id
        target_field: product_id
  - target_entity: tags
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: tag_id
        target_field: tag_id
```

## Remove a relation

To remove the `locations` relation from the orders entity while keeping the `customers` relation:

1. Use `get_entity` to fetch the current orders entity YAML.
2. Remove the `locations` entry from the `relations:` list.
3. Call `update_object` with `object_key` for the orders entity and yaml_text:

```yaml
type: entity
name: orders
display_name: Orders
keys:
  - order_id
key_dataset: orders_source
is_time_spine: false
relations:
  - target_entity: customers
    rel_type: many-to-one
    rel_join_type: left
    cross_filtering: both
    connection:
      - src_field: customer_id
        target_field: customer_id
```
