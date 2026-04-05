output "vpc_id" {
  description = "ID du VPC principal"
  value       = aws_vpc.my_vpc.id
}

output "public_subnet_id" {
  description = "ID du subnet public"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "ID du subnet privé"
  value       = aws_subnet.private_subnet.id
}