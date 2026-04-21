# lab-03-log-insights

## Objective

Centralise application logs in CloudWatch Logs and query them with Log Insights.
This lab is the closest to everyday enterprise usage: structured logging, retention policy, and analytical queries on real data.

---

## What this lab deploys

- **1 Lambda function** — `lab03-log-insights`, generates INFO / WARNING / ERROR logs in structured JSON
- **1 CloudWatch Log Group** — `/aws/lambda/lab03-log-insights`, retention set to 7 days
- **1 IAM Role + Policy** — least-privilege: only `CreateLogStream` and `PutLogEvents` on the specific log group

---

## What you learn

- The CloudWatch Logs hierarchy: **Log Group → Log Stream → Log Events**
- Why logging in structured JSON is better than free text — Log Insights parses fields directly, no regex needed
- Why `json.dumps()` is required when Lambda's `log_format = "JSON"` is enabled — without it, Python serialises the dict as a string, breaking JSON parsing
- The Log Insights syntax: `fields`, `filter`, `stats`, `sort`, `limit`
- Why a retention policy matters — without it, logs are kept indefinitely and costs accumulate silently
- Why `depends_on` is sometimes necessary — Terraform cannot infer behavioural dependencies (role attached before Lambda starts, log group exists before first log event)

---

## Architecture

```
Your machine                        AWS (eu-west-3)
─────────────────   ─────────────────────────────────────────────────────────
                  │
terraform apply ──┼──► IAM Role + Policy
                  │         │
                  │         ▼
                  │    Lambda function ──► CloudWatch Log Group
                  │    lab03-log-insights       /aws/lambda/lab03-log-insights
                  │                                    │
invoke-and-       │                             Log Streams (1 per instance)
query.sh      ────┼──► Lambda invoke                   │
                  │                             Log Events (1 JSON line per log)
                  │                                    │
              ────┼──► Log Insights queries ───────────┘
                  │
─────────────────   ─────────────────────────────────────────────────────────
```

---

## Structure

```
lab-03-log-insights/
├── README.md
├── script/
│   ├── index.py                  # Lambda handler — generates INFO / WARNING / ERROR logs
│   ├── invoke-and-query.sh       # Invokes Lambda 15×, then runs Log Insights queries
│   ├── log-insights-terraform.sh # terraform init + apply shortcut
│   ├── queries.md                # The 3 lab queries with explanations
│   └── queries-advanced.md       # Extended query reference (percentiles, error rates, timelines)
└── terraform/
    ├── cloudwatch.tf             # Log Group + 7-day retention
    ├── iam.tf                    # Role, policy, attachment
    ├── lambdas.tf                # Lambda function + archive_file zip
    ├── outputs.tf                # Function name, log group name, invoke command
    ├── providers.tf              # AWS provider (~> 5.0) + default_tags
    └── variables.tf              # region, environment, function_name
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configured (`aws configure`)
- [jq](https://jqlang.github.io/jq/download/) installed (used by `invoke-and-query.sh` to parse JSON responses)

> **Windows / Git Bash users:** Git Bash rewrites paths starting with `/aws/` as Windows paths.
> The `invoke-and-query.sh` script handles this with `MSYS_NO_PATHCONV=1` scoped to the affected command.

---

## Usage

### Step 1 — Deploy

```bash
bash script/log-insights-terraform.sh
```

Terraform creates 4 resources: the log group, the IAM role, the policy + attachment, and the Lambda function.

### Step 2 — Invoke and query

```bash
bash script/invoke-and-query.sh
```

The script:
1. Invokes the Lambda 15 times to generate log volume
2. Waits 10 seconds for CloudWatch ingestion
3. Runs 3 Log Insights queries and prints results in the terminal

### Step 3 — Explore in the console

**CloudWatch → Log groups → `/aws/lambda/lab03-log-insights`**

- Open a Log Stream to see raw JSON log events
- Go to **Log Insights**, select the log group, and run the queries from `queries.md`

---

## Verification

| Where | What to verify |
|---|---|
| Lambda → Functions | `lab03-log-insights` present |
| Lambda → Configuration → Permissions | IAM role attached, policy visible |
| CloudWatch → Log groups | `/aws/lambda/lab03-log-insights` with 7-day retention |
| CloudWatch → Log groups → Log streams | At least one stream after invocation |
| CloudWatch → Log Insights | Queries return results with `level`, `message`, `request_id` fields |

---

## Log Insights queries

Three queries are automated in `invoke-and-query.sh` and documented in `queries.md`.

**Distribution by log level:**
```
fields level
| stats count() as total by level
| sort total desc
```

**ERROR events only:**
```
fields request_id, message, error_code, duration_ms
| filter level = "ERROR"
| sort @timestamp desc
| limit 10
```

**Average duration per level:**
```
fields level, duration_ms
| stats avg(duration_ms) as avg_duration_ms by level
| sort avg_duration_ms desc
```

See `queries-advanced.md` for more: percentiles, error rates by service, slow requests, timeline analysis.

---

## Key concepts

### Log Group → Log Stream → Log Events

Every Lambda invocation writes to a **Log Stream** inside the **Log Group**. AWS creates one stream per Lambda instance — if Lambda scales to 3 instances in parallel, you get 3 streams simultaneously. Each `logger.info()` call produces one **Log Event**.

### Why structured JSON logging

Free-text logs require regex to extract fields in Log Insights. JSON lets you query fields directly:

```
# Free text — fragile
filter @message like /ERROR/

# Structured JSON — clean
filter level = "ERROR"
| stats avg(duration_ms) by level
```

### Why `json.dumps()` is required

When `log_format = "JSON"` is enabled, Lambda wraps every log entry in its own JSON envelope. The `message` field contains whatever you pass to `logger.info()`. Passing a Python dict directly produces a string representation (`"{'level': 'INFO', ...}"`), not valid JSON. `json.dumps()` produces a proper JSON string that Log Insights can parse as nested JSON.

### Why the retention policy matters

Without `retention_in_days`, CloudWatch keeps logs indefinitely. A Lambda invoked thousands of times per day accumulates significant log volume — and cost. Setting retention at deploy time guarantees it is in place from the first log event.

### Why `depends_on` is explicit

Terraform infers most dependencies from resource references, but two here are behavioural:
- The IAM policy must be **attached** (not just created) before Lambda starts — otherwise the first invocation fails with AccessDenied
- The log group must **exist** before the first log event — otherwise AWS creates it automatically but without the retention policy

---

## Cleanup

```bash
cd terraform/
terraform destroy -auto-approve
```

Verify in the console that the Lambda, log group, and IAM role have been removed.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Free tier |
|---|---|
| Lambda invocations | 1 000 000 / month free |
| CloudWatch Logs ingestion | 5 GB / month free |
| CloudWatch Log Insights queries | 5 GB scanned / month free |