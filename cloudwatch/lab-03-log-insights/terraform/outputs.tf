output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.lambda_function.function_name
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "invoke_command" {
  description = "CLI command to invoke the Lambda"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.lambda_function.function_name} --region ${var.region} /tmp/response.json"
}