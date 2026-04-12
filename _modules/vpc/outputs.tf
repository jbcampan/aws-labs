output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

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

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}