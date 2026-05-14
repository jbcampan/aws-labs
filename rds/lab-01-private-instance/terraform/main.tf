# ─── VPC ──────────────────────────────────────────────────────────────────────
# We reuse the shared VPC module, enabling only what this lab requires:
#
#   - private_subnet_cidr_b : second private subnet (AZ-b)
#     → REQUIRED for the RDS DB Subnet Group
#     → AWS enforces at least 2 AZs even for Single-AZ RDS instances
#
#   - public_subnet_cidr_b  : second public subnet (AZ-b)
#     → not strictly required for this lab
#     → included for architectural completeness
#
#   - enable_nat_gateway    : optional internet egress for private subnets
#     → NOT required for RDS itself (fully private)
#     → may be useful for EC2 (e.g. package installation)
#     → can be safely disabled if using SSM + VPC endpoints only

module "vpc" {
  source                = "../../../_modules/vpc"
  vpc_name              = "${var.project_name}-vpc"
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidr    = "10.0.1.0/24"
  public_subnet_cidr_b  = "10.0.3.0/24"
  private_subnet_cidr   = "10.0.2.0/24"
  private_subnet_cidr_b = "10.0.4.0/24"
  enable_nat_gateway    = true
}