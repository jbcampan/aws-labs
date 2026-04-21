# CloudWatch Log Insights — Advanced Query Reference

Log group: `/aws/lambda/lab03-log-insights`

> **Note:** Some queries reference fields that do not exist in the current `index.py`
> (`endpoint`, `latency_ms`, `user_id`, `status_code`). They are included as a reference
> for more realistic Lambda functions you will build in future labs.

---

## Log Insights syntax primer

| Keyword  | Role                                          | SQL equivalent  |
|----------|-----------------------------------------------|-----------------|
| `fields` | Select which fields to display                | `SELECT`        |
| `filter` | Keep only matching log events                 | `WHERE`         |
| `stats`  | Aggregate: `count`, `avg`, `sum`, `min`, `max`, `pct` | `GROUP BY` |
| `sort`   | Order results                                 | `ORDER BY`      |
| `limit`  | Cap the number of results                     | `LIMIT`         |

**Filter operators:** `=` `!=` `<` `>` `<=` `>=` `like` `not like` `in` `not in`  
**Wildcards:** `*` (e.g. `"ERROR*"`)

---

## 1. Overview — all logs with their main fields

Useful for exploring data structure before writing more targeted queries.

```
fields @timestamp, level, message, service, endpoint, status_code, latency_ms
| sort @timestamp desc
| limit 50
```

---

## 2. Filter ERROR events only

Log Insights parses JSON fields automatically — filter directly on `level`.

```
fields @timestamp, level, message, service, endpoint, status_code, user_id, error_type
| filter level = "ERROR"
| sort @timestamp desc
| limit 100
```

---

## 3. Count logs by level — global distribution

```
stats count(*) as total by level
| sort total desc
```

---

## 4. Errors over time (5-minute buckets)

Useful to see whether errors arrive in spikes or continuously.  
`bin(5m)` groups events into 5-minute windows.

```
filter level = "ERROR"
| stats count(*) as error_count by bin(5m)
| sort @timestamp asc
```

---

## 5. Errors by service — which service is failing?

```
filter level = "ERROR"
| stats count(*) as errors by service
| sort errors desc
```

---

## 6. Latency by service — P50, P95, P99, and average

`pct()` is the real performance indicator, not just `avg()`.  
P99 at 3000ms means: 1% of requests take more than 3 seconds.

```
filter ispresent(latency_ms)
| stats
    avg(latency_ms)      as avg_ms,
    pct(latency_ms, 50)  as p50_ms,
    pct(latency_ms, 95)  as p95_ms,
    pct(latency_ms, 99)  as p99_ms,
    max(latency_ms)      as max_ms,
    count(*)             as requests
  by service
| sort p99_ms desc
```

---

## 7. Slow requests (above threshold)

Identifies requests over 2000ms — potential bottlenecks.

```
filter ispresent(latency_ms) and latency_ms > 2000
| fields @timestamp, service, endpoint, latency_ms, user_id, status_code
| sort latency_ms desc
| limit 20
```

---

## 8. Top endpoints by error volume

```
filter level = "ERROR" and ispresent(endpoint)
| stats count(*) as errors by endpoint
| sort errors desc
| limit 10
```

---

## 9. HTTP status code breakdown

```
filter ispresent(status_code)
| stats count(*) as occurrences by status_code
| sort occurrences desc
```

---

## 10. Error activity by user — who generates the most errors?

```
filter level = "ERROR" and ispresent(user_id)
| stats count(*) as errors by user_id
| sort errors desc
| limit 10
```

---

## 11. Error rate as a percentage by service

Computes `error_rate = errors / total * 100`.

```
filter ispresent(service)
| stats
    count(*) as total,
    sum(level = "ERROR") as errors
  by service
| fields service, total, errors, (errors / total * 100) as error_rate_pct
| sort error_rate_pct desc
```

---

## 12. Summary per Lambda invocation

Monitor the behaviour of each individual Lambda execution.

```
filter message = "Lambda invocation completed"
| fields @timestamp, aws_request_id, http_success, http_warnings, http_errors, total_logs_emitted
| sort @timestamp desc
| limit 20
```

---

## 13. Payment errors specifically

Field-level filtering on `message` — useful for business-specific events.

```
filter level = "ERROR" and message like "Payment"
| fields @timestamp, message, user_id, reason, amount_usd
| sort @timestamp desc
```

---

## 14. Full timeline — errors and warnings side by side

Combined view to detect correlations (warning spike before errors?).

```
filter level in ["ERROR", "WARNING"]
| stats
    sum(level = "ERROR")   as errors,
    sum(level = "WARNING") as warnings
  by bin(5m)
| sort @timestamp asc
```

---

## 15. Free-text search (like / not like)

Useful for exploring logs without knowing the exact field structure.

```
filter message like /failed/
| fields @timestamp, level, message, service, user_id
| sort @timestamp desc
| limit 30
```