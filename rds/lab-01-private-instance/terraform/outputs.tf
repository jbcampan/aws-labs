output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "ec2_instance_id" {
  value = aws_instance.ec2.id
}

output "rds_secret_arn" {
  value = aws_db_instance.mysql.master_user_secret[0].secret_arn
}