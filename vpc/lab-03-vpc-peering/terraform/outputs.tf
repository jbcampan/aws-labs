output "ec2_vpc1_public_ip" {
  description = "Public IP of the EC2 instance in VPC1 — use this to SSH in"
  value       = aws_instance.ec2_vpc1.public_ip
}

output "ec2_vpc2_public_ip" {
  description = "Public IP of the EC2 instance in VPC2 — use this to SSH in"
  value       = aws_instance.ec2_vpc2.public_ip
}

output "ec2_vpc2_private_ip" {
  description = "Private IP of EC2 in VPC2 — use this to test ping from VPC1"
  value       = aws_instance.ec2_vpc2.private_ip
}

output "key_name" {
  description = "SSH key pair name used for EC2 instances"
  value       = aws_key_pair.lab03.key_name
}