# aws-labs

A progressive, hands-on collection of AWS labs built for learning and employability. Each lab focuses on a specific service or concept, implemented with minimal but realistic configurations.

## Goal

Work through AWS services systematically — from identity and networking fundamentals to serverless and containers — using the tools actually used in production environments.

## Tools used

| Tool | Usage |
|------|-------|
| **Terraform** | Primary IaC tool for all labs |
| **Python (boto3)** | When programmatic logic adds value (loops, parsing, SDK calls) |
| **Bash / AWS CLI** | One-liners, quick validations, diagnostic commands |

## Cost

Labs are designed to stay within a minimal AWS budget. All resources should be destroyed with `terraform destroy` after each lab. Estimated total cost across the full curriculum: **< $20**.

A billing alarm is set up in the first CloudWatch lab as a safety net.

---

## Curriculum

### ✅ S3 — Simple Storage Service
> Bucket creation, deletion, listing, static website hosting. Implemented in Bash, Python, CloudFormation and Terraform.

| Lab | Description |
|-----|-------------|
| create-bucket | Create an S3 bucket |
| delete-bucket | Delete an S3 bucket |
| list-buckets | List all buckets in an account |
| website | Host a static website on S3 |

---

### 1 — IAM — Identity and Access Management
> Users, groups, roles, policies, instance profiles. The foundation everything else depends on.

| Lab | Description |
|-----|-------------|
| lab-01-users-groups | Create IAM users and groups, attach managed policies |
| lab-02-roles-policies | Write least-privilege custom policies, assume a role with STS |
| lab-03-instance-profile | Attach an IAM role to an EC2 instance, access S3 without hardcoded credentials |

---

### 2 — VPC — Virtual Private Cloud
> Networking fundamentals: subnets, route tables, internet gateway, security groups, peering.

| Lab | Description |
|-----|-------------|
| lab-01-vpc-standard | VPC with public and private subnets, IGW, route tables |
| lab-02-security-groups | Stateful firewall rules, SG-to-SG references |
| lab-03-vpc-peering | Connect two VPCs, cross-VPC routing |

> ⚠️ After these labs, Terraform reusable modules are extracted into `_modules/vpc/` and `_modules/security-groups/`.

---

### 3 — EC2 — Elastic Compute Cloud
> Instances, AMIs, user data, Auto Scaling Groups. Builds directly on IAM and VPC.

| Lab | Description |
|-----|-------------|
| lab-01-instance-ssm | Instance in private subnet, access via SSM Session Manager (no SSH) |
| lab-02-custom-ami | Custom AMI with user data (nginx at boot), cross-region copy |
| lab-03-asg | Auto Scaling Group with Launch Template, CPU-based scaling policy, ALB |

---

### 4 — CloudWatch — Monitoring and Observability
> Alarms, metrics, dashboards, logs. Applied immediately to what was built in EC2.

| Lab | Description |
|-----|-------------|
| lab-01-billing-alarm | Billing alarm with SNS email notification |
| lab-02-metrics-dashboard | CloudWatch Agent, custom metrics (RAM, disk), dashboard |
| lab-03-log-insights | Structured JSON logs from Lambda, Log Insights queries |

---

### 5 — SNS + SQS — Messaging
> Pub/sub and queue-based decoupling. Short to set up, essential to understand.

| Lab | Description |
|-----|-------------|
| lab-01-sns-email | SNS topic, email and SQS subscriptions, fan-out pattern |
| lab-02-sqs-lambda | SQS queue, Dead Letter Queue, Lambda consumer, batch processing |

---

### 6 — Lambda — Serverless Functions
> Event-driven compute. Three distinct contexts: file processing, API backend, VPC access.

| Lab | Description |
|-----|-------------|
| lab-01-s3-trigger | Lambda triggered by S3 upload, CSV transformation |
| lab-02-api-rest | REST API with API Gateway + Lambda + DynamoDB (full CRUD) |
| lab-03-vpc-access | Lambda inside a VPC, private RDS access, connection reuse pattern |

---

### 7 — EventBridge — Event Bus
> Scheduled rules and event-driven reactions to AWS service events.

| Lab | Description |
|-----|-------------|
| lab-01-scheduled-rule | Cron-triggered Lambda, rate and cron expression syntax |
| lab-02-event-driven | React to EC2 state changes and IAM login failures in real time |

---

### 8 — RDS — Relational Database Service
> Managed relational databases: deployment, access control, backup and restore.

| Lab | Description |
|-----|-------------|
| lab-01-instance-privee | RDS MySQL in private subnet, access via EC2, Secrets Manager |
| lab-02-snapshot-restore | Manual snapshot, restore to new instance, Point-in-Time Recovery |

---

### 9 — ECS / Fargate — Containers
> Serverless container deployment. From a single task to a production-grade setup with ALB and auto-scaling.

| Lab | Description |
|-----|-------------|
| lab-01-fargate-simple | Docker image on ECR, ECS Cluster, Task Definition, Service |
| lab-02-fargate-alb | ALB, private subnets, rolling updates, Application Auto Scaling |

---

### 10 — Step Functions — Orchestration *(optional)*
> Coordinate multiple Lambda functions into a structured workflow with branching and error handling.

| Lab | Description |
|-----|-------------|
| lab-01-orchestration-lambda | Order processing state machine: Choice, Retry, Catch, Parallel states |

---

## Repository structure

```
aws-labs/
├── _modules/                    # Reusable Terraform modules (extracted after VPC labs)
│   ├── vpc/
│   └── security-groups/
│
├── s3/                          # Done ✓
│
├── iam/
│   └── lab-01-users-groups/
│       ├── terraform/
│       ├── scripts/
│       └── README.md
│
├── vpc/
├── ec2/
├── cloudwatch/
├── sns-sqs/
├── lambda/
├── eventbridge/
├── rds/
├── ecs/
└── step-functions/
```

Each lab follows the same structure:

```
lab-XX-name/
├── terraform/        # Infrastructure as Code
├── scripts/          # Python or Bash scripts when relevant
└── README.md         # Lab objectives, architecture, instructions, cleanup
```

## How to use

Each lab is self-contained. The general workflow is:

```bash
cd <service>/lab-XX-name/terraform
terraform init
terraform plan
terraform apply

# ... do the lab ...

terraform destroy
```

Refer to each lab's `README.md` for prerequisites, step-by-step instructions, and what to observe.

## Prerequisites

- AWS account with credentials configured (`aws configure`)
- Terraform >= 1.5
- Python >= 3.10 with boto3 (`pip install boto3`)
- Docker (for ECS labs)
- AWS CLI v2