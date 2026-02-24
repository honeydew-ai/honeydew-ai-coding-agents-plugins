---
name: query
description: Use when the user wants to query, analyze, or explore data through the Honeydew semantic layer. Covers structured YAML queries, natural-language questions, and multi-step deep analysis.
---

## Overview

Honeydew provides three ways to query data through the semantic layer. Each method suits a different situation — pick the right one based on how well you understand the model and how complex the question is.

| Method                    | Tool                                             | Best For                                                 |
| ------------------------- | ------------------------------------------------ | -------------------------------------------------------- |
| **Structured YAML query** | `preview_data_from_yaml` / `get_sql_from_yaml`   | You know the exact fields. Deterministic, full control.  |
| **Natural language**      | `ask_question_get_data` / `ask_question_get_sql` | Plain English question. Single query, fast answer.       |
| **Deep analysis**         | `ask_deep_analysis_question`                     | Complex, multi-step, "why" questions. Agentic reasoning. |

---

## When to Use Each Method

### 1. Structured YAML Query (`preview_data_from_yaml` / `get_sql_from_yaml`)

**Use when:**

- You know the entity, attribute, and metric names (or can discover them via `list_entities` / `get_entity`)
- You need precise control over filters, ordering, and field selection
- You want deterministic, reproducible results
- You need to validate a newly created metric or attribute
- The user specifies exact fields like "show me `detailed_listings.price` by `detailed_listings.room_type`"

**Do NOT use when:**

- You don't know the field names and the user is asking in plain English
- The question requires multi-step reasoning or investigation

**How it works:**

- `preview_data_from_yaml` — executes the query and returns data rows
- `get_sql_from_yaml` — returns the generated SQL without executing (useful for review, debugging, or handing off to other tools)

Both take the same YAML perspective format.

### 2. Natural Language (`ask_question_get_data` / `ask_question_get_sql`)

**Use when:**

- The user asks a question in plain English
- It's a single, straightforward question that maps to one query
- You don't know or aren't sure of the exact field names
- The user wants a quick answer without worrying about model details

**Do NOT use when:**

- The question involves multiple steps, comparisons across time periods, or root cause analysis
- You already know the exact fields — use a structured YAML query instead for precision

**How it works:**

- `ask_question_get_data` — translates the question to SQL, executes it, and returns results
- `ask_question_get_sql` — translates the question to SQL and returns the SQL only

### 3. Deep Analysis (`ask_deep_analysis_question`)

**Use when:**

- The question requires multiple steps or investigative reasoning
- The user asks "why" something happened (e.g., "why did revenue drop in Q3?")
- The user wants trend analysis, anomaly detection, or root cause investigation
- The question is open-ended and may require looking at the data from multiple angles
- Follow-up questions build on prior analysis (use `conversation_id`)

**Do NOT use when:**

- The question is simple and can be answered with a single query
- You just need to fetch specific data points

---

## Decision Flow

```
User asks a data question
    │
    ├─► Do you know the exact field names?
    │       │
    │       ├─► YES → preview_data_from_yaml (structured, deterministic)
    │       │
    │       └─► NO → Can you quickly discover them?
    │               │
    │               ├─► YES → list_entities / get_entity → then preview_data_from_yaml
    │               │
    │               └─► NO → ask_question_get_data (let Honeydew resolve fields)
    │
    ├─► Is it a simple, single-query question in plain English?
    │       └─► YES → ask_question_get_data
    │
    ├─► Does it require investigation, "why", trends, or multi-step reasoning?
    │       └─► YES → ask_deep_analysis_question
    │
    └─► Does the user want to see the SQL without running it?
            ├─► From known fields → get_sql_from_yaml
            └─► From plain English → ask_question_get_sql
```

---

## Method 1: Structured YAML Query

### Building the YAML Perspective

A perspective query defines what data to retrieve:

```yaml
type: perspective
name: <descriptive_query_name>
attributes:
  - <entity>.<attribute_name>
  - <related_entity>.<attribute_name>
metrics:
  - <entity>.<metric_name>
filters:
  - <entity>.<field> = 'value'
order_by:
  - <entity>.<field> ASC|DESC
```

### Field Reference

- **attributes** — dimensions to group by (columns in the output)
- **metrics** — aggregated measures (SUM, COUNT, AVG, etc.)
- **filters** — row-level filters applied before aggregation
- **order_by** — sort order for results

All fields use `entity.field_name` syntax. Cross-entity fields are supported when relations exist.

### Discovering Fields

Before building a query, discover the available fields:

1. `list_entities` — see all entities
2. `get_entity` with entity name — see its attributes, metrics, and relations
3. `get_field` with entity and field name — get detailed info about a specific field
4. `search_model` with a keyword — find fields across the model

### Examples

**Simple metric query — total count:**

Call `preview_data_from_yaml` with yaml_text:

```yaml
type: perspective
name: listing_count
metrics:
  - detailed_listings.count
```

**Dimension breakdown — listings by room type:**

Call `preview_data_from_yaml` with yaml_text:

```yaml
type: perspective
name: listings_by_room_type
attributes:
  - detailed_listings.room_type
metrics:
  - detailed_listings.count
order_by:
  - detailed_listings.count DESC
```

**Filtered query — only entire homes:**

Call `preview_data_from_yaml` with yaml_text:

```yaml
type: perspective
name: entire_home_stats
attributes:
  - detailed_listings.neighbourhood_cleansed
metrics:
  - detailed_listings.count
filters:
  - detailed_listings.room_type = 'Entire home/apt'
order_by:
  - detailed_listings.count DESC
```

**Cross-entity query — listings with host info:**

Call `preview_data_from_yaml` with yaml_text:

```yaml
type: perspective
name: listings_by_host_type
attributes:
  - detailed_listings.room_type
  - dim_host.host_is_superhost
metrics:
  - detailed_listings.count
order_by:
  - detailed_listings.count DESC
```

**Pagination — large result sets:**

Call `preview_data_from_yaml` with:

- `yaml_text`: the perspective YAML
- `limit`: 50 (max rows to return)
- `offset`: 100 (skip first 100 rows)

**SQL preview only:**

Call `get_sql_from_yaml` with the same YAML to see the generated SQL without executing.

### Filter Syntax

Filters use standard comparison expressions: `=`, `>`, `<`, `IN (...)`, `ILIKE`, `SEARCH(...)`, `IS NULL`, booleans, date ranges, and `AND`/`OR` combinations.

> For the complete filter expression reference — including SEARCH, date handling, and type casting — see the **filtering** skill.

---

## Method 2: Natural Language Query

### ask_question_get_data

Call with:

- `question` (required): the question in plain English
- `max_rows` (required): maximum number of rows to return

```
question: "What are the top 10 neighbourhoods by number of listings?"
max_rows: 10
```

Returns the query results directly.

### ask_question_get_sql

Call with:

- `question` (required): the question in plain English

```
question: "What are the top 10 neighbourhoods by number of listings?"
```

Returns the generated SQL without executing.

### Tips for Natural Language Queries

- Be specific: "average price per room type" is better than "show me prices"
- Mention the entity/domain if ambiguous: "average listing price" not just "average price"
- Include time ranges explicitly: "in the last 12 months" or "for 2024"
- Specify limits: "top 10", "bottom 5"

---

## Method 3: Deep Analysis

### ask_deep_analysis_question

Call with:

- `question` (required): the analysis question
- `conversation_id` (optional): ID from a previous deep analysis call, for follow-up questions

```
question: "Analyze the relationship between host response time and review scores. Are there significant patterns?"
```

Returns:

- Markdown analysis report with findings
- Supporting data
- Suggested follow-up questions
- `conversation_id` for continuing the conversation

### Follow-up Questions

Use `conversation_id` from the previous response to ask follow-up questions that build on the prior analysis:

```
question: "Now break this down by room type — does the pattern hold across all types?"
conversation_id: "<id from previous response>"
```

### Good Deep Analysis Questions

- "Why did the average review score drop for listings in Brooklyn?"
- "What factors most influence listing price? Analyze the key drivers."
- "Compare superhost vs non-superhost performance across all metrics."
- "Identify unusual patterns in listing availability over the past year."
- "What are the characteristics of top-performing listings?"

---

## Combining Methods

For complex tasks, combine methods in sequence:

1. **Discover** — Use `list_entities` / `get_entity` to understand the model
2. **Explore** — Use `ask_question_get_data` to get a quick feel for the data
3. **Drill down** — Use `preview_data_from_yaml` for precise, targeted queries
4. **Investigate** — Use `ask_deep_analysis_question` for root cause or trend analysis

### Example Workflow

User: "Help me understand pricing patterns for Airbnb listings."

1. Discover entities: `list_entities` → find `detailed_listings`
2. Explore fields: `get_entity` for `detailed_listings` → find `price`, `room_type`, `neighbourhood_cleansed`
3. Quick overview: `ask_question_get_data` → "What is the average listing price by room type?"
4. Targeted query: `preview_data_from_yaml` → price distribution by neighbourhood for Entire homes only
5. Deep dive: `ask_deep_analysis_question` → "What factors most influence listing price? Analyze correlations with room type, location, amenities, and reviews."

---

## Best Practices

- **Start with discovery** — always check `list_entities` / `get_entity` before building queries, so you reference real fields
- **Use structured queries for precision** — when you know the fields, `preview_data_from_yaml` gives you full control and reproducible results
- **Use natural language for speed** — when the user asks a quick question and you don't need to control every detail
- **Use deep analysis for insight** — when the question is about "why" or requires investigating multiple dimensions
- **Paginate large results** — use `limit` and `offset` in `preview_data_from_yaml` to avoid overwhelming output
- **Show SQL when debugging** — use `get_sql_from_yaml` or `ask_question_get_sql` to inspect the generated query
- **Reference fields correctly** — always use `entity.field_name` syntax in YAML perspectives
