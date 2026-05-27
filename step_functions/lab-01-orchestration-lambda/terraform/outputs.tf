output "state_machine_arn" {
  description = "ARN of the State Machine — used to trigger executions"
  value       = aws_sfn_state_machine.order_pipeline.arn
}

output "state_machine_name" {
  description = "State Machine name"
  value       = aws_sfn_state_machine.order_pipeline.name
}

output "orders_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "confirmation_topic_arn" {
  description = "ARN of the customer confirmation SNS topic"
  value       = aws_sns_topic.order_confirmation.arn
}

output "alerts_topic_arn" {
  description = "ARN of the alerts SNS topic"
  value       = aws_sns_topic.order_alerts.arn
}

output "lambda_arns" {
  description = "ARNs of all Lambda functions"
  value       = { for name, fn in aws_lambda_function.functions : name => fn.arn }
}

output "console_url" {
  description = "Direct AWS Console URL to the State Machine"
  value       = "https://console.aws.amazon.com/states/home?region=${var.aws_region}#/statemachines/view/${aws_sfn_state_machine.order_pipeline.arn}"
}