# Fetch information about the current AWS account
data "aws_caller_identity" "current" {}

# Fetch the current AWS region
data "aws_region" "current" {}

# VPC Module
# Deploys a simple VPC with one public and one private subnet
module "vpc" {
  source              = "../../../_modules/vpc"
  vpc_name            = "${var.project_name}-vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"

  # public_subnet_cidr_b and private_subnet_cidr_b omitted:
  # simple lab in a single AZ, no ALB or RDS required
  # enable_nat_gateway = false (default): tasks will run in public subnet with public IP
}