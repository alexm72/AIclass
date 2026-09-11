# Database Performance Tuning with Claude Code & MCP Servers

A guide for using Claude Code with MCP database servers to optimize SQL queries, generate indexes, and resolve performance issues.

---

## Installing the `optimize-sql-query` Skill

The `optimize-sql-query` skill automates the optimization workflow so Claude Code follows the full process (schema inspection, anti-pattern checks, index analysis, findings doc) every time — without the user having to prompt for each step.

### Prerequisites

- Claude Code installed and working
- At least one MCP database server configured (see Step 1 in Process Overview)

### Installation Steps

1. **Locate your Claude Code skills directory:**

   ```
   ~/.claude/skills/
   ```

   On Windows this is typically `C:\Users\<username>\.claude\skills\`.

   If the `skills` folder doesn't exist, create it:

   ```bash
   mkdir -p ~/.claude/skills
   ```

2. **Copy the skill folder** into the skills directory:

   ```bash
   cp -r optimize-sql-query ~/.claude/skills/
   ```

   The resulting structure should be:

   ```
   ~/.claude/skills/
     optimize-sql-query/
       SKILL.md
   ```

3. **Verify installation** — start a new Claude Code session and the skill should appear in the available skills list. You can confirm by asking Claude:

   ```
   What skills do you have available?
   ```

   You should see `optimize-sql-query` listed.

### That's It

No registration or configuration needed. Claude Code auto-discovers skills from the `~/.claude/skills/` directory. The skill triggers automatically when you mention query optimization, slow queries, index tuning, or database performance — or you can invoke it directly with `/optimize-sql-query`.

---

## Process Overview

### Step 1: Setup / Configure an MCP Server to the Target Database

Connect Claude Code to the database you're investigating by configuring an MCP server in your Claude Code settings.

- Each MCP server targets a specific database instance (e.g., `advalent_prod`, `cddr_ref`, `broker_dev`).
- Once configured, Claude Code can run queries, inspect schemas, describe tables, and get row counts directly against the target database.
- Confirm connectivity by asking Claude Code to list databases or describe a table before starting optimization work.

**Typical MCP tools available per server:**

| Tool | Purpose |
|------|---------|
| `list_databases` | Enumerate available databases on the server |
| `get_schema` | Retrieve the full schema (tables, columns, types) |
| `describe_table` | Get column details, keys, and indexes for a specific table |
| `get_table_row_count` | Check table cardinality (important for index decisions) |
| `execute_query` | Run SELECT queries and review execution plans |

### Step 2: Gather the SQL Query(s) Needing Optimization

Collect the problematic queries. Sources typically include:

- Application logs or APM tools showing slow queries
- SQL Server Profiler / Extended Events traces
- DBA-identified problem queries
- Developer-reported performance complaints

Provide the full query text to Claude Code along with any context you have (e.g., "this runs every 5 minutes and takes 30+ seconds," "this blocks other transactions").

### Step 3: Optimize with Claude Code via MCP Server

In Claude Code, with the MCP server connected, ask Claude to analyze and optimize the query. Claude will:

1. **Inspect the schema** — examine table structures, existing indexes, column types, and relationships.
2. **Check table cardinality** — understand row counts to inform index and join strategy.
3. **Analyze the query** — identify performance bottlenecks (missing indexes, implicit conversions, non-sargable predicates, unnecessary joins, etc.).
4. **Propose optimized SQL** — rewrite the query with improvements.
5. **Generate index recommendations** — suggest new indexes (with included columns where appropriate) that support the optimized query.
6. **Persist findings to a markdown file** — document the original query, analysis, optimized query, and index DDL in a reviewable format.

### Step 4: Review Findings & Iterate

Review the generated findings document. Determine if further optimization is needed:

- Are there additional queries that touch the same tables?
- Did the analysis surface schema-level concerns (e.g., missing foreign keys, data type mismatches)?
- Are there trade-offs between read and write performance from proposed indexes?

If more work is needed, repeat Step 3 with updated context or additional queries.

### Step 5: Create New Indexes

Execute the generated index DDL statements in the target database. Consider:

- Running in a maintenance window for large tables
- Using `ONLINE = ON` for SQL Server to avoid blocking
- Monitoring index creation progress on large tables

### Step 6: Validate & Baseline

Execute the optimized queries in SSMS or DBeaver to:

- **a)** Confirm the queries run correctly (correct results, no errors).
- **b)** Establish a baseline execution time for comparison against the original.

If either validation fails, return to Step 3 with the new information.

---

## Best Practices for Query Optimization with Claude Code & MCP Servers

### Providing Context to Claude Code

- **Always provide the full original query** — don't paraphrase or simplify. Claude needs exact SQL to analyze.
- **Include execution plan XML if available** — paste the actual execution plan from SSMS for the most targeted analysis.
- **State the problem clearly** — "This query takes 45 seconds and should take under 2" is better than "this is slow."
- **Mention the environment** — table sizes, SQL Server version, edition (Standard vs. Enterprise affects available features like online index builds and columnstore).
- **Share existing indexes** — Claude can check via MCP, but calling out known indexes saves a round trip.

### Query Analysis Approach

- **Ask Claude to check the schema first** — before optimizing, have Claude run `describe_table` and `get_table_row_count` on the relevant tables. This grounds the analysis in real data.
- **Request the execution plan** — ask Claude to run `SET STATISTICS IO ON` or examine the estimated execution plan to identify the most expensive operators.
- **Look for common anti-patterns:**
  - Non-sargable predicates (`WHERE YEAR(date_col) = 2024` instead of range predicates)
  - Implicit type conversions (e.g., comparing `VARCHAR` to `NVARCHAR`)
  - Functions on indexed columns in WHERE clauses
  - `SELECT *` when only specific columns are needed
  - Missing join predicates causing Cartesian products
  - Correlated subqueries that could be rewritten as JOINs or CTEs
  - Excessive use of `DISTINCT` masking a join issue
  - OR conditions that prevent index seeks

### Index Generation Best Practices

- **Follow the "narrow and targeted" principle** — create indexes that serve specific query patterns rather than wide, catch-all indexes.
- **Include columns strategically** — use `INCLUDE` to cover SELECT columns and avoid key lookups, but don't include everything.
- **Consider existing indexes before adding new ones** — a new index might be covered by widening an existing one. Redundant indexes waste storage and slow writes.
- **Be mindful of index maintenance overhead** — every index must be maintained on INSERT, UPDATE, and DELETE. High-write tables need fewer, more targeted indexes.
- **Check for overlapping indexes** — if a new index is a left-prefix of an existing one (or vice versa), consolidate.
- **Name indexes consistently** — use a convention like `IX_TableName_Column1_Column2` so they're self-documenting.
- **Consider filtered indexes** — for queries that always filter on a specific condition (e.g., `WHERE is_active = 1`), a filtered index can be smaller and faster.
- **Always generate the full DDL** — include `CREATE INDEX` statements with table name, key columns, included columns, and any filter predicates so they're ready to execute.

### Structuring the Findings Document

Ask Claude to produce a findings document with these sections:

```
## Query: [Short Description]

### Original Query
-- paste original SQL

### Analysis
- Schema observations
- Cardinality notes
- Identified bottlenecks
- Anti-patterns found

### Optimized Query
-- paste optimized SQL

### Index Recommendations
-- CREATE INDEX DDL statements

### Expected Impact
- What should improve and why

### Validation Notes
- Execution time before/after (fill in after Step 6)
```

### Iterative Optimization Tips

- **Start with the highest-impact query** — optimize the worst offender first; its indexes may help other queries too.
- **Re-analyze after adding indexes** — new indexes change the optimizer's plan choices. A query that was fine before might now benefit from the new index, or a previously recommended index might no longer be needed.
- **Batch related queries together** — if multiple queries hit the same tables, analyze them as a group so index recommendations account for all access patterns.
- **Track before/after metrics** — document execution times, logical reads, and plan changes. This builds the case for the work and catches regressions.

### Common Pitfalls to Avoid

| Pitfall | Why It Matters |
|---------|---------------|
| Adding indexes without checking existing ones | Creates redundant indexes that slow writes |
| Optimizing queries without knowing table sizes | A table scan on 100 rows is fine; on 10M rows it's not |
| Ignoring parameter sniffing | A query might be fast with one parameter value and slow with another — test with realistic values |
| Creating indexes on low-selectivity columns | An index on a `bit` column rarely helps |
| Not validating in the target environment | Dev and prod have different data distributions — always validate where it matters |
| Over-indexing | More indexes are not always better; balance read vs. write performance |

---

## Sample Prompts

These examples show what to type in Claude Code to kick off the optimization workflow. The `optimize-sql-query` skill triggers automatically — no special syntax needed beyond having an MCP server configured.

### Basic: Single Slow Query

```
I have a slow query against the cddr_prod database. It runs from our nightly ETL 
and takes about 3 minutes. Here's the query:

SELECT p.PatientId, p.LastName, p.FirstName, e.EncounterDate, e.Status
FROM Patient p
JOIN Encounter e ON p.PatientId = e.PatientId
WHERE e.EncounterDate >= '2024-01-01'
AND p.IsActive = 1
ORDER BY e.EncounterDate DESC

Can you optimize this and save the findings?
```

### With Execution Plan Context

Providing the execution plan from SSMS gives Claude the most targeted analysis.

```
This query against advalent_prod takes 45 seconds and runs every 10 minutes from 
our reporting service. The execution plan shows a clustered index scan on Claims 
(2.8M rows) and a hash match join. Here's the query:

[paste SQL]

Optimize this using the advalent_prod MCP server and generate any indexes that would help.
```

### Multiple Related Queries

When several slow queries hit the same tables, analyze them together so index recommendations account for all access patterns.

```
We have 3 queries hitting the same tables on broker_dev that are all slow. 
Can you analyze them together so the index recommendations cover all access patterns?

Query 1: [paste SQL]
Query 2: [paste SQL]  
Query 3: [paste SQL]
```

### Iterative Follow-Up

After reviewing a findings document and deciding more work is needed (Step 4 of the process).

```
The optimized query from optimization-claims-report.md is still doing a key lookup 
on the Claims table. Can you re-analyze and see if we need to widen the index 
to cover the SELECT columns?
```

### Index-Only Analysis

When the query itself is fine but you suspect missing indexes.

```
I don't need the query rewritten, but can you look at this query against hrpdw_prod 
and tell me what indexes would help? Check what already exists first.

[paste SQL]
```

### Recording Validation Results

After running the optimized query in SSMS/DBeaver (Step 6), update the findings doc with actual numbers.

```
I ran the optimized query from our last session in SSMS. It went from 45 seconds 
to 3 seconds. Can you update the findings doc with those numbers?
```

### Tips for Writing Effective Prompts

- **Always name the MCP server** — Claude needs to know which one to connect to (e.g., `advalent_prod`, `cddr_ref`, `broker_dev`)
- **Paste the full query** — don't summarize or truncate it
- **Include timing and context** — "takes 30 seconds," "runs every 5 minutes," "blocks other transactions" helps Claude prioritize what to fix
- **Execution plan XML is gold** — if you can grab it from SSMS, paste it in for the most precise analysis

---

## Quick Reference: MCP Server Commands in Claude Code

When working with a connected MCP server, you can ask Claude to:

- `"List all databases on the [server] MCP server"`
- `"Describe the [table_name] table"`
- `"How many rows are in [table_name]?"`
- `"Run this query: SELECT ..."`
- `"Show me the existing indexes on [table_name]"`
- `"Get the schema for [database_name]"`

These map to the MCP tools (`list_databases`, `describe_table`, `get_table_row_count`, `execute_query`, `get_schema`) and let Claude ground its analysis in the actual database state.
