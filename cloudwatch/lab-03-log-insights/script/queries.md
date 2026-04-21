# CloudWatch Log Insights — Query Reference

Log group: `/aws/lambda/lab03-log-insights`

These queries can be run:
- **From the CLI** via `invoke-and-query.sh` (automated)
- **From the AWS Console** → CloudWatch → Log Insights → select the log group above

---

## Query 1 — Count by log level

**Goal:** See the distribution of INFO / WARNING / ERROR events at a glance.

```
fields level
| stats count() as total by level
| sort total desc
```

**How to read it:**
| Keyword | Role |
|---------|------|
| `fields` | Selects which JSON fields to expose |
| `stats count()` | Counts matching log events |
| `by level` | Groups the count by the value of the `level` field |
| `sort … desc` | Most frequent level first |

---

## Query 2 — ERROR events only

**Goal:** List every error with its context — useful for incident triage.

```
fields request_id, message, error_code, duration_ms
| filter level = "ERROR"
| sort @timestamp desc
| limit 10
```

**How to read it:**
| Keyword | Role |
|---------|------|
| `filter` | Keeps only log events where `level` equals `"ERROR"` |
| `@timestamp` | Built-in field added by CloudWatch (log ingestion time) |
| `sort @timestamp desc` | Most recent errors first |
| `limit 10` | Cap results — good practice to avoid huge result sets |

---

## Query 3 — Average duration per log level

**Goal:** Detect whether errors are slower than successful requests.

```
fields level, duration_ms
| stats avg(duration_ms) as avg_duration_ms by level
| sort avg_duration_ms desc
```

**How to read it:**
| Keyword | Role |
|---------|------|
| `stats avg(…)` | Computes the average of a numeric field |
| `as avg_duration_ms` | Renames the computed column for readability |
| `by level` | One row per distinct value of `level` |

---

## Log Insights syntax cheat sheet

```
fields <field1>, <field2>     # choose which fields to display
| filter <field> = "value"    # keep only matching events
| filter <field> like /regex/ # regex filter
| stats count() by <field>    # count / group
| stats avg(<field>) by <f>   # average / group
| stats sum(<field>) by <f>   # sum / group
| sort <field> desc           # sort
| limit <n>                   # cap number of results
```

**Built-in fields** (always available, added by CloudWatch):

| Field | Content |
|-------|---------|
| `@timestamp` | When the log event was ingested |
| `@message` | The raw log line |
| `@logStream` | The log stream name (one per Lambda instance) |
| `@requestId` | Lambda's own request ID (different from our `request_id`) |
