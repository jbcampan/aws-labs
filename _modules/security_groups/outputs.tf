output "sg_web_id" {
  description = "ID of the Security Group web (HTTP/HTTPS)"
  value       = aws_security_group.web.id
}

output "sg_ssh_id" {
  description = "ID of the Security Group SSH"
  value       = aws_security_group.ssh.id
}

output "sg_db_id" {
  description = "ID of the database (MySQL) Security Group"
  value       = aws_security_group.db.id
}
