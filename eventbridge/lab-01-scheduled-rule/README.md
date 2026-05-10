# lab-01-scheduled-rule

## Objective

Understand EventBridge as a modern scheduler — the serverless replacement for cron jobs.
A Lambda function wakes up automatically on a defined schedule, queries DynamoDB, and logs a report to CloudWatch. No server to maintain, no manual trigger, nothing to poll.

---

## What this lab deploys

- **1 DynamoDB Table** — `lab-01-scheduled-rule-items`, holds the sample items the Lambda reports on
- **1 Lambda Function** — `lab-01-scheduled-rule`, scans the table and logs a structured report
- **1 IAM Role** — least-privilege: DynamoDB read-only, CloudWatch Logs write
- **1 EventBridge Scheduled Rule** — `lab-01-scheduled-rule-rule`, fires every 5 minutes during the lab
- **1 Lambda Resource Policy** — allows EventBridge to invoke the Lambda function
- **1 CloudWatch Log Group** — `/aws/lambda/lab-01-scheduled-rule`, with 7-day retention

---

## What you learn

- **Rate vs cron expressions** — `rate(5 minutes)` for simple intervals, `cron(0 8 * * ? *)` for precise scheduling; AWS cron uses 6 fields and differs from Unix cron in key ways
- **EventBridge Rules vs EventBridge Scheduler** — the two coexisting services, when to use each, and why Scheduler adds exactly-once guarantees
- **Why EventBridge replaces a cron EC2 server** — no instance to maintain, automatic scaling, built-in retry
- **The disabled state** — best practice: disable a rule instead of destroying it when you want to pause temporarily
- **Permissions in two directions** — the IAM Role allows Lambda to read DynamoDB; the Resource Policy allows EventBridge to invoke Lambda; both are required

---

## Architecture

```
AWS (eu-west-3)
──────────────────────────────────────────────────────────────────
EventBridge Scheduled Rule
  rate(5 minutes)
        │
        │  Automatic invocation — no manual action required
        ▼
  Lambda Function
  lab-01-scheduled-rule
        │
        ├──► DynamoDB Table (lab-01-scheduled-rule-items)
        │         scan → item_count, sample_item
        │
        └──► CloudWatch Logs
                  /aws/lambda/lab-01-scheduled-rule
                  structured JSON report every 5 minutes
──────────────────────────────────────────────────────────────────
```

---

## Structure

```
lab-01-scheduled-rule/
├── README.md
├── .gitignore
├── script/
│   ├── report_handler.py               # Lambda function — DynamoDB scan and report
│   ├── seed_dynamodb.py                # Inserts sample items into the table
│   └── scheduled-rule-terraform.sh    # terraform init + apply shortcut
└── terraform/
    ├── cloudwatch.tf                   # CloudWatch Log Group + EventBridge Rule + Target
    ├── dynamodb.tf                     # DynamoDB table
    ├── iam.tf                          # Lambda execution role and inline policy
    ├── lambda.tf                       # Lambda function, packaging, resource policy
    ├── main.tf                         # account_id data source
    ├── outputs.tf                      # Resource names, ARNs, ready-to-use CLI commands
    ├── providers.tf                    # AWS provider (~> 5.0), archive provider
    └── variables.tf                    # region, project_name, schedule_expression, etc.
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- Python 3.x with `boto3` installed (`pip install boto3`)
- Permissions: `lambda:*`, `dynamodb:*`, `iam:*`, `logs:*`, `events:*`

---

## Usage

### Step 1 — Deploy

```bash
bash script/scheduled-rule-terraform.sh
```

Note the outputs — they contain ready-to-use CLI commands for logs, manual invocation, and disabling the rule.

### Step 2 — Seed the DynamoDB table

```bash
python3 script/seed_dynamodb.py
```

Verify in the AWS console: DynamoDB → Tables → `lab-01-scheduled-rule-items` → **Explore items**. You should see 3 items.

### Step 3 — Stream the logs

In a dedicated terminal, start tailing before the next invocation fires:

```bash
aws logs tail /aws/lambda/lab-01-scheduled-rule --follow --region eu-west-3
```

Within 5 minutes, you will see `Lambda déclenchée par EventBridge` followed by the JSON report — without any action on your part.

### Step 4 — Invoke manually

No need to wait between observations:

```bash
aws lambda invoke \
  --function-name lab-01-scheduled-rule \
  --region eu-west-3 \
  /tmp/response.json && cat /tmp/response.json
```

### Step 5 — Test the disabled state

```bash
# Disable the rule (without destroying it)
aws events disable-rule --name lab-01-scheduled-rule-rule --region eu-west-3
```

Wait 5–10 minutes and confirm in CloudWatch that no new automatic invocations appear. Manual invocation still works — the rule is paused, not the Lambda.

```bash
# Re-enable
aws events enable-rule --name lab-01-scheduled-rule-rule --region eu-west-3
```

### Step 6 — Switch to a production schedule

In `terraform/variables.tf` (or `terraform.tfvars`), update the schedule expression:

```hcl
schedule_expression = "cron(0 8 * * ? *)"
```

```bash
cd terraform && terraform apply
```

Check the EventBridge console to confirm the rule now shows the cron expression. No need to wait 24 hours — the goal is to see the config update and read the cron syntax in the AWS interface.

---

## Verification

| Where | What to verify |
|---|---|
| DynamoDB | Table `lab-01-scheduled-rule-items` present with 3 items |
| EventBridge → Rules | `lab-01-scheduled-rule-rule` present and `ENABLED` |
| EventBridge → Rule → Targets | Lambda listed as the target |
| EventBridge → Rule → Monitoring | Invocation count increases over time |
| Lambda → Configuration → Triggers | EventBridge listed as trigger source |
| Lambda → Configuration → Permissions → Resource policy | `AllowEventBridgeInvoke` statement present |
| CloudWatch → Log groups | `/aws/lambda/lab-01-scheduled-rule` present |
| CloudWatch → Logs | JSON report with `item_count` and `sample_item` visible |

---

## Key concepts

### Rate vs cron expressions

EventBridge supports two scheduling syntaxes:

```
rate(5 minutes)    # every 5 minutes — simple, no fixed anchor
rate(1 day)        # every 24 hours from rule creation time

cron(0 8 * * ? *)          # every day at 08:00 UTC
cron(0 8 ? * MON-FRI *)    # Monday to Friday at 08:00 UTC
cron(0/5 * * * ? *)        # every 5 minutes (cron form)
```

AWS cron uses **6 fields** — unlike the 5-field Unix cron standard:

```
cron(Minutes  Hours  Day-of-month  Month  Day-of-week  Year)
```

Key differences from Unix cron:

| | AWS cron | Unix cron |
|---|---|---|
| Fields | 6 (includes Year) | 5 |
| Day-of-week values | `SUN MON TUE WED THU FRI SAT` | `0–6` |
| Day conflict | Use `?` when specifying the other day field | Both can be set |
| Timezone | UTC only | System timezone |

### EventBridge Rules vs EventBridge Scheduler

AWS offers two separate services for scheduling — they coexist, and both remain relevant:

| | EventBridge Rules (scheduled) | EventBridge Scheduler |
|---|---|---|
| Launched | 2015 (as CloudWatch Events) | 2022 |
| Invocation guarantee | At-least-once | **Exactly-once** |
| One-time schedules | No | Yes |
| Timezone support | UTC only | Any IANA timezone |
| Native targets | ~30 | 270+ |
| This lab uses | ✅ | |

Use **EventBridge Scheduler** when exactly-once delivery matters (payments, single notifications), when you need one-time schedules, or when you want to target AWS services directly without a Lambda intermediary.

### The disabled state

A rule can be `ENABLED` or `DISABLED` without being destroyed. This preserves the full configuration — schedule expression, targets, retry policy — and allows instant reactivation.

```bash
aws events disable-rule --name <rule-name> --region eu-west-3
aws events enable-rule  --name <rule-name> --region eu-west-3
```

In Terraform, the equivalent is setting `rule_enabled = false` and running `apply`.
Use this pattern for maintenance windows, seasonal schedules, or debug pauses.

### Permissions in two directions

Two distinct permission layers are required and easy to confuse:

| Resource | Direction | Allows |
|---|---|---|
| IAM Role (`iam.tf`) | Lambda → DynamoDB / CloudWatch | Lambda can scan the table and write logs |
| Lambda Resource Policy (`lambda.tf`) | EventBridge → Lambda | EventBridge is allowed to invoke the function |

Without the Resource Policy, EventBridge receives a silent `Access Denied`. No error appears in EventBridge — the rule fires, the invocation is attempted, and nothing happens. This is one of the most common and hardest-to-debug misconfigurations in event-driven architectures.

---

## Cleanup

```bash
cd terraform/
terraform destroy
```

Verify in the console that the EventBridge rule, Lambda function, DynamoDB table, and CloudWatch log group are all gone.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Free tier |
|---|---|
| EventBridge Rules | 1 000 000 invocations / month free |
| Lambda invocations | 1 000 000 / month free |
| Lambda compute | 400 000 GB-seconds / month free |
| DynamoDB | 25 GB storage + 200 000 000 requests / month free |
| CloudWatch Logs ingestion | 5 GB / month free |