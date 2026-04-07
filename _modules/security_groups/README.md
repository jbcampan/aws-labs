# _modules/security-groups

Reusable Terraform module that provisions three Security Groups covering the standard web/ssh/db pattern used across EC2, RDS, and ECS labs.

Requires a VPC to already exist — pass its ID directly, typically from the output of the `vpc` module.

---

## What this module creates

- 1 SG **web** — inbound HTTP (80) and HTTPS (443) open to the world, outbound all allowed
- 1 SG **ssh** — inbound SSH (22) restricted to a single IP, outbound all allowed
- 1 SG **db** — inbound MySQL (3306) allowed from the web SG only (SG-to-SG reference), outbound all allowed

---

## Usage

```hcl
module "security_groups" {
  source      = "../../_modules/security-groups"
  vpc_id      = module.vpc.vpc_id
  my_ip       = var.my_ip
  name_prefix = "lab03"
}
```

`vpc_id` is typically chained directly from the `vpc` module output. All SGs are named using `name_prefix` — e.g. `lab03-sg-web`, `lab03-sg-db`.

---

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `vpc_id` | string | yes | — | ID of the VPC in which to create the Security Groups |
| `my_ip` | string | yes | — | Your public IP in CIDR notation, used to restrict SSH (e.g. `82.123.45.67/32`) |
| `name_prefix` | string | no | `"main"` | Prefix used to name all Security Groups |

---

## Outputs

| Name | Description |
|---|---|
| `sg_web_id` | ID of the web SG — attach to EC2 instances, ALBs |
| `sg_ssh_id` | ID of the SSH SG — attach to EC2 instances that need direct access |
| `sg_db_id` | ID of the db SG — attach to RDS instances, not to app servers |

---

## Note on SG-to-SG references

The db SG allows inbound MySQL traffic from the web SG — not from a specific IP. Any instance carrying the web SG can reach MySQL, regardless of its IP address.

This is the standard pattern in production: when app servers scale or their IPs change, the DB access rule never needs to be updated.

---

## What this module does not handle

- **EC2 instances, key pairs, AMIs** — this module only creates the Security Groups. Attaching them to instances is the responsibility of the calling lab.
- **Additional protocols** — only HTTP, HTTPS, SSH, and MySQL are covered. If a lab needs PostgreSQL (5432), Redis (6379), or custom ports, add dedicated SGs in the calling `main.tf` rather than modifying this module.
- **NACLs** — stateless filtering at the subnet level is out of scope here. Security filtering is handled exclusively at the SG level.