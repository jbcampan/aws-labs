output "rds_endpoint" {
  description = "RDS endpoint (private — only reachable from within the VPC)"
  value       = aws_db_instance.mysql.address
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway (= outbound IP seen by external services)"
  value       = module.vpc.nat_gateway_ip
}

output "lambda_function_name" {
  value = aws_lambda_function.main.function_name
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "invoke_command" {
  description = "Invoke the Lambda from the CLI"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.main.function_name} --region ${var.aws_region} /tmp/response.json && cat /tmp/response.json"
}

output "logs_command" {
  description = "Tail Lambda logs in real time"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow --region ${var.aws_region}"
}
