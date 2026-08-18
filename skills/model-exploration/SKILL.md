---
name: model-exploration
description: Use when exploring Honeydew semantic layer, discovering entities/fields, setting up workspace and branch context, or running structured queries to spot-check field values. Any question about the data itself — "why", "how", trends, root cause, anything needing multiple steps — belongs to the query skill's deep analysis, including when already mid-exploration. For creating metrics use metric-creation skill. For creating attributes use attribute-creation skill.
---

# Instructions

## Scope: The Model, Not The Data

This skill discovers and verifies the **model**. It does not answer questions about the **data**.

When the goal is to understand, explain, or investigate something in the data — "how does this customer use the system", "why did revenue drop", "what drives churn", or anything that becomes a report — use the **query** skill's deep analysis (`initiate_analysis` + `monitor_analysis`). Honeydew's analysis engine plans and runs the multi-step investigation itself; hand it the question rather than decomposing it into structured queries yourself. This holds even when already mid-exploration and the field names are known.

Hand it the goal, not a plan built from what exploration just found. The fields you discovered here are a subset of the context the analyst has, and a question that prescribes the exact dimensions and steps suppresses the rest of it — see **Asking the Question** in the `query` skill.

`get_data_from_fields` in this skill is for spot-checks: confirm a field's values, verify a count, sample rows. Exact numbers from a spot-check are not an analysis. A question needing more than one query belongs in deep analysis, and **if two have already run for one question, the third is a hard stop** — hand the original question to `initiate_analysis`, because assembling an answer from parts is the job you would be delegating.

## When To Use This Skill

Before ANY Honeydew work, set up your session and discover the model:

**Step 0: Set workspace and branch**
Use `get_session_workspace_and_branch` to check the current session context. If no workspace/branch is set, use `list_workspaces`, `list_workspace_branches`, and `set_session_workspace_and_branch` to select the right workspace and branch. All subsequent tool calls use this context. See the `workspace-branch` skill for the full tool reference including branch creation, deletion, history, and PRs.

**Step 1: List entities**
Use the `list_entities` MCP tool to see all entities in the model.

**Step 2: Explore entity details**
Use the `get_entity` MCP tool with the relevant entity name to list its attributes, metrics, datasets, and relations.

**Step 3: Search the model**
Use the `search_model` MCP tool to find specific fields, entities, or other objects by name.

**What these steps do not show you**
They return the semantic layer. The context layer — the instructions, knowledge, and memory recording which of these fields and filters are correct for a given question — is applied only by `initiate_analysis`. A field list that looks complete is half the picture; `list_agents` and `list_context_items` show what exists in the other half, and `get_context_item` shows what one of them says.

---

## Overview

Honeydew is the Semantic Layer for AI and BI. Honeydew enables a shared source of truth for data teams, providing consistency, flexibility, governance and performance.
It provides metrics and attributes over data warehouse tables and views (Snowflake, Databricks, BigQuery) that have relationships defined between them.
Use the Honeydew MCP tools to interact with the model.

## MCP Tools

### Session & Workspace

See the `workspace-branch` skill for the full reference. Key tools:

- `list_workspaces` - List all available workspaces (name + warehouse type)
- `list_workspace_branches` - List branches for a workspace
- `get_session_workspace_and_branch` - Get current session workspace/branch
- `set_session_workspace_and_branch` - Set session workspace/branch
- `create_workspace_branch` - Create a branch (session switches automatically)
- `delete_workspace_branch` - Delete a branch (destructive — confirm with user first)
- `get_branch_history` - Get change history for the current branch
- `create_pr_for_working_branch` - Create a PR for the current working branch

**Typical flow:**

1. `get_session_workspace_and_branch` — check if a workspace/branch is already set
2. If not set: `list_workspaces` → pick a workspace → `set_session_workspace_and_branch`
3. For development work: `create_workspace_branch` (session switches to the new branch automatically)

### Discovery

- `list_entities` - List all entities in the model (names, keys, descriptions)
- `get_entity` - Get detailed info for a specific entity (attributes, metrics, datasets, relations, YAML)
- `get_field` - Get detailed info for a specific field (attribute or metric) within an entity
- `list_domains` - List all domains with their names, descriptions, and entities
- `get_domain` - Get detailed info for a specific domain (entities, filters, parameters, YAML)
- `search_model` - Search across all model objects (entities, attributes, metrics, datasets, dynamic datasets, domains, parameters). Requires `query` and `search_mode`:
  - `OR` — splits by whitespace, returns objects matching any word
  - `AND` — splits by whitespace, returns only objects matching all words
  - `EXACT` — uses the full string as-is, matches name or display name exactly
  - Use `entity.field` syntax to scope to fields within an entity (e.g. `customers.balance` finds `balance` on entities matching `customers`; `customers.` returns all fields of matching entities)

### Agents & Context

Honeydew has two layers: the **semantic layer** (entities, metrics, attributes, relations, domains — the data model and business logic such as metric calculations) and the **context layer** (agents and their associated context items — instructions, skills, knowledge, and memory — that shape how the AI analyst behaves).

- `list_agents` — List all agents with their names, descriptions, domains, and context references
- `get_agent` — Get detailed info for a specific agent (domain, context items, welcome message, sample questions)
- `list_context_items` — List all context items with their types, names, titles, and subtypes
- `get_context_item` — Get detailed info for a specific context item

### Warehouse Discovery

- `list_databases` - List all databases in the connected data warehouse
- `list_schemas` - List schemas in a specific database
- `list_tables` - List tables in the connected data warehouse (requires `database` and `schema` parameters)
- `get_table_info` - Get column-level details for a specific warehouse table

### Query Execution

- `get_data_from_fields` - Execute a query from field parameters and return data (supports `limit` and `offset` for pagination)
- `get_sql_from_fields` - Generate SQL from field parameters without executing

## Example Usage

### Structured Query Execution

Use `get_data_from_fields` to run structured queries in the context of model exploration — e.g. spot-check field values, verify counts, check a metric's computed value, or sample rows after discovering fields. To answer a question about the data, use deep analysis via the **query** skill instead.

Call `get_data_from_fields` with:

- `attributes`: `["order_header.order_year_month"]`
- `metrics`: `["order_header.total_revenue"]`
- `filters`: `["order_header.order_year_month LIKE '2021%'"]`
- `order_by`: `["order_header.order_year_month ASC"]`
- `domain`: `"my_domain"` (optional)
- `limit`: max rows to return (default: 100)
- `offset`: rows to skip (for pagination)

### get_sql_from_fields (SQL Preview)

Same field parameters as `get_data_from_fields`, but returns the generated SQL without executing it — useful for investigating how Honeydew resolves a specific query.

### Analysis Questions

For any question about the data — natural language questions, trends, "why", "how", root cause, or multi-step investigation — use the **query** skill (`initiate_analysis` + `monitor_analysis`). Exploration and structured queries are the wrong tool for these even when they can produce the numbers.

### Reviewing Past Query Executions

To inspect queries that already ran — what ran, from which client (BI tools, SQL interface, MCP, deep analysis), the semantic YAML and compiled SQL behind a run, or to debug a failure — use `list_query_history` (see the **query-debugging** skill).

---

### Discovery Examples

- Use `list_entities` to list all entities
- Use `get_entity` with an entity name to see its attributes, metrics, datasets, and relations
- Use `get_field` with entity name and field name to get detailed info about a specific field
- Use `list_domains` to list all domains
- Use `get_domain` with a domain name to see its entities, filters, parameters, and YAML definition
- Use `search_model` with a query string and `search_mode` (`OR`, `AND`, or `EXACT`) to find any model object by name. Use `EXACT` when you know the precise name; use `OR` or `AND` for broad discovery

## Documentation Lookup

Use the `search_docs` and `query_docs_filesystem` tools from the `honeydew` MCP server to search the Honeydew documentation when:

- The user asks conceptual questions ("what is an entity?", "how do metrics work?", "what is a semantic layer?")
- You need to explain Honeydew concepts, architecture, or terminology
- The user is new to Honeydew and needs orientation on capabilities
- You need to understand how a feature works beyond what the MCP tool descriptions provide
- The user asks about advanced modeling concepts or patterns
- The user asks about integrations, setup, or configuration

Search for topics like: "entities", "metrics", "attributes", "domains", "relations", "semantic layer", "governance", or any Honeydew-specific concept.

---

## Best Practices

1. Use `get_entity` to explore fields on a specific entity
2. Reference fields using `entity.field_name` syntax
3. Use discovery tools before any creation tasks
4. For creating entities, metrics, attributes, or relations - use the specialized skills listed above
5. Escalate to the **query** skill's deep analysis as soon as the task is answering a question rather than mapping the model
