# ─── VPC ─────────────────────────────────────────────────────────────────────

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
