# lab-02-sqs-lambda

## Objective

Understand SQS as a decoupling mechanism and connect it to Lambda as a consumer.
This lab introduces the visibility timeout, dead-letter queues, and batch processing — the foundations of reliable async processing in AWS.

---

## What this lab deploys

- **1 SQS Queue** — `lab02-queue`, the main message queue
- **1 SQS Dead Letter Queue** — `lab02-dlq`, receives messages that failed 3 times
- **1 Redrive Policy** — redirects failed messages from the main queue to the DLQ after 3 attempts
- **1 Lambda Function** — `lab02-consumer`, a Python consumer with intentional random failures (40%)
- **1 Event Source Mapping** — the AWS mechanism that polls SQS and triggers Lambda automatically
- **1 CloudWatch Log Group** — `/aws/lambda/lab02-consumer`, with 7-day retention

---

## What you learn

- The fundamental difference between SNS and SQS — SNS pushes immediately to subscribers, SQS stores messages until a consumer reads them
- The visibility timeout — when Lambda reads a message, it becomes invisible for X seconds; if Lambda fails, the message reappears and is retried
- The Dead Letter Queue — an essential safety net in production to avoid silently losing failed messages
- Batch processing — Lambda can receive multiple SQS messages per invocation, reducing cost and improving throughput
- The `ReportBatchItemFailures` pattern — only genuinely failed messages are retried, not the entire batch
- The difference between Standard queues (at-least-once delivery, no order guarantee) and FIFO queues (exactly-once, ordered) — see Key Concepts below

---

## Architecture

```
Your machine                         AWS (eu-west-3)
────────────────────   ──────────────────────────────────────────────────────────
                     │
terraform apply ─────┼──► SQS Queue (lab02-queue)
                     │         │  visibility_timeout = 30s
                     │         │  maxReceiveCount = 3
                     │         │
                     │         │  Event Source Mapping (automatic poll)
                     │         ▼
send_messages.py ────┼──► Lambda (lab02-consumer)
                     │         │
                     │         ├──► ✅ success → message deleted from queue
                     │         │
                     │         └──► ❌ failure → message reappears (up to 3x)
                     │                   │
                     │                   │ after 3 failures
                     │                   ▼
                     │         SQS DLQ (lab02-dlq)
                     │
────────────────────   ──────────────────────────────────────────────────────────
```

---

## Structure

```
lab-02-sqs-lambda/
├── README.md
├── script/
│   ├── handler.py                  # Lambda consumer — random failure simulation
│   ├── send_messages.py            # Sends a batch of 15 messages to the SQS queue
│   └── sqs-lambda-terraform.sh    # terraform init + apply shortcut
└── terraform/
    ├── cloudwatch.tf               # CloudWatch Log Group with retention policy
    ├── iam.tf                      # Lambda execution role and SQS permissions
    ├── lambda.tf                   # Lambda function and Event Source Mapping
    ├── outputs.tf                  # Queue URLs, ARNs, Lambda name, CloudWatch link
    ├── providers.tf                # AWS provider (~> 5.0), archive provider
    ├── sqs.tf                      # Main queue, DLQ, redrive policy
    └── variables.tf                # region, project_name, failure_rate, tags
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- AWS CLI configured (`aws configure`)
- Python >= 3.11 with `boto3` installed (`pip install boto3`)
- Permissions: `sqs:*`, `lambda:*`, `iam:*`, `logs:*`

---

## Usage

### Step 1 — Deploy

```bash
bash script/sqs-lambda-terraform.sh
```

Terraform creates 7 resources. Note the `main_queue_url` and `dlq_url` in the outputs.

### Step 2 — Send messages

```bash
python script/send_messages.py
```

Sends 15 messages to the main queue. The queue URL is retrieved automatically from Terraform outputs.

### Step 3 — Watch Lambda process the messages

Lambda is triggered automatically by the Event Source Mapping. Check the CloudWatch logs:

```bash
# On Windows, prefer PowerShell or the AWS Console
aws logs tail /aws/lambda/lab02-consumer --follow --region eu-west-3
```

Or go directly to the console: **CloudWatch → Log groups → /aws/lambda/lab02-consumer**

### Step 4 — Inspect the DLQ

Wait ~2 minutes for failed messages to exhaust their 3 retries and land in the DLQ.

```bash
# Count messages in the DLQ
aws sqs get-queue-attributes \
  --queue-url <dlq_url> \
  --attribute-names ApproximateNumberOfMessages \
  --region eu-west-3

# Read one failed message
aws sqs receive-message \
  --queue-url <dlq_url> \
  --max-number-of-messages 1 \
  --region eu-west-3
```

You will see the original JSON payload intact — nothing was lost.

---

## Verification

| Where | What to verify |
|---|---|
| SQS → Queues | `lab02-queue` and `lab02-dlq` present |
| SQS → lab02-queue → Dead-letter queue tab | DLQ configured with `maxReceiveCount = 3` |
| Lambda → lab02-consumer → Triggers | `lab02-queue` listed as event source |
| CloudWatch → Log groups | `/aws/lambda/lab02-consumer` present after first invocation |
| CloudWatch → Logs | Mix of `✅ processed` and `❌ failed` messages visible |
| SQS → lab02-dlq | Messages present after ~2 minutes (those that failed 3 times) |

---

## Key concepts

### SNS vs SQS — the fundamental difference

| | SNS | SQS |
|---|---|---|
| Model | Push — delivered immediately to subscribers | Pull — stored until a consumer reads it |
| Retention | None — lost if no subscriber | Up to 14 days |
| Consumers | Multiple simultaneous subscribers | One consumer per message |
| Typical use | Notifications, fan-out | Async work queues, decoupling |

Both are complementary — SNS → SQS is a classic pattern for fan-out with buffering.

### The visibility timeout

When Lambda reads a message, SQS makes it **invisible** for `visibility_timeout` seconds (30s here).
During that window, no other consumer can pick it up.

- Lambda **succeeds** → it deletes the message from the queue.
- Lambda **fails or times out** → the message reappears and is retried.

The `visibility_timeout` of the queue must always be **≥ the Lambda timeout**, otherwise a message can be retried while Lambda is still processing it.

### The Dead Letter Queue (DLQ)

An essential safety net in production. Without it:
- A poison pill message can loop forever and block processing.
- Failed messages silently disappear after their retention period.

With `maxReceiveCount = 3`, a message that fails 3 times is automatically moved to the DLQ where it can be inspected, fixed, and replayed manually.

### Batch processing and ReportBatchItemFailures

Lambda receives up to `batch_size` messages (5 here) per invocation. Without any special configuration, if **one** message in the batch fails, AWS retries **all** messages in the batch.

With `function_response_types = ["ReportBatchItemFailures"]`, Lambda returns only the IDs of failed messages — the rest are correctly deleted from the queue. This is the expected behavior in production.

### Standard vs FIFO queues

| | Standard | FIFO |
|---|---|---|
| Throughput | Nearly unlimited | 300 msg/s (3 000 with batching) |
| Ordering | Best-effort (not guaranteed) | Strict (First-In-First-Out) |
| Delivery | At-least-once (duplicates possible) | Exactly-once |
| Typical use | Parallel processing, order-independent tasks | Transactions, ordered workflows |

This lab uses a Standard queue — each message is independent and order does not matter.

---

## Cleanup

```bash
cd terraform/
terraform destroy -auto-approve
```

Verify in the console that both SQS queues and the Lambda function have been removed.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Free tier |
|---|---|
| SQS requests | 1 000 000 / month free |
| Lambda invocations | 1 000 000 / month free |
| Lambda compute | 400 000 GB-seconds / month free |
| CloudWatch Logs ingestion | 5 GB / month free |