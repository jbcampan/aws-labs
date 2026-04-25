# lab-01-sns-email

## Objective

Understand SNS in its simplest form — a message published to a topic is distributed to all subscribers simultaneously.
This lab introduces the pub/sub model and the fan-out pattern before going further with SQS.

---

## What this lab deploys

- **1 SNS Topic** — `lab01-fanout-topic`, the central pub/sub bus
- **1 SQS Queue** — `lab01-fanout-queue`, subscriber #1
- **1 SQS Queue Policy** — allows SNS to write into the queue
- **2 SNS Subscriptions** — one email, one SQS (fan-out to both simultaneously)

---

## What you learn

- The pub/sub model — the publisher doesn't know who's listening, subscribers don't know who's publishing
- The fan-out pattern — one `sns.publish()` call delivers to N subscribers of different types simultaneously
- The difference between SNS (push, real-time, no retention) and SQS (pull, retention, explicit acknowledgement)
- Why the SQS queue policy is required — without it, SNS silently fails to write to the queue
- The email subscription confirmation — AWS sends a confirmation email before activating the subscription

---

## Architecture

```
Your machine                        AWS (eu-west-3)
─────────────────   ─────────────────────────────────────────────────────────
                  │
terraform apply ──┼──► SNS Topic (lab01-fanout-topic)
                  │         │
                  │         ├──► Email subscription ──► 📧 your inbox
                  │         │
                  │         └──► SQS subscription  ──► 📬 lab01-fanout-queue
                  │
run.sh publish ───┼──► sns.publish()
                  │         │
                  │         └──► fan-out: email + SQS simultaneously
                  │
run.sh read ──────┼──► sqs.receive_message()
                  │
─────────────────   ─────────────────────────────────────────────────────────
```

---

## Structure

```
lab-01-sns-email/
├── README.md
├── script/
│   ├── publish.py                # Publishes a message to the SNS topic
│   ├── read_sqs.py               # Reads a message from the SQS queue
│   ├── run.sh                    # Entrypoint — exports env vars, routes to publish or read
│   └── sns-email-terraform.sh   # terraform init + apply shortcut
└── terraform/
    ├── main.tf                   # SNS topic, SQS queue, queue policy, subscriptions
    ├── outputs.tf                # Topic ARN, queue URL, queue ARN, next steps
    ├── providers.tf              # AWS provider (~> 5.0), required version
    ├── terraform.tfvars.example  # Variable template (copy to terraform.tfvars)
    └── variables.tf              # region, email_address
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- Python >= 3.11 with `boto3` installed (`pip install boto3`)
- Permissions: `sns:*`, `sqs:*`

---

## Usage

### Step 1 — Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars and set your email address
```

### Step 2 — Deploy

```bash
bash script/sns-email-terraform.sh
```

Terraform creates 4 resources: the SNS topic, the SQS queue, the queue policy, and both subscriptions.

### Step 3 — Confirm the email subscription

AWS sends a *"AWS Notification - Subscription Confirmation"* email to your address.
**Click the confirmation link** — the subscription stays in `PendingConfirmation` until you do.

Verify in the console: **SNS → Topics → lab01-fanout-topic → Subscriptions** — status should switch to `Confirmed`.

### Step 4 — Publish and read

```bash
bash script/run.sh publish   # Publishes a message to the SNS topic
bash script/run.sh read      # Reads the message from the SQS queue
```

---

## Verification

| Where | What to verify |
|---|---|
| SNS → Topics | `lab01-fanout-topic` present |
| SNS → Topics → Subscriptions | 2 subscriptions — email `Confirmed`, SQS `Confirmed` |
| SQS → Queues | `lab01-fanout-queue` present |
| Your inbox | Message received after `run.sh publish` |
| Terminal | Message body printed after `run.sh read` |

---

## Key concepts

### The pub/sub model

The publisher (`publish.py`) sends to the topic without knowing who's listening.
Subscribers (email, SQS) receive without knowing who published.
Adding a new subscriber requires no change to the publisher — that's the decoupling.

### Fan-out

One `sns.publish()` call delivers to all subscribers simultaneously.
Email and SQS receive the same message at the same time, through different protocols.

### SNS vs SQS

| | SNS | SQS |
|---|---|---|
| Delivery | Push (real-time) | Pull (on demand) |
| Retention | None — message lost if no subscriber | Up to 14 days |
| Acknowledgement | Not required | Explicit (`delete_message`) |

### Why the SQS queue policy is required

SNS needs explicit permission to call `sqs:SendMessage` on the queue.
Without the policy, SNS silently drops the message — no error, no delivery.

### SNS message envelope in SQS

When `raw_message_delivery = false` (default), SNS wraps your message in a JSON envelope:

```json
{
  "Type": "Notification",
  "TopicArn": "arn:aws:sns:...",
  "Subject": "Test SNS",
  "Message": "Hello from my first SNS message!",
  "Timestamp": "2024-01-15T10:30:00.000Z"
}
```

`read_sqs.py` parses this envelope and prints both the raw body and the inner message.

---

## Cleanup

```bash
cd terraform/
terraform destroy -auto-approve
```

Verify in the console that the SNS topic, SQS queue, and both subscriptions have been removed.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Free tier |
|---|---|
| SNS email notifications | 1 000 / month free |
| SNS API requests | 1 000 000 / month free |
| SQS requests | 1 000 000 / month free |