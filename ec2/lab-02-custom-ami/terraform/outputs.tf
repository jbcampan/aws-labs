output "region_source" {
  value = var.region
}

output "key_name" {
  description = "SSH key pair name used for EC2 instances"
  value       = aws_key_pair.lab02.key_name
}

output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}