# lab-01-billing-alarm

## Objective

Set up a billing alarm on a real AWS account — ideally before touching anything else.
Short, immediately useful, and a perfect introduction to CloudWatch: metrics, thresholds, states, and actions.

---

## What this lab deploys

- **1 SNS Topic** — `billing-alerts`, the notification channel
- **1 SNS Email Subscription** — your address, confirmed manually after apply
- **1 CloudWatch Alarm** — watches `EstimatedCharges` in `AWS/Billing`, triggers at $50

---

## What you learn

- The anatomy of a CloudWatch alarm: metric → threshold → state (`OK` / `ALARM` / `INSUFFICIENT_DATA`) → action
- The concept of **namespace** and **dimensions**: `AWS/Billing` with `Currency=USD`
- The CloudWatch → SNS coupling pattern — reused in every monitoring lab that follows
- Why billing metrics are only available in `us-east-1` — a subtle but important constraint

---

## Architecture

```
AWS/Billing
EstimatedCharges          CloudWatch Alarm          SNS Topic            Your inbox
(Currency=USD)    ──►    billing-alarm ($50)  ──►  billing-alerts  ──►  alert email
                          state: OK / ALARM
```

---

## Structure

```
lab-01-billing-alarm/
├── terraform/
│   ├── main.tf                  # SNS topic, subscription, CloudWatch alarm
│   ├── variables.tf             # region (locked to us-east-1), alert_email
│   ├── outputs.tf               # SNS topic ARN, alarm name
│   ├── providers.tf             # AWS provider (~> 5.0)
│   ├── terraform.tfvars         # Your email address (not committed)
│   └── terraform.tfvars.example # Template to copy
└── script/
    └── billing-alarm-terraform.sh  # Init + apply shortcut
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configured (`aws configure`)
- Billing alerts enabled in your AWS account:
  Account → Billing & Cost Management → Billing preferences → **Receive Billing Alerts** ✓

> Without this preference enabled, CloudWatch will never receive `EstimatedCharges` data.

---

## Usage

### Step 1 — Set your email

```bash
# Copy the example file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your address
# terraform/terraform.tfvars
alert_email = "you@example.com"
```

### Step 2 — Deploy

```bash
bash script/billing-alarm-terraform.sh
# or manually:
cd terraform/
terraform init
terraform apply
```

### Step 3 — Confirm the subscription

AWS sends a confirmation email immediately after apply.
Open it and click **Confirm subscription** — the alarm will not fire until this is done.

---

## Verification

### Console checkpoints

| Where | What to verify |
|---|---|
| SNS → Topics | `billing-alerts` present |
| SNS → Topics → billing-alerts → Subscriptions | Status: **Confirmed** (not PendingConfirmation) |
| CloudWatch → Alarms → All alarms | `billing-alarm` visible, state: `OK` or `INSUFFICIENT_DATA` |

> Make sure the console is set to **us-east-1** (top right) — billing metrics do not exist in other regions.

### Test the alarm (optional)

To validate the full notification path without waiting for a real overage, temporarily lower the threshold:

```hcl
# terraform/main.tf
threshold = 0.01
```

Then re-apply:

```bash
terraform apply
```

CloudWatch evaluates the alarm at the next metric update (every 6–8 hours). Once the ALARM state is reached, you will receive an email. Reset the threshold to `50` and re-apply afterward.

---

## Key concepts

### `INSUFFICIENT_DATA` at startup

A freshly created alarm starts in `INSUFFICIENT_DATA` — CloudWatch has not yet received a data point to evaluate. This is normal. The alarm transitions to `OK` or `ALARM` after the first `EstimatedCharges` update (up to 8 hours).

`treat_missing_data = "notBreaching"` prevents false alerts during this window.

### Why `us-east-1` only

AWS publishes billing metrics exclusively to CloudWatch in `us-east-1`, regardless of where your resources run. The `region` variable includes a validation block that blocks any other value at plan time.

### Why `statistic = "Maximum"`

`EstimatedCharges` is a cumulative gauge — it only goes up within a billing period. `Maximum` captures the latest value accurately. `Average` would understate it by mixing old and new data points.

### Why `period = 21600` (6 hours)

AWS updates the `EstimatedCharges` metric every 6–8 hours. Using a shorter period would cause the alarm to evaluate against stale or missing data. 6 hours is the shortest meaningful evaluation window.

---

## Cleanup

```bash
cd terraform/
terraform destroy
```

Confirm in the console that the SNS topic and the CloudWatch alarm have been removed.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Cost |
|---|---|
| CloudWatch alarm × 1 | Free (10 alarms free permanently) |
| SNS email subscription | Free |