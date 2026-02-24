# Honeydew AI Claude Plugins

A Claude Code plugin marketplace for [Honeydew AI](https://honeydew.ai) — skills and tools powered by the Honeydew MCP that help you build semantic models and analyze data through natural conversation.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- A Honeydew AI workspace with the [Honeydew MCP server](https://github.com/honeydew-ai/honeydew-mcp) configured

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add honeydew-ai/honeydew-ai-claude-plugins
```

Then install the plugins you need:

```
/plugin install semantic-modeling-tools@honeydew-ai
/plugin install data-analysis-tools@honeydew-ai
```

## Available Plugins

### Semantic Modeling Tools

Tools for building and managing your Honeydew semantic layer. Includes 6 skills:

| Skill | Description |
|-------|-------------|
| **model-exploration** | Explore the semantic model — list entities, search fields, inspect relationships, and discover warehouse tables |
| **entity-creation** | Create entities — the foundational business concepts built from data warehouse tables |
| **relation-creation** | Define relationships between entities with join types, cardinality, and complex join conditions |
| **attribute-creation** | Create calculated attributes (dimensions) — per-row virtual columns defined with SQL expressions |
| **metric-creation** | Create metrics (KPIs) — reusable aggregations like totals, averages, ratios, and growth rates |
| **validation** | Mandatory post-creation validation — type-specific sanity checks, cross-validation, and error handling |

### Data Analysis Tools

Tools for querying and analyzing data through the Honeydew semantic layer. Includes 2 skills:

| Skill | Description |
|-------|-------------|
| **query** | Query data using structured YAML perspectives, natural language questions, or multi-step deep analysis |
| **filtering** | Advanced filtering syntax — comparisons, string matching, date handling, nulls, and full-text search |

## Supported Data Warehouses

- Snowflake
- Databricks
- BigQuery

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
