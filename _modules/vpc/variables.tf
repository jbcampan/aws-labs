variable "vpc_cidr" {
  description = "VPC CIDR block (e.g.: 10.0.0.0/16)"
  type        = string
}

variable "vpc_name" {
  description = "Prefix used to name all module resources"
  type        = string
  default     = "main"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block — AZ a (e.g.: 10.0.1.0/24)"
  type        = string
}

variable "public_subnet_cidr_b" {
  description = "Public subnet CIDR block — AZ b (e.g.: 10.0.3.0/24). Required for ALB/ASG (needs 2+ AZ). Leave empty for single-AZ labs."
  type        = string
  default     = ""
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block (e.g.: 10.0.2.0/24)"
  type        = string
}

variable "private_subnet_cidr_b" {
  description = "Private subnet CIDR block — AZ b (e.g.: 10.0.4.0/24). Required for RDS multi-AZ, Lambda VPC (DB Subnet Group needs 2 AZs). Leave empty for single-AZ labs."
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Enable a NAT Gateway in the public subnet so that resources in private
    subnets can initiate outbound connections to the internet.

    Set to true when:
      - A Lambda in a private subnet needs to call external APIs
      - EC2 instances in private subnets need to pull packages / updates

    Leave false (default) for labs where private resources are fully isolated
    or only communicate within the VPC. The NAT Gateway incurs a fixed hourly
    cost (~$0.045/h) regardless of traffic — always destroy after use.
  EOT
  type        = bool
  default     = false
}