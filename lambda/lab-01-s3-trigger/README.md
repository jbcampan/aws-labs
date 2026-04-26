# lab-01-s3-trigger

## Objective

Understand Lambda's event-driven model through a concrete use case — a file uploaded to S3 automatically triggers a processing pipeline.
This is the most classic and pedagogical Lambda pattern: no server running permanently, no polling, just a function that wakes up on demand.

---

## What this lab deploys

- **1 S3 Source Bucket** — `lab01-source-<account_id>`, receives the raw CSV files
- **1 S3 Destination Bucket** — `lab01-destination-<account_id>`, receives the transformed JSON files
- **1 Lambda Function** — `lab01-processor`, reads the CSV, transforms it, writes the JSON
- **1 IAM Role** — least-privilege: read on the source bucket, write on the destination bucket, CloudWatch logs
- **1 S3 Event Notification** — triggers the Lambda on every upload under `uploads/*.csv`
- **1 Lambda Resource Policy** — allows S3 to invoke the Lambda function
- **1 CloudWatch Log Group** — `/aws/lambda/lab01-processor`, with 7-day retention

---

## What you learn

- The event-driven model — Lambda does not run permanently; it is instantiated on demand by an event
- The S3 event object — how to extract the bucket name and object key from the event passed to Lambda
- The cold start — the first invocation is slower because AWS must instantiate the Python container; observable in CloudWatch logs via `Init Duration`
- Permissions in two directions — the IAM Role allows Lambda to access S3, but a separate Resource Policy on the Lambda allows S3 to invoke it; missing either one silently breaks the pipeline
- Good practice — never hardcode bucket names in code; pass them as Lambda environment variables

---

## Architecture

```
You                              AWS (eu-west-3)
─────────────────   ──────────────────────────────────────────────────────────
                  │
terraform apply ──┼──► S3 Source Bucket (lab01-source-<account_id>)
                  │         │  filter: uploads/*.csv
                  │         │  S3 Event Notification
                  │         ▼
aws s3 cp ────────┼──► Lambda (lab01-processor)
                  │         │  reads CSV from source
                  │         │  filters inactive rows
                  │         │  transforms → JSON
                  │         ▼
                  │    S3 Destination Bucket (lab01-destination-<account_id>)
                  │         processed/sample.json
                  │
                  │    CloudWatch Logs
                  │         /aws/lambda/lab01-processor
─────────────────   ──────────────────────────────────────────────────────────
```

---

## Structure

```
lab-01-s3-trigger/
├── README.md
├── script/
│   ├── handler.py                  # Lambda function — CSV to JSON transformation
│   ├── sample.csv                  # Test file with active/inactive rows
│   └── s3-trigger-terraform.sh    # terraform init + apply shortcut
└── terraform/
    ├── cloudwatch.tf               # CloudWatch Log Group with 7-day retention
    ├── iam.tf                      # Lambda execution role and S3 permissions
    ├── lambda.tf                   # Lambda function, packaging, and resource policy
    ├── main.tf                     # account_id data source and common tags
    ├── outputs.tf                  # Bucket names, Lambda name, ready-to-use CLI commands
    ├── providers.tf                # AWS provider (~> 5.0), archive provider
    ├── s3.tf                       # Source bucket, destination bucket, event notification
    └── variables.tf                # region, project_name
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- Permissions: `s3:*`, `lambda:*`, `iam:*`, `logs:*`

---

## Usage

### Step 1 — Deploy

```bash
bash script/s3-trigger-terraform.sh
```

Terraform creates 9 resources. Note the `upload_command` and `watch_logs_command` in the outputs — they are ready to copy-paste.

### Step 2 — Open the logs

In a dedicated terminal, start tailing the logs before uploading anything:

```bash
aws logs tail /aws/lambda/lab01-processor --follow --region eu-west-3
```

### Step 3 — Upload the test CSV

In a second terminal, from the `script/` directory:

```bash
aws s3 cp sample.csv s3://<source_bucket>/uploads/sample.csv
```

The Lambda triggers automatically within a few seconds.

### Step 4 — Verify the output

```bash
aws s3 cp s3://<destination_bucket>/processed/sample.json - | python3 -m json.tool
```

You should see 4 entries — the 2 inactive rows (`active: false`) have been filtered out, and names are Title Cased.

---

## Verification

| Where | What to verify |
|---|---|
| S3 | Both buckets `lab01-source-...` and `lab01-destination-...` present |
| Lambda → lab01-processor → Configuration → Triggers | S3 listed as trigger |
| Lambda → Configuration → Environment variables | `DEST_BUCKET` present |
| Lambda → Configuration → Permissions | IAM role attached |
| CloudWatch → Log groups | `/aws/lambda/lab01-processor` present after first invocation |
| CloudWatch → Logs | `File received`, `Transformed file written`, `Init Duration` visible |
| S3 destination | `processed/sample.json` present with 4 entries |

---

## Key concepts

### The S3 event object

When S3 triggers Lambda, it passes a JSON payload describing what happened:

```json
{
  "Records": [{
    "eventName": "ObjectCreated:Put",
    "s3": {
      "bucket": { "name": "lab01-source-595949105416" },
      "object": { "key": "uploads/sample.csv" }
    }
  }]
}
```

The Lambda function extracts `bucket.name` and `object.key` from this structure — it has no other way of knowing which file triggered it.

### The cold start

On the first invocation, CloudWatch reports an extra line:

```
REPORT  Duration: 565 ms  Billed Duration: 1060 ms  Init Duration: 493 ms
```

`Init Duration` is the time AWS needed to spin up the Python container before running any code. Upload the CSV a second time within a few minutes — `Init Duration` disappears. The container is already warm.

### Permissions in two directions

Two distinct permission layers are required and are easy to confuse:

| Resource | Direction | Allows |
|---|---|---|
| IAM Role | Lambda → S3 | Lambda can read the source bucket and write to the destination |
| Lambda Resource Policy | S3 → Lambda | S3 is allowed to invoke the Lambda function |

Without the Resource Policy, S3 receives a silent `Access Denied` when attempting to invoke Lambda. No log appears, no error is raised on the S3 side — the pipeline simply does nothing.

### Environment variables over hardcoded values

The destination bucket name is passed to Lambda via an environment variable (`DEST_BUCKET`), set by Terraform at deploy time. This means the same code works in any environment without modification — a fundamental best practice.

---

## Cleanup

```bash
cd terraform/
terraform destroy
```

Both buckets are destroyed along with their contents (`force_destroy = true`). Verify in the console that the buckets and Lambda function are gone.

---

## Cost

$0 — this lab runs entirely within the AWS free tier.

| Resource | Free tier |
|---|---|
| S3 storage | 5 GB / month free |
| S3 requests | 20 000 GET + 2 000 PUT / month free |
| Lambda invocations | 1 000 000 / month free |
| Lambda compute | 400 000 GB-seconds / month free |
| CloudWatch Logs ingestion | 5 GB / month free |