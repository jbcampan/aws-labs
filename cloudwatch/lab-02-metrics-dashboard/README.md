# lab-02-metrics-dashboard

## Objective

Deploy a CloudWatch dashboard with meaningful EC2 metrics — and understand the fundamental difference between basic and detailed monitoring.
Introduces the CloudWatch Agent, custom metric namespaces, and alarm design on real infrastructure.

---

## What this lab deploys

- **1 EC2 instance** — `t3.micro`, Amazon Linux 2023, with the CloudWatch Agent installed via user data
- **1 SSM Parameter** — stores the agent JSON config, readable by the instance at boot
- **1 CloudWatch Dashboard** — `lab02-metrics-dashboard`, with 8 widgets across native and custom metrics
- **1 SNS Topic** — `lab02-alerts`, the notification channel
- **1 SNS Email Subscription** — your address, confirmed manually after apply
- **2 CloudWatch Alarms** — CPU > 80% and RAM > 85%, both notifying the SNS topic

---

## What you learn

- Why AWS does not provide RAM metrics natively — the hypervisor cannot see inside the guest OS (classic interview question)
- How to install and configure the CloudWatch Agent via a JSON config stored in SSM Parameter Store
- The difference between **basic monitoring** (5-minute granularity, free) and **detailed monitoring** (1-minute granularity, paid)
- The distinction between native metrics (`AWS/EC2` namespace) and custom metrics (`Lab02/EC2` namespace)
- How to build a useful dashboard rather than a default one

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        EC2 t2.micro                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           CloudWatch Agent                           │   │
│  │  Collecte : RAM, disk %, CPU détaillé, processus     │   │
│  │  Namespace : Lab02/EC2                               │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                       │
└─────────────────────┼───────────────────────────────────────┘
                      │ métriques custom
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    CloudWatch                               │
│                                                             │
│  Métriques natives (AWS/EC2) :     Métriques custom :       │
│  ├── CPUUtilization                ├── mem_used_percent     │
│  ├── NetworkIn / NetworkOut        ├── mem_available        │
│  ├── DiskReadBytes                 ├── disk_used_percent    │
│  └── DiskWriteBytes                └── processes_*          │
│                                                             │
│  Dashboard : lab02-metrics-dashboard                        │
│  Alarmes   : cpu-high (>80%), ram-high (>85%)               │
└─────────────────────────────────────────────────────────────┘
                      │ alarmes SNS
                      ▼
            SNS Topic (lab-01) → Email
```

---

## Structure

```
lab-02-metrics-dashboard/
├── terraform/
│   ├── cloudwatch.tf            # Dashboard, alarms, SNS topic and subscription
│   ├── data.tf                  # AMI, default VPC and subnets
│   ├── ec2.tf                   # EC2 instance, SSM parameter, agent config
│   ├── iam.tf                   # IAM role, policies, instance profile
│   ├── outputs.tf               # Instance ID, dashboard URL, SSM commands
│   ├── providers.tf             # AWS provider (~> 5.0)
│   ├── security-groups.tf       # Outbound-only SG (SSM, no SSH)
│   ├── variables.tf             # region, instance_type, alert_email
│   ├── terraform.tfvars         # Your email address (not committed)
│   └── terraform.tfvars.example # Template to copy
└── script/
    ├── cloudwatch-agent.sh      # User data: installs and starts the agent
    ├── metrics-dashboard.sh     # Init + apply shortcut
    └── stress-test.sh           # Generates CPU/RAM/disk load to trigger alarms
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS CLI configured (`aws configure`)
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) installed (for SSM console access without SSH)

---

## Usage

### Step 1 — Set your email

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# terraform/terraform.tfvars
alert_email = "you@example.com"
```

### Step 2 — Deploy

```bash
bash script/metrics-dashboard.sh
# or manually:
cd terraform/
terraform init
terraform apply
```

### Step 3 — Confirm the subscription

AWS sends a confirmation email immediately after apply.
Click **Confirm subscription** — alarms will not notify until this is done.

### Step 4 — Open the dashboard

```bash
terraform output dashboard_url
```

Wait 5–10 minutes after deploy for the first metrics to appear.

---

## Verification

### Console checkpoints

| Where | What to verify |
|---|---|
| EC2 → Instances | `lab02-metrics-instance` running |
| SSM → Session Manager | Instance reachable (no SSH needed) |
| CloudWatch → Metrics → AWS/EC2 | `CPUUtilization`, `NetworkIn`, `NetworkOut` visible |
| CloudWatch → Metrics → Custom → Lab02/EC2 | `mem_used_percent`, `disk_used_percent` visible |
| CloudWatch → Dashboards | `lab02-metrics-dashboard` populated |
| CloudWatch → Alarms | `lab02-cpu-high` and `lab02-ram-high` in `OK` state |

### Verify the agent on the instance

```bash
# Connect without SSH
aws ssm start-session --target $(terraform output -raw instance_id) --region eu-west-3

# On the instance:
systemctl status amazon-cloudwatch-agent
cat /var/log/user-data.log
```

### Trigger the alarms

```bash
# CPU spike — triggers cpu-high after ~10 min (2 × 5-min periods)
bash script/stress-test.sh cpu 360

# RAM pressure — triggers ram-high after ~3 min (3 × 1-min periods)
bash script/stress-test.sh ram 180
```

---

## Key concepts

### Why RAM is not a native EC2 metric

AWS runs instances on a hypervisor (Nitro). The hypervisor can observe CPU cycles, network throughput, and EBS I/O — all traffic that crosses the hardware boundary. It cannot see what happens inside the guest OS: how much RAM the kernel has allocated, what the filesystem usage looks like, or how many processes are running. The CloudWatch Agent runs inside the OS and bridges that gap.

### Basic vs. detailed monitoring

| | Basic | Detailed |
|---|---|---|
| Granularity | 5 minutes | 1 minute |
| Cost | Free | ~$3.50/instance/month |
| Activation | Default | `monitoring = true` in Terraform |

### Native vs. custom metrics

| Namespace | Source | Examples |
|---|---|---|
| `AWS/EC2` | AWS hypervisor | `CPUUtilization`, `NetworkIn` |
| `Lab02/EC2` | CloudWatch Agent | `mem_used_percent`, `disk_used_percent` |

Custom metrics are billed at ~$0.30/metric/month.

### Agent config via SSM Parameter Store

The agent JSON config is stored in SSM at `/lab02/cloudwatch-agent/config`. The user data script fetches it at boot using the native `ssm:` protocol in `amazon-cloudwatch-agent-ctl`. This means you can update the config and restart the agent without recreating the instance.

### Alarm design

`cpu_high` uses `evaluation_periods = 2` with `period = 300` — it requires 10 consecutive minutes above 80% before firing. This avoids false positives on short spikes. `ram_high` uses `period = 60` — it reacts in 3 minutes, appropriate for a metric that changes more gradually.

---

## Cleanup

```bash
cd terraform/
terraform destroy
```

Then verify manually in the console that these resources are gone — they are not managed by Terraform:

- **CloudWatch → Log Groups** : `/lab02/cloudwatch-agent` and `/lab02/system`

---

## Cost

Negligible for a short lab session.

| Resource | Cost |
|---|---|
| EC2 t3.micro | Free tier or ~$0.011/hour |
| Detailed monitoring | ~$3.50/instance/month |
| Custom metrics × 4 | ~$0.30/metric/month = ~$1.20/month |
| CloudWatch dashboard | Free (first 3 dashboards) |
| SNS email notifications | Free |
| **Total if destroyed same day** | **< $0.05** |