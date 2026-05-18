# lab-02 — RDS Snapshot & Restore

> Master RDS backup and restore.  
> In production, knowing how to restore a database quickly is just as important as knowing how to create one.

---

## What This Lab Covers

- **1 VPC** — with public and private subnets across 2 AZs
- **1 EC2 Bastion** — `lab02-bastion`, Amazon Linux 2023, t3.micro, SSH access, MySQL client pre-installed via user_data
- **1 RDS Source Instance** — MySQL 8.0, db.t3.micro, 20 GB gp2, single-AZ, private subnets, no public access
- **1 RDS Restored Instance** — created during the lab by restoring the manual snapshot; new endpoint, same data as pre-incident
- **1 Manual Snapshot** — triggered by you via CLI, tagged with date and context, persists until explicitly deleted
- **2 Security Groups** — bastion (SSH ingress + full egress) and RDS (port 3306 from bastion SG only)
- **1 DB Subnet Group** — spans both private subnets across 2 AZs

---

## What You Learn

- **Manual vs automated snapshots** — manual snapshots are triggered by you and persist until explicitly deleted; automated snapshots are managed by AWS and deleted according to the retention window
- **Restore always creates a new instance** — the restored instance has a new endpoint; in production this means updating all application connection strings, which is the real operational challenge
- **RTO in practice** — you will observe how long the restore actually takes (typically 10–30 minutes for a db.t3.micro), and understand the architectural implications of that number
- **Point-in-Time Recovery** — RDS retains transaction logs and can restore to any moment within the retention window (up to 35 days), much more precise than a fixed snapshot *(requires `backup_retention_period > 0`, not available on free tier)*
- **Snapshot tagging best practices** — human-readable names with date and context are critical when restoring under stress; AWS-generated names are nearly unreadable

---

## Architecture

```
                ┌─────────────────────────────────────┐
                │              VPC 10.0.0.0/16         │
                │                                     │
                │  ┌──────────────┐                   │
Internet ──SSH──┼─►│  EC2 Bastion │                   │
                │  │ (MySQL CLI)  │                   │
                │  └──────┬───────┘                   │
                │         │ MySQL :3306               │
                │  ┌──────▼────────────────────────┐  │
                │  │  Private Subnet A  Private B   │  │
                │  │  ┌────────────┐               │  │
                │  │  │ RDS Source │ ←── snapshot  │  │
                │  │  │ (lab02-src)│               │  │
                │  │  └────────────┘               │  │
                │  │  ┌──────────────┐             │  │
                │  │  │ RDS Restored │ (created    │  │
                │  │  │ (lab02-rest) │  on restore) │  │
                │  │  └──────────────┘             │  │
                │  └───────────────────────────────┘  │
                └─────────────────────────────────────┘
```

---

## Structure

```
lab-02-snapshot-restore/
├── README.md
├── script/
│   ├── 01-seed-data.sh              # Seeds orders and products tables on RDS (runs on bastion)
│   ├── 02-create-snapshot.sh        # Creates a tagged manual snapshot, polls until available
│   ├── 03-simulate-incident.sh      # Runs DELETE FROM orders without WHERE (with confirmation)
│   ├── 04-restore-from-snapshot.sh  # Restores a new RDS instance, measures RTO in real time
│   ├── 05-verify-restore.sh         # Compares source vs restored instance side by side
│   ├── 06-pitr.sh                   # Point-in-Time Recovery to a precise UTC timestamp (bonus)
│   └── 07-cleanup.sh                # Deletes restored instances, snapshot, then terraform destroy
└── terraform/
    ├── main.tf                       # VPC, subnets, IGW, route tables, RDS, EC2, IAM
    ├── outputs.tf                    # Bastion IP, RDS endpoint, SSH and MySQL commands
    ├── variables.tf                  # Region, project name, DB credentials, SSH key path
    └── terraform.tfvars.example      # Template to copy — never commit terraform.tfvars
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS CLI configured (`aws configure`)
- An SSH key pair (`~/.ssh/id_rsa` + `~/.ssh/id_rsa.pub`)
- Permissions: `ec2:*`, `rds:*`, `iam:*`
- Your public IP: `curl -s ifconfig.me`

---

## Full Lab Walkthrough

### Step 0 — Setup

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set your IP (x.x.x.x/32) and database password
```

```bash
terraform init
terraform plan
terraform apply
```

Provisioning takes **10–15 minutes** — RDS is slow to initialize. Note the outputs at the end:

```
bastion_public_ip     = "x.x.x.x"
rds_source_endpoint   = "lab02-source.xxxxxx.eu-west-3.rds.amazonaws.com:3306"
ssh_command           = "ssh -i ~/.ssh/id_rsa ec2-user@x.x.x.x"
```

**Explore the console before moving on:**

- **VPC → Subnets** — confirm 1 public subnet (bastion) and 2 private subnets (RDS) are present
- **EC2 → Instances** — `lab02-bastion` has a public IP; note the absence of any key pair hint in the security group section
- **RDS → Databases → lab02-source**
  - *Publicly accessible*: **No**
  - *Endpoint*: a DNS name resolving to a private IP only
  - *DB Subnet Group*: lists both private subnets across 2 AZs
- **RDS → Databases → lab02-source → Maintenance & backups** — note the backup retention period; if you are on the free tier it must be `0`, which disables PITR (Step 6)

---

### Step 1 — Seed Initial Data

Copy the script to the bastion, then connect:

```bash
export BASTION_IP=$(terraform output -raw bastion_public_ip)

scp script/01-seed-data.sh ec2-user@$BASTION_IP:/tmp/
ssh -i ~/.ssh/id_rsa ec2-user@$BASTION_IP
```

From the bastion:

```bash
export RDS_HOST=<rds-endpoint-without-port>
export DB_PASS="ChangeMe123!"

bash /tmp/01-seed-data.sh
```

Manual verification:

```sql
mysql -h $RDS_HOST -u adminuser -p appdb

SELECT * FROM orders;    -- 8 rows expected
SELECT * FROM products;  -- 5 rows expected
EXIT;
```

**Console check — RDS → Monitoring:** the `DatabaseConnections` and `WriteIOPS` metrics show activity from the seed.

---

### Step 2 — Create a Manual Snapshot

From your local machine:

```bash
export DB_INSTANCE_ID=lab02-source
export AWS_REGION=eu-west-3

bash script/02-create-snapshot.sh
```

The script polls every 15 seconds and prints status. When it shows `available`, save the identifier:

```bash
export SNAPSHOT_ID=lab02-source-manual-YYYYMMDD-HHMM
```

**Console check — RDS → Snapshots → Manual tab:**
- The snapshot appears with status `Available`
- Verify the tags: `Note = Snapshot-avant-incident-simule`, `CreatedAt = ...`
- Switch to the **Automated** tab: compare the AWS-generated names — nearly unreadable under stress

**Manual vs automated snapshots:**

| Type      | Triggered by        | Retention                          | Naming        |
|-----------|---------------------|------------------------------------|---------------|
| Manual    | You (CLI/console)   | Until explicitly deleted           | You choose    |
| Automated | AWS (backup window) | Based on `backup_retention_period` | AWS-generated |

---

### Step 3 — Simulate an Incident

From the bastion:

```bash
scp script/03-simulate-incident.sh ec2-user@$BASTION_IP:/tmp/
ssh -i ~/.ssh/id_rsa ec2-user@$BASTION_IP
```

```bash
export RDS_HOST=<rds-endpoint-without-port>
export DB_PASS="ChangeMe123!"

bash /tmp/03-simulate-incident.sh
# Type "incident" to confirm
```

**Note the UTC timestamp displayed** — you will need it for PITR (Step 6).

Verification — the damage is real:

```sql
mysql -h $RDS_HOST -u adminuser -p appdb
SELECT COUNT(*) FROM orders;   -- -> 0, data is gone
EXIT;
```

**Console check — RDS → Monitoring:** a `WriteIOPS` spike is visible at the exact moment of the DELETE.

---

### Step 4 — Restore from the Snapshot

From your local machine:

```bash
bash script/04-restore-from-snapshot.sh
```

**What happens under the hood:**
1. AWS provisions a brand new RDS instance
2. Restores the EBS volume from the snapshot stored in S3
3. Starts MySQL and replays logs from the snapshot point

The script displays elapsed time in real time — this is your **observed RTO**. Typically 10–30 minutes for a db.t3.micro.

When `available`, copy the export command printed by the script:

```bash
export RESTORED_HOST=<printed-by-the-script>
```

**Console check — RDS → Databases:** you now see **two instances** — `lab02-source` and `lab02-source-restored`. They have different endpoints. In production, the application would need to be pointed at the new one — this is the real operational challenge of a restore.

---

### Step 5 — Verify the Restore

From the bastion:

```bash
scp script/05-verify-restore.sh ec2-user@$BASTION_IP:/tmp/
ssh -i ~/.ssh/id_rsa ec2-user@$BASTION_IP
```

```bash
export RDS_HOST=<source-endpoint>
export RESTORED_HOST=<restored-endpoint>
export DB_PASS="ChangeMe123!"

bash /tmp/05-verify-restore.sh
```

The script compares both instances side by side:
- Source instance → `orders` is empty (data lost)
- Restored instance → 8 orders present (pre-incident data confirmed)

Manual spot-check on the restored instance:

```sql
mysql -h $RESTORED_HOST -u adminuser -p appdb
SELECT * FROM orders;   -- all 8 rows are back
EXIT;
```

---

### Step 6 — PITR (Bonus)

> **Free tier note:** PITR requires `backup_retention_period > 0`. If you set it to `0` to stay within the free tier, skip this step.

Point-in-Time Recovery restores to a precise UTC timestamp by replaying transaction logs — more precise than a fixed snapshot.

```bash
bash script/06-pitr.sh
# Enter a timestamp BEFORE the incident: e.g. 2024-01-15T14:28:00Z
```

Use the UTC timestamp noted in Step 3, minus 2 minutes to be safely before the incident.

**PITR vs Snapshot — the key difference:**

```
Timeline:
──────────────────────────────────────────────────────►
    | snapshot   | new data inserted | INCIDENT |
    | (frozen)   | after snapshot    |          |
    └────────────┘                   └──────────┘

Snapshot restore -> recovers data up to the moment the snapshot was taken
PITR restore    -> recovers data up to the requested timestamp
                   (includes data inserted after the snapshot)
```

---

### Step 7 — Cleanup

```bash
export SNAPSHOT_ID=lab02-source-manual-YYYYMMDD-HHMM

bash script/07-cleanup.sh
# Type "cleanup" to confirm
```

The script deletes resources in the correct order:
1. Restored RDS instance (from snapshot)
2. PITR RDS instance (if created)
3. Manual snapshot
4. Terraform infrastructure (VPC, EC2, source RDS) via `terraform destroy`

**Console check after cleanup:**
- RDS → Databases: empty
- RDS → Snapshots → Manual: empty
- EC2 → Instances: terminated
- VPC: the lab VPC is gone

---

## Verification Checklist

| Where | What to verify |
|---|---|
| VPC → Subnets | 1 public subnet (bastion) + 2 private subnets (RDS) |
| EC2 → Instances | `lab02-bastion` has a public IP; RDS has none |
| RDS → lab02-source | *Publicly accessible*: No |
| RDS → DB Subnet Group | Both private subnets listed across 2 AZs |
| RDS → Snapshots → Manual | Snapshot visible with readable tags |
| RDS → Snapshots → Automated | Names are unreadable — contrast intentional |
| RDS → Databases (post-restore) | Two instances visible with different endpoints |
| MySQL on restored instance | `SELECT COUNT(*) FROM orders` returns 8 |
| After cleanup | RDS empty, snapshots empty, VPC gone |

---

## Key Concepts

### RTO in Practice

The **Recovery Time Objective** measures how long it takes to return to an operational state.
In this lab, you measured it yourself: it is the elapsed time between launching `restore-db-instance-from-db-snapshot` and the instance reaching `available`.

Architectural implications:
- 20-min RTO → acceptable for a non-critical internal tool
- 20-min RTO → unacceptable for a production SaaS or e-commerce platform
- To reduce RTO: Multi-AZ failover (~60s), Read Replica promotion, Aurora Global Database

### The Real Challenge: the New Endpoint

A restore **always** creates a new instance with a new endpoint. This is not a bug — it is by design, and it is the real operational challenge of a database restore in production.

In practice, this means updating:
- Application environment variables and secrets
- Load balancer target configurations
- Connection strings in monitoring and observability tools

Patterns to reduce the blast radius:
- **CNAME or Route 53 alias** pointing to the RDS endpoint → only DNS needs updating on restore
- **AWS RDS Proxy** → stable entry point that absorbs endpoint changes transparently

### Manual vs Automated Snapshots

```hcl
# Automated snapshots — controlled by this parameter
backup_retention_period = 7  # 0 disables them entirely (and disables PITR)
```

Manual snapshots are initiated by you (`aws rds create-db-snapshot`) and persist until you explicitly delete them. Automated snapshots are created by AWS within the configured backup window and deleted when they fall outside the retention window.

In a real incident, being able to identify the right snapshot immediately is critical. AWS-generated names are nearly unreadable under stress:

```bash
# Bad: AWS-generated, impossible to identify quickly
rds:lab02-source-2024-01-15-03-07

# Good: human-readable, context is obvious at a glance
lab02-source-manual-20240115-1430-before-v2-migration
```

### Point-in-Time Recovery

RDS continuously archives transaction logs to S3. When you trigger a PITR restore, AWS replays those logs up to the requested timestamp on top of the nearest automated snapshot. This means:

- You can restore to **any second** within the retention window (up to 35 days)
- PITR captures changes that happened **after** the last snapshot — a snapshot-only strategy would lose that data
- PITR requires `backup_retention_period > 0`; setting it to `0` disables both automated snapshots and PITR entirely

---

## Cost

| Resource | Free Tier | Beyond Free Tier |
|---|---|---|
| RDS db.t3.micro (source) | 750 h/month for 12 months | ~$0.02/h |
| RDS db.t3.micro (restored) | Counts against the same 750 h | ~$0.02/h |
| EC2 t3.micro (bastion) | 750 h/month for 12 months | ~$0.01/h |
| RDS Snapshot (20 GB) | 100% of provisioned storage free | ~$0.095/GB-month |

> **Two RDS instances run simultaneously during the restore phase** — both count against your free tier hours. Destroy the restored instance immediately after verification.