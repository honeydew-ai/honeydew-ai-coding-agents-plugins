---
name: query
description: Use when the user wants to query or analyze data through the Honeydew semantic layer — including natural language analysis questions, deep multi-step investigations, and structured queries. For model/field discovery use the model-exploration skill.
---

## Prerequisites

Queries run against the workspace and branch set for the current session. Use `get_session_workspace_and_branch` to check the current context. If no workspace/branch is set, use `list_workspaces`, `list_workspace_branches`, and `set_session_workspace_and_branch` to select one. See the `workspace-branch` skill for the full workspace/branch tool reference.

---

## Overview

Honeydew gives you two ways to answer a question about the data, plus tools for reviewing analyses and queries that already ran. Choose between the two by asking whether the specification — which fields, which filters, which population — is given to you or chosen by you.

| Method                    | Tool                                              | Best For                                                                         |
| ------------------------- | ------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Deep analysis**         | `initiate_analysis` + `monitor_analysis`          | **Default for any question about the data.** The only path that applies the context layer — your organization's instructions, knowledge, and memory about which fields and definitions are correct for a given question. |
| **Structured query**      | `get_data_from_fields` / `get_sql_from_fields`    | Executing a specification you already trust. Deterministic execution — and no check that the specification is right. |
| **Explain a prior step**  | `get_analysis_step_details`                       | User asks how a specific step in a prior analysis was calculated.                |
| **Browse past analyses**  | `list_analysis_chats`                             | User wants to see past conversations or find a prior analysis.                   |
| **Read a past conversation** | `get_stored_conversation`                      | User wants to read or review the full content of a specific past conversation.   |
| **Review query history**  | `list_query_history`                              | User wants to inspect past query executions — what ran, from which client, the query behind a run, or to debug a failure. |

---

## When to Use Each Method

### Deep Analysis (`initiate_analysis` + `monitor_analysis`)

**Use when:**

- The goal is to understand, explain, or investigate rather than to retrieve a figure
- The question requires multiple steps or investigative reasoning
- The user asks "why" something happened (e.g., "why did revenue drop in Q3?")
- The user wants trend analysis, anomaly detection, or root cause investigation
- The question is open-ended and may require looking at the data from multiple angles
- Follow-up questions build on prior analysis (use `conversation_id`)
- A figure is wanted whose fields you cannot identify, and finding them would take more work than handing over the question

### Structured Query (`get_data_from_fields` / `get_sql_from_fields`)

**Use when:**

- The user named the exact fields — "show me `detailed_listings.price` by `detailed_listings.room_type`" — so the specification is theirs
- A prior analysis reported the fields and filters it used, and you want another slice or the raw numbers behind one of its claims
- You are testing a specification rather than relying on one: validating a metric or attribute you just created, spot-checking a field's values, verifying a count
- You need precise control over filters, ordering, and pagination for a figure whose definition is not in question

**Do NOT use when:**

- The goal is to understand, explain, or investigate rather than to retrieve a known figure — knowing the field names does not make a structured query the right tool
- The answer depends on a choice you would be making about which field, filter, or population is correct. That choice is what the context layer records, and a structured query applies none of it — it executes your specification exactly and cannot tell you the specification is wrong
- You would need more than one query to assemble the answer — hand the question over instead. **And if two have already run for one question, the third is a hard stop**: assembling an answer from parts is the job you would be delegating

**How it works:**

- `get_data_from_fields` — executes the query and returns data rows
- `get_sql_from_fields` — returns the generated SQL without executing. Use it when the SQL itself is what's wanted: handing it to the warehouse, dbt, or another tool, or bisecting a failing query to watch a fragment appear and disappear (see the **query-debugging** skill). The output is long machine-generated SQL — to understand what a field computes, read the model with `get_field` / `get_entity` instead

Both take the same field parameters.

---

## Decision Flow

```
User asks a data question
    │
    ├─► User asks to explain / drill into a step from a prior analysis?
    │       └─► get_analysis_step_details (step_id from monitor_analysis)
    │           Returns semantic query, data results, and SQL for that step
    │
    ├─► User wants to browse past conversations / find a prior analysis?
    │       └─► list_analysis_chats (paginated list, newest first)
    │
    ├─► User wants to read the content of a specific past conversation?
    │       └─► get_stored_conversation (conversation_id from list_analysis_chats)
    │
    ├─► User wants to inspect past query executions (what ran / from which client / the query behind a run / a failure)?
    │       └─► list_query_history (filter by status/client/domain/user/time; most recent first)
    │
    ├─► Investigation / "why" / "how" / trends / root cause / anything that
    │   takes more than one query to answer?
    │       └─► initiate_analysis + monitor_analysis
    │           Check this BEFORE the field-names question below — a question
    │           whose fields you happen to know is still an investigation
    │
    └─► Retrieving a specific figure or row set?
            │
            ├─► The specification is given, not chosen by you — the user named
            │   the fields, a prior analysis reported them, or the specification
            │   is itself what you are testing → get_data_from_fields
            │         (or get_sql_from_fields to preview SQL without executing)
            │
            └─► You would be choosing it → initiate_analysis + monitor_analysis
```

---

## Structured Query in Detail

### Field Parameters

A structured query uses flat field parameters to define what data to retrieve:

- **`attributes`** — dimensions to group by (columns in the output), e.g. `["entity.attribute_name"]`
- **`metrics`** — aggregated measures (SUM, COUNT, AVG, etc.), e.g. `["entity.metric_name"]`
- **`filters`** — row-level filters applied before aggregation, e.g. `["entity.field = 'value'"]`. A filter written over an aggregate instead applies after aggregation — see the **filtering** skill
- **`order_by`** — sort order for results, e.g. `["entity.field DESC"]`. When a field is aliased, sort on the alias.
- **`domain`** — optional domain name for query context
- **`limit`** — max rows to return (default: 100)
- **`offset`** — rows to skip (for pagination)

All fields use `entity.field_name` syntax. Cross-entity fields are supported when relations exist.

### Discovering Fields

Before building a query, discover the available fields:

1. `list_entities` — see all entities
2. `get_entity` with entity name — see its attributes, metrics, and relations
3. `get_field` with entity and field name — get detailed info about a specific field
4. `list_domains` — see all available domains (useful before passing `domain` parameter)
5. `search_model` with a keyword and `search_mode` (`OR` for broad discovery, `EXACT` for known names) — find fields across the model

### Examples

**Filtered breakdown — entire homes by neighbourhood:**

Call `get_data_from_fields` with:

- `attributes`: `["detailed_listings.neighbourhood_cleansed"]`
- `metrics`: `["detailed_listings.count"]`
- `filters`: `["detailed_listings.room_type = 'Entire home/apt'"]`
- `order_by`: `["\"detailed_listings.count\" DESC"]`

Attributes may span entities wherever a relation exists — adding `dim_host.host_is_superhost` to the list above joins host detail into the same breakdown.

**Using aliases — rename fields or ad-hoc expressions:**

You can alias any field or ad-hoc expression using `AS "alias_name"`. This controls the column name in the output.

Call `get_data_from_fields` with:

- `attributes`: `["detailed_listings.room_type"]`
- `metrics`: `["detailed_listings.count AS \"total_listings\"", "AVG(detailed_listings.price) AS \"avg_price\""]`
- `order_by`: `["\"total_listings\" DESC"]`

Once aliased, use the alias (not the original expression) in `order_by`.

### Filter Syntax

Filters use standard comparison expressions: `=`, `>`, `<`, `IN (...)`, `ILIKE`, `SEARCH(...)`, `IS NULL`, booleans, date ranges, and `AND`/`OR` combinations.

> For the complete filter expression reference — including SEARCH, date handling, and type casting — see the **filtering** skill.

---

## Deep Analysis in Detail

Deep analysis is a stateful, resumable analyst sub-agent: you delegate a goal to it and monitor it, rather than driving its steps. It plans its own investigation, keeps its own memory (the `conversation_id` is its scratchpad), can pause to ask a clarifying question, and can be aborted and resumed without losing what it has computed. You reach it through a polling loop rather than a single call, so a figure whose **definition is not in question** — one the user specified, one a prior analysis established, one you are spot-checking — is not worth delegating. Knowing the field names is not the same test: exploration returns the semantic layer only, and the context layer may hold an instruction that the obvious field or filter is the wrong one for this question. The rules below follow from that — hand it the goal rather than a plan, correct it by interrupting and resuming rather than starting over, and open a fresh conversation for an unrelated task rather than putting it in this one's context.

### Asking the Question

State the goal, not the plan. The analyst has context you do not: instructions, knowledge, and conventions held in the semantic layer about which fields, filters, and definitions are correct for a given question. An over-constrained question suppresses that context twice over — the steps you prescribe may be wrong because you are missing it, and a question that already contains a full plan gives the analyst little reason to load it.

- Ask: "What's driving the revenue decline in Q3?"
- Not: "Compare revenue by category and region for Q3 vs Q2, then rank categories by delta."

Add precision through follow-ups instead, once the interpretation and plan come back — by then the analyst has its context loaded and a specific redirection lands on top of it rather than in place of it. Precision about what you want to know, though, not about how to compute it: a follow-up is as much a goal as the first question, so ask whether the pattern holds rather than naming the breakdown you expect.

### initiate_analysis + monitor_analysis

Deep analysis is a two-step async process:

**Step 1 — start the analysis:**

Call `initiate_analysis` with:

- `question` (required): the analysis question
- `agent` (required for new conversations): agent name — use `list_agents` to discover available agents and their associated domains. **Workspace and branch must be set before calling `list_agents`** (agents are workspace-scoped)
- `conversation_id` (optional): ID from a previous call, for follow-up questions

Returns a `conversation_id` immediately. New conversations also return a `ui_url` — **always display this URL to the user** so they can follow the analysis in the Honeydew application.

**Step 2 — poll until done:**

Call `monitor_analysis` repeatedly with the `conversation_id`. Each call returns only new messages since the last call. `status` is `"STILL_RUNNING"` while the analysis works and `"DONE"` once it has stopped; `"NO_CHAT_CURRENTLY_RUNNING"` means it had already finished before you polled — read that one with `get_stored_conversation` rather than polling on.

`status` and `stop_reason` are separate fields and `DONE` belongs to both. `status` says whether the run has stopped; once it has, `stop_reason` says what kind of ending it was. `NO_CHAT_CURRENTLY_RUNNING` is never a `stop_reason`.

| `stop_reason` | Meaning | What to do |
|---------------|---------|------------|
| `"DONE"` | Finished normally | Read `responses` array for the final report |
| `"ASK"` | Analysis paused to ask a clarifying question | Read `responses` for the question, answer with a new `initiate_analysis` on the same `conversation_id` |
| `"FAIL"` | The run ended without producing an answer | There is nothing in `responses` to report. Do not present partial progress as a result — say the analysis did not complete. A follow-up on the same `conversation_id` starts fresh rather than resuming |
| `"ABORTED"` | This execution run was stopped | **Not terminal.** Conversation state is preserved — continue with a new `initiate_analysis` on the same `conversation_id` |

**Report progress when it's meaningful to the user** — not every poll, but not silently either. Use judgement:

- On `interpretation` / `plan`: tell the user what the analysis intends to do
- On every `step_insight` with a substantive finding: post a one-liner describing what was found — e.g. *"58 menu items found, top is The King Combo at $431M"*
- If several steps have passed without a user-facing update, post a brief aggregate — e.g. *"Analyzed pricing by neighbourhood, computed averages, filtered outliers"* — so the user knows progress is being made
- On internal errors, retries, or backtracking steps: skip reporting — the user doesn't need to know the agent corrected itself, only that meaningful progress is being made

When `status` is `"DONE"`, the final user-facing report is in the `responses` array.

```
# Example
initiate_analysis(question="What's driving revenue across cuisine types?", agent="listings-analyst")
→ { conversation_id: "abc123", ui_url: "https://..." }

# Poll loop — report to user after each call that has new content
monitor_analysis(conversation_id="abc123")
→ interpretation + plan received → tell user what the analysis will do

monitor_analysis(conversation_id="abc123")
→ step insight received → report: "Top item is Indian at $1B"

monitor_analysis(conversation_id="abc123")
→ step insight received → report: "% contribution: Indian leads at 34%, followed by Italian at 22%"

...

monitor_analysis(conversation_id="abc123")
→ { status: "DONE", responses: [{ text: "..." }] }
```

### Feedback on a Finished Analysis

`provide_analysis_feedback` attaches feedback to a `conversation_id`:

- **Positive**: a short affirmative string, e.g. `"Good"`
- **Negative**: `<Reason>: <details>` where `Reason` is one of `Chart Issue`, `Data Issue`, `Wrong Judgement`, or `Other` — e.g. `"Data Issue: revenue figures don't match our BI tool"`
- **Clear existing feedback**: pass `null`

There is one entry per conversation, covering the conversation as a whole, and a second call overwrites the first — so **the user's judgement always wins**. Never overwrite feedback the user gave with your own.

**From the user** — trigger when the user says things like: "that was correct", "that's wrong", "the data looks off", "great analysis", "this is incorrect because...". Record what they said.

**On your own initiative** — only from evidence, never from satisfaction. You asked the question, so "it answered what I needed" or "the numbers look plausible" is self-assessment: biased in your own favour, and it dilutes the feedback curators review. What qualifies is a check you can name:

- The result disagrees with, or confirms, an independent source — a structured query over the same fields and filters, a figure the user supplied, a documented value
- A data defect visible in the result — impossible nulls, counts inflated by a fan-out join, two routes to the same number disagreeing
- A conclusion the analysis's own numbers do not support
- A chart that misrepresents the data it plots

Tag it `[agent]` and name the evidence, so a review pass can separate agent-sourced feedback from the user's. Keep `<Reason>:` leading on negative feedback so the reason stays machine-readable:

- `"Data Issue: [agent] reported total revenue 4.2M, but get_data_from_fields on order_detail.revenue with the same date filter returns 3.8M"`
- `"[agent] verified against an independent get_data_from_fields call on order_detail.revenue by menu.item_category for 2021 — figures match"`

With no check to name, leave no feedback. That is a correct outcome, not a skipped step.

### Follow-up Questions

Use `conversation_id` from the previous analysis to ask follow-up questions that build on prior state. **Start a new conversation (omit `conversation_id`) when the topic changes completely** — reusing a conversation for an unrelated question carries stale context into the new analysis and can skew results.

```
initiate_analysis(
  question="Does that pattern hold across room types, or is one of them driving it?",
  conversation_id="abc123"
)
```

### Continuing Inside an Analysis

Once a conversation exists, each next question is a choice between a follow-up and dropping out to a structured query.

**Send a follow-up when:**

- The next step needs reasoning rather than a different breakdown — "does the pattern hold if we control for market size?", "why is that outlier there?"
- The next step builds on groups the conversation already computed. A structured query cannot express these ad hoc — ranks, table calculations, filtering on a rank exist as calculated attributes in the model, not as something a query can compute on the fly. A ranking the analysis has already built is reusable for free inside the conversation, and outside it would have to be modelled or rebuilt by hand

**Drop out to `get_data_from_fields` when:**

- You need the raw numbers behind a specific claim the analysis made
- You want another slice of a metric the analysis has already established
- It is a distinct-values or count lookup
- You want a result that is deterministic and reproducible

Only work done inside the conversation shows up at the `ui_url` you gave the user. Numbers you produce with a structured query afterwards won't be there, so report them yourself rather than leaving a gap between what the app shows and what you say.

A finished analysis is also the best source of field names for structured queries: it reports the exact `entity.field` references and filters it used, and `get_analysis_step_details` gives the semantic query behind any step. Feed those attributes, metrics, and filters into `get_data_from_fields` instead of rediscovering them from `list_entities`. The compiled SQL a step also returns is not an input to `get_data_from_fields` — it is for reading or handing to the warehouse.

### Interrupting and Resuming an Analysis

`abort_analysis` with the `conversation_id` stops the current execution run. It is an interrupt, not a cancel: all conversation state survives, including groups already computed. Resume with a new `initiate_analysis` on the same `conversation_id` and the analysis continues from the aborted point, reusing prior results rather than restarting.

**The question you send on resume is the correction.** Interrupt-and-resume is how you steer an analysis mid-flight, rather than waiting for a wrong direction to run to completion and correcting afterwards.

Always abort when the user asks. On your own initiative, the bar is a contradiction with what the user asked for — not a difference from how you would have done it:

- The `interpretation` restates the question as something the user did not ask
- A `step_insight` shows it working from a premise the user's request rules out — a filter that excludes the population in question, a date range other than the one asked about
- The user has since said something that invalidates the direction

A plan that differs from the one you had in mind is not a misread. You handed over the goal because the analyst has context you lack, so an approach you would not have chosen is the expected case rather than a fault. Neither is a step whose purpose isn't obvious yet — the plan may need it later. When the analysis is merely slower or less direct than you would have been, let it finish.

### Explaining a Prior Analysis Step

When the user asks to explain, review, or drill into a specific step (e.g., "how was that calculated?", "explain the cuisine breakdown", "what happened in step 5"):

1. Identify the `step_id` from `monitor_analysis` progress messages (e.g. `"STEP/5"`)
2. Call `get_analysis_step_details` with `conversation_id` and `step_id`

Returns:
- The semantic query used (attributes, metrics, filters)
- Context resolved (which entities/fields Honeydew selected)
- Context items used (if any instructions or knowledge were applied)
- Data results from that step
- The SQL generated for that step

References in the response can be expanded for deeper inspection:
- Field references (e.g. `entity.field_name`) → `get_field` — shows the full definition, useful if the user wants to understand how a metric or attribute is calculated
- Context item references → `get_context_item` — shows the instruction or knowledge applied during that step

### Example Questions

**Simple natural language:**
- "What are the top 10 neighbourhoods by number of listings?"
- "Show me average price by room type."

**Complex analysis:**
- "Why did the average review score drop for listings in Brooklyn?"
- "What factors most influence listing price? Analyze the key drivers."
- "Compare superhost vs non-superhost performance across all metrics."
- "Identify unusual patterns in listing availability over the past year."
- "What are the characteristics of top-performing listings?"

**Step explanation (use `get_analysis_step_details`, not a new question):**
- "How was that calculated?"
- "Explain the cuisine breakdown."
- "Show me what happened in that step."
- "What fields were used there?"

---

## Delegating to a Subagent

A subagent does not inherit the skills you have loaded, and your brief outranks any skill it does load — so the brief is where its choice of path gets made. Put these in it:

1. "Load the `honeydew-ai:query` skill before any Honeydew work — you do not inherit mine. Add `honeydew-ai:model-exploration` if you will be discovering entities or fields."
2. "This task is [an investigation / a set of lookups]. For investigation, call `initiate_analysis` with agent `<name>` and hand it the goal, not a plan. For the lookups, the exact fields are given below."
3. If an analysis already exists: "Continue conversation `<conversation_id>` rather than starting a parallel investigation."

Name the agent yourself in point 2, looked up with `list_agents`: `initiate_analysis` needs either `agent` or `conversation_id`, and a brief supplying neither leaves the subagent to error on its first call.

Scope tool guidance per question rather than per subagent. A brief covering both a count and an investigation gets governed by whichever instruction it states, so say which applies to which question. Do not write "use structured queries for exact figures, deep analysis only if genuinely multi-step" — it inverts the default and gates the analysis path behind a judgement the subagent makes holding a field list and none of this skill.

---

## Browsing Past Analyses

### list_analysis_chats

Returns a paginated list of past analysis conversations for the current workspace, sorted newest first.

- Admins see all conversations; non-admins see only their own.
- Each entry includes: `conversation_id`, title, domain, agent, creation time, user feedback, and the display name of the user who created it.
- Use `limit` and `offset` for pagination.

```
list_analysis_chats(limit=20, offset=0)
```

Use this when the user asks to:
- "Show me my recent analyses"
- "Find the analysis I ran last week on revenue"
- "List all conversations in this workspace"

### get_stored_conversation

Returns all messages from a past analysis conversation. Use this to read the full content of a specific conversation identified via `list_analysis_chats`.

- `is_complete` in the response indicates whether the conversation reached a terminal state.
- `with_step_ids: false` (default) — returns only final responses and plan/interpretation messages. Use this for a readable summary.
- `with_step_ids: true` — also includes `step_start` and `step_insight` progress entries. Use this when you need to identify specific steps to pass to `get_analysis_step_details`.

```
get_stored_conversation(conversation_id="abc123")
get_stored_conversation(conversation_id="abc123", with_step_ids=true)
```

---

## Reviewing Past Query Executions

To review or inspect **queries that already ran** — what ran, from which client (BI tools, SQL interface, MCP, deep analysis), the semantic definition or compiled SQL behind a run, who ran it and when, and debugging failures — use `list_query_history` (from the `honeydew` MCP server). It lists queries previously executed through the semantic layer, most recent first, with each query's status, error message, owner, client, domain, timestamps, warehouse query ID, and a link to open it in the app.

This is a distinct workflow from querying data — see the dedicated **query-debugging** skill.

---

## Combining Methods

Methods chain in both directions.

**Discover → query → investigate** — explore the model, spot-check a field with a structured query, then hand the actual question to deep analysis.

**Investigate → query** — let deep analysis answer the question, then use the field names and filters it reports to run fast deterministic cuts of its result. See **Continuing Inside an Analysis** for which direction a given follow-up belongs in.

### Example Workflow

User: "Help me understand pricing patterns for Airbnb listings."

1. Orient: `list_entities` / `get_entity` → find `detailed_listings` and what it holds
2. Pick the analyst: `list_agents` → the agent whose domain covers listings
3. Hand over the goal: `initiate_analysis` → "What factors most influence listing price?" — show the user the `ui_url` it returns
4. Poll `monitor_analysis` and report progress as steps produce findings
5. Cut its result: `get_data_from_fields` with the fields the analysis reported → the exact numbers behind the driver it identified

Steps 1–2 orient you in the model; they do not turn the question into a lookup.

---

## Documentation Lookup

Use the `search_docs` and `query_docs_filesystem` tools from the `honeydew` MCP server to search the Honeydew documentation when:

- The user asks about query capabilities or features not covered in this skill
- You need to understand how the query API interacts with domains, parameters, or governance rules
- The user encounters unexpected query behavior and needs deeper context on how the semantic layer resolves queries

Search for topics like: "queries", "perspectives", "dynamic datasets", "parameters", "query API".

---

## Tip: Getting Distinct Values for a Field

To retrieve the distinct (unique) values of a field, include it in `attributes` and add a count metric in `metrics`.
Use the entity's built-in count metric (e.g., `entity.count`) if available, or an ad-hoc count metric using `COUNT(entity.field)`
on the field whose distinct values you want — never use `COUNT(*)`.
The metric forces aggregation, which groups by the attribute and returns one row per distinct value.

**Example — distinct room types:**

Call `get_data_from_fields` with:

- `attributes`: `["detailed_listings.room_type"]`
- `metrics`: `["COUNT(detailed_listings.room_type)"]`
- `order_by`: `["\"COUNT(detailed_listings.room_type)\" DESC"]`

This returns each unique `room_type` along with its count, ordered by frequency. The count is a useful bonus — it tells you how common each value is — but the key point is that the query returns **one row per distinct value**.

The count can also be filtered on. A breakdown by `detailed_listings.host_name` with `filters`: `["COUNT(detailed_listings.host_name) > 1"]` returns only the values occurring more than once — which is how you surface duplicates.

This pattern is useful for:

- **Exploring filter values** — find out what values exist before writing a filter expression (see the **filtering** skill)
- **Validating a new attribute** — after creating a calculated attribute, check its distinct output values to confirm the logic is correct (see the **attribute-creation** skill)
- **Understanding data distribution** — see how data is spread across categories

---

## Presenting Results

Present analysis results clearly — format tables, highlight key numbers, and surface what's notable, unexpected, or actionable.

If your environment has visualization tools, render visualizations when they would reveal patterns faster than text — e.g. trends, distributions, or ranked lists of 5+ items. Skip it for 2–3 numbers or a single yes/no conclusion. When it might help but isn't a clear win, offer rather than render.

---

## Best Practices

- **Use deep analysis for insight** — anything beyond a lookup goes to `initiate_analysis`: "why", "how", trends, drivers, or any question needing more than one query. Let the analysis engine plan the investigation instead of chaining structured queries by hand
- **Use structured queries for a settled specification** — when the fields and filters were given to you rather than chosen by you, `get_data_from_fields` executes them exactly and reproducibly
- **Discover before you query, not instead of delegating** — check `list_entities` / `get_entity` so you reference real fields; a field list in hand is not a reason to answer the question yourself
- **Delegate the goal, not the plan** — an over-specified question suppresses the semantic-layer context the analyst would otherwise load, and the steps you prescribe may be wrong precisely because you lack that context. Add precision in follow-ups
- **Stay in the conversation for reasoning, drop out for slices** — follow up when the next step needs reasoning or reuses groups the analysis already computed; use `get_data_from_fields` when you just need deterministic numbers
- **Report meaningful progress, not every step** — surface a one-liner when a step produces a substantive finding; skip internal retries and error-recovery steps the user doesn't need to see
- **Explain a prior step** — use `get_analysis_step_details` with the `step_id`; the response includes the semantic query, data results, and SQL for that step
- **Paginate large results** — use `limit` and `offset` in `get_data_from_fields` to avoid overwhelming output
- **Debug against the model, not the generated SQL** — to understand what a metric or attribute computes, read `get_field` / `get_entity`; the compiled SQL is long machine output and is rarely the shortest route to the answer
- **Reference fields correctly** — always use `entity.field_name` syntax in field parameters
