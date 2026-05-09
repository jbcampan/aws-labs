# ─── VPC ──────────────────────────────────────────────────────────────────────
# We reuse the shared VPC module, enabling only what this lab requires:
#   - private_subnet_cidr_b : second private subnet (AZ-b) — required for the
#     RDS DB Subnet Group (AWS requires at least 2 AZs, even for single-AZ DBs)
#   - public_subnet_cidr_b  : second public subnet (AZ-b) — best practice for
#     NAT Gateway redundancy, not strictly required in this lab
#   - enable_nat_gateway    : allows Lambda (in private subnet) to access
#     the internet if needed (external API calls, etc.)

module "vpc" {
  source = "../../../_modules/vpc"

  vpc_name              = "${var.project_name}-vpc"
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidr    = "10.0.1.0/24"
  public_subnet_cidr_b  = "10.0.3.0/24"
  private_subnet_cidr   = "10.0.2.0/24"
  private_subnet_cidr_b = "10.0.4.0/24"
  enable_nat_gateway    = true
}