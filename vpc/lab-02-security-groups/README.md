# lab-02-security-groups

## Objective

Understand Security Groups — the primary network filtering mechanism used in every EC2, RDS, and ECS lab that follows.

This lab covers the creation of three Security Groups with different rules, and a test EC2 instance to validate them concretely.

---

## What this lab deploys

- **1 SG "web"** — inbound HTTP (80) and HTTPS (443) open to the world, outbound all allowed
- **1 SG "ssh"** — inbound SSH (22) restricted to your IP only
- **1 SG "db"** — inbound MySQL (3306) allowed from the web SG only (SG-to-SG reference)
- **1 EC2 instance** — Ubuntu 22.04, in the public subnet from lab-01, carrying the web and ssh SGs

---

## What you learn

- Security Groups are **stateful** — if an inbound connection is allowed, the response is automatically permitted outbound, without an explicit egress rule
- The fundamental difference with NACLs, which are stateless
- How to reference a SG from another SG instead of an IP — common practice in production to allow DB access only from app servers
- Why `0.0.0.0/0` on SSH is never acceptable in production

---

## Structure

```
lab-02-security-groups/
├── terraform/
│   ├── main.tf           # Data sources, security groups, key pair, EC2 instance
│   ├── variables.tf      # Region, your IP
│   ├── outputs.tf        # Instance public IP, SG IDs
│   ├── providers.tf      # AWS provider (~> 5.0)
│   └── terraform.tfvars  # Your actual IP (not committed)
├── script/
│   └── security-groups-terraform.sh  # Init + apply
└── README.md
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configured (`aws configure`)
- IAM permissions to create EC2 and Security Group resources
- **lab-01 must be deployed** — this lab reads the VPC and subnet via data sources
- An SSH key pair on your machine (`~/.ssh/id_rsa.pub`)

If you don't have an SSH key yet:
```bash
ssh-keygen -t rsa -b 4096
```

---

## Usage

### Configuration

Copy the example file and fill in your public IP:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Get your public IP:
```bash
curl -4 ifconfig.me
```

Then set it in `terraform.tfvars`:
```
my_ip = "82.123.45.67/32"
```

### Option 1 — Via the script

```bash
chmod +x script/security-groups-terraform.sh
./script/security-groups-terraform.sh
```

### Option 2 — Manually

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

---

## Verification

After `terraform apply`, check in the AWS console:

- The 3 Security Groups appear under EC2 → Security Groups
- The web SG has inbound rules on ports 80 and 443 from `0.0.0.0/0`
- The ssh SG has an inbound rule on port 22 restricted to your IP
- The db SG has an inbound rule on port 3306 sourced from the web SG (not an IP)
- The EC2 instance is running in the public subnet with a public IP

### Test SSH access

```bash
ssh -i ~/.ssh/id_rsa ubuntu@YOUR_PUBLIC_IP
```

Expected result: you are connected to the instance.

### Test SSH restriction

Change `my_ip` to a fake IP in `terraform.tfvars`:
```
my_ip = "1.2.3.4/32"
```

Apply and retry SSH:
```bash
terraform apply
ssh -i ~/.ssh/id_rsa ubuntu@YOUR_PUBLIC_IP
```

Expected result: connection timeout — the SG blocks any IP that doesn't match the rule.

Restore your real IP and apply again before destroying.

---

## Note on SG-to-SG references

The db SG allows inbound MySQL traffic from the web SG — not from a specific IP. This means any instance carrying the web SG can reach MySQL, regardless of its IP address.

This is the standard pattern in production: when you scale your app servers or their IPs change, the DB access rule doesn't need to be updated.

---

## Cleanup

```bash
cd terraform/
terraform destroy
```

The VPC from lab-01 is **not destroyed** — it is shared across labs.

---

## Cost

**~$0.01** for the EC2 instance if destroyed shortly after testing. The Security Groups themselves have no cost.