#############################################
# lab-01-scheduled-rule — Terraform Outputs
#############################################

output "lambda_function_name" {
  description = "Name of the reporting Lambda function"
  value       = aws_lambda_function.report.function_name
}

output "lambda_function_arn" {
  description = "ARN of the reporting Lambda function"
  value       = aws_lambda_function.report.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.scheduled_report.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.scheduled_report.arn
}

output "eventbridge_rule_state" {
  description = "Rule state (ENABLED / DISABLED)"
  value       = aws_cloudwatch_event_rule.scheduled_report.state
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group used to monitor invocations"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "schedule_expression" {
  description = "Configured schedule expression"
  value       = aws_cloudwatch_event_rule.scheduled_report.schedule_expression
}

output "observe_logs_command" {
  description = "AWS CLI command to stream logs in real time"
  value       = "aws logs tail ${aws_cloudwatch_log_group.lambda_logs.name} --follow --region ${var.aws_region}"
}

output "invoke_manually_command" {
  description = "Command to invoke the Lambda manually (testing)"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.report.function_name} --region ${var.aws_region} /tmp/response.json && cat /tmp/response.json"
}

output "disable_rule_command" {
  description = "Command to temporarily disable the rule (without destroying it)"
  value       = "aws events disable-rule --name ${aws_cloudwatch_event_rule.scheduled_report.name} --region ${var.aws_region}"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.items.name
}

output "aws_region" {
  value = var.aws_region
}