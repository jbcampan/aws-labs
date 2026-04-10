# lab-02-custom-ami

## Objective

Create a custom AMI from a configured EC2 instance, then copy it to another region. Understand the AMI lifecycle and the difference between user data bootstrapping and a frozen machine image.

---

## What this lab deploys

- **1 VPC** — `lab02-ec2` (`10.0.0.0/16`) with a public and private subnet, via `_modules/vpc`
- **2 Security Groups** — web (HTTP/HTTPS open to the world) and SSH (restricted to your IP), via `_modules/security_groups`
- **1 Key Pair** — `lab02-key`, sourced from `~/.ssh/id_rsa.pub`
- **1 EC2 instance** — `t3.micro`, Ubuntu 22.04, deployed in the public subnet with a user data script
- **1 AMI** — created from the configured instance in `eu-west-3`
- **1 AMI copy** — copied to `us-east-1`

---

## What you learn

- **User data** — a Bash script executed once at first boot, useful for bootstrapping an instance (installing packages, writing files, starting services)
- **Custom AMI** — a frozen snapshot of a configured instance's disk; new instances launched from it require no further setup
- **The difference between the two** — user data runs at boot time and takes time; an AMI is already "baked" and launches immediately ready
- **The AMI lifecycle** — instance → configure → snapshot → AMI → new identical instance
- **Regional scope in practice** — an AMI is regional by default; copying it cross-region is an explicit operation that duplicates the underlying EBS snapshot

---

## Structure

```
lab-02-custom-ami/
├── terraform/
│   ├── main.tf          # VPC module, SG module, key pair, EC2 instance
│   ├── variables.tf     # Region, my_ip
│   ├── outputs.tf       # Instance ID, public IP, key name, region source
│   └── providers.tf     # AWS provider (~> 5.0)
└── script/
    ├── custom-ami-terraform.sh    # Init + apply
    ├── custom-ami-nginx.sh        # User data: installs nginx, writes index.html
    └── custom-ami-copy.sh         # create-image + copy-image
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configured (`aws configure`)
- An SSH key pair at `~/.ssh/id_rsa.pub`

IAM permissions required: EC2, VPC.

---

## Usage

### Step 1 — Deploy the instance

#### Option A — Via the script

```bash
chmod +x script/custom-ami-terraform.sh
./script/custom-ami-terraform.sh
```

#### Option B — Manually

```bash
cd terraform/
terraform init
terraform apply
```

Terraform will prompt for `my_ip` — provide your public IP in CIDR notation (e.g. `82.123.45.67/32`).

### Step 2 — Verify nginx is running

Wait 60–90 seconds after `terraform apply` for the user data script to complete, then:

```bash
curl http://$(terraform output -raw public_ip)
# Expected: <h1>Hello from my EC2</h1>
```

If `curl` times out, the user data is still running. Wait and retry.

### Step 3 — Create and copy the AMI

Once nginx responds correctly, run the copy script:

```bash
chmod +x script/custom-ami-copy.sh
./script/custom-ami-copy.sh
```

The script will:
1. Retrieve the instance ID from `terraform output`
2. Create an AMI in `eu-west-3` and wait for it to become `available`
3. Copy the AMI to `us-east-1` and wait for the copy to become `available`
4. Print both AMI IDs

---

## Verification

### Check user data logs (if nginx doesn't respond)

```bash
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw public_ip)
sudo cat /var/log/cloud-init-output.log
systemctl status nginx
```

### Check AMIs in both regions

```bash
# Source region
aws ec2 describe-images \
  --filters "Name=name,Values=lab02-custom-ami-*" \
  --region eu-west-3 \
  --query "Images[*].[ImageId,Name,State]" \
  --output table

# Target region
aws ec2 describe-images \
  --filters "Name=name,Values=lab02-custom-ami-*copy*" \
  --region us-east-1 \
  --query "Images[*].[ImageId,Name,State]" \
  --output table
```

Both should show `available`.

---

## Note on user data vs AMI

| | User data | Custom AMI |
|---|---|---|
| When it runs | At first boot | Never — already baked in |
| Boot time | Longer (installs packages) | Faster (everything is already there) |
| Typical use | Light config, dynamic params, secrets | Standardised base image for a team |

In production, AMI baking is typically done with [Packer](https://www.packer.io/). This lab uses the raw CLI approach to expose the underlying mechanics.

---

## Cleanup

AMIs and their underlying EBS snapshots are billed independently — both must be deleted.

```bash
# Deregister AMIs
aws ec2 deregister-image --image-id <AMI_ID_SOURCE> --region eu-west-3
aws ec2 deregister-image --image-id <AMI_COPY_ID>   --region us-east-1

# List and delete snapshots
aws ec2 describe-snapshots --owner-ids self --region eu-west-3 \
  --query "Snapshots[*].[SnapshotId,Description]" --output table

aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID> --region eu-west-3
aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID> --region us-east-1

# Destroy Terraform infrastructure
cd terraform/
terraform destroy
```

> ⚠️ `deregister-image` does not delete the underlying snapshot. Both commands are required to avoid ongoing storage costs.

---

## Cost

**~$0.01** for the EC2 instance if destroyed shortly after testing. EBS snapshot storage in two regions is negligible for a small image — but destroy promptly.