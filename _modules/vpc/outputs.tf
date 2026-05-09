output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# ── Publics subnets ───────────────────────────────────────────────────────────

# Single string (for compatibility with other labs)
output "public_subnet_id" {
  description = "Public subnet ID (AZ-a)"
  value       = aws_subnet.public.id
}

# List for ALB + ASG (both need it)
output "public_subnet_ids" {
  description = "List of public subnet IDs across AZs — use this for ALB and ASG"
  value = compact([aws_subnet.public.id, try(aws_subnet.public_b[0].id, "")])
}

# ── Privates subnets ───────────────────────────────────────────────────────────

# Single string (for compatibility with other labs)
output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

# List for VPC + RDS (DB Subnet Group needs ≥ 2 AZ)
output "private_subnet_ids" {
  description = "List of private subnet IDs across AZs — use this for Lambda VPC config and RDS DB Subnet Group"
  value       = compact([aws_subnet.private.id, try(aws_subnet.private_b[0].id, "")])
}

# ── Networking  ────────────────────────────────────────────────────────────────────

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ip" {
  description = "Public Elastic IP of the NAT Gateway (= outbound IP of private-subnet resources). Empty string if enable_nat_gateway = false."
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : ""
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}