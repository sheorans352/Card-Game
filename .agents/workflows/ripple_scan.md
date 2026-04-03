---
description: Rules for ensuring system-wide consistency during database schema or security changes.
---

# Ripple Scan Workflow

To prevent regressions and silent failures (like stale table references or blocked RPCs), follow these steps whenever a database table is renamed, an RLS policy is modified, or a column is added.

## 1. Codebase Scan (Flutter)
Always run a full recursive grep to find all string references to the table or column being modified.
// turbo
`grep -r "TABLE_NAME" lib/`

## 2. Database Function Scan (Postgres)
Identify and audit all RPCs that interact with the modified table. Use this query to find functions referencing a specific table.
// turbo
```sql
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_type = 'FUNCTION' 
AND routine_definition ILIKE '%TABLE_NAME%';
```

## 3. Security (RLS) Audit
Whenever an RLS policy is added or modified, verify if any RPC needs `SECURITY DEFINER` to bypass restrictions (common for server-side cleanup or multi-row deletions).

## 4. State Synchronization
Ensure that Flutter providers (Riverpod/Stream) are updated to watch the new table/column names simultaneously with the database change to avoid "Invisible Data" bugs.
