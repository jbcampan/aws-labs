# _modules/vpc

Reusable Terraform module that provisions a standard VPC with one public subnet, one private subnet, and an Internet Gateway.

Created after lab-01 and lab-02 — call this module from any lab that needs a network layer instead of duplicating the code.

---

## What this module creates

- 1 VPC
- 1 public subnet (`map_public_ip_on_launch = true`)
- 1 private subnet
- 1 Internet Gateway attached to the VPC
- 1 public route table with a default route to the IGW, associated to the public subnet
- 1 private route table (no internet route), associated to the private subnet

---

## Usage

```hcl
module "vpc" {
  source              = "../../_modules/vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  vpc_name            = "lab03"
}
```

All resources are named using `vpc_name` as a prefix — e.g. `lab03-igw`, `lab03-public-subnet`.

---

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `vpc_cidr` | string | yes | — | CIDR block of the VPC (e.g. `10.0.0.0/16`) |
| `public_subnet_cidr` | string | yes | — | CIDR block of the public subnet (e.g. `10.0.1.0/24`) |
| `private_subnet_cidr` | string | yes | — | CIDR block of the private subnet (e.g. `10.0.2.0/24`) |
| `vpc_name` | string | no | `"main"` | Prefix used to name all resources |

---

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC — pass this to the security-groups module |
| `public_subnet_id` | ID of the public subnet — pass this to EC2, ALB, etc. |
| `private_subnet_id` | ID of the private subnet — pass this to RDS, ECS tasks, etc. |
| `igw_id` | ID of the Internet Gateway |

---

## What this module does not handle

- **NAT Gateway** — resources in the private subnet cannot reach the internet without one. In a real project you would add a NAT Gateway attached to the public subnet, with a route in the private route table pointing to it. Omitted here to keep costs at $0.
- **Multiple AZs** — both subnets are in the default AZ. Production workloads typically spread subnets across 2 or 3 AZs for high availability.
- **NACLs** — Network ACLs are stateless and sit in front of Security Groups. This module relies on the default NACL (allow all), which is fine for labs. Security filtering is handled at the SG level via the `security-groups` module.