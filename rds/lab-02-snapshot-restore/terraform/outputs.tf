output "bastion_public_ip" {
  description = "Public IP of the EC2 bastion host"
  value       = aws_instance.bastion.public_ip
}

output "rds_source_endpoint" {
  description = "Endpoint of the source RDS instance"
  value       = aws_db_instance.source.endpoint
}

output "rds_source_identifier" {
  description = "Identifier of the source RDS instance (used for snapshots)"
  value       = aws_db_instance.source.identifier
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.source.db_name
}

output "db_username" {
  description = "Admin username"
  value       = aws_db_instance.source.username
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to the bastion"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.bastion.public_ip}"
}

output "mysql_connect_source" {
  description = "MySQL connection command for the source instance"
  value       = "mysql -h ${aws_db_instance.source.address} -P 3306 -u ${aws_db_instance.source.username} -p ${aws_db_instance.source.db_name}"
  sensitive   = true
}