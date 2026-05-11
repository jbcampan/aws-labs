output "sns_topic_arn" {
  description = "ARN of the SNS topic receiving EC2 alerts"
  value       = aws_sns_topic.ec2_alerts.arn
}

output "ec2_handler_lambda_name" {
  description = "Name of the EC2 state-change Lambda"
  value       = aws_lambda_function.handler.function_name
}

output "ec2_eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule watching EC2 state changes"
  value       = aws_cloudwatch_event_rule.ec2_state_change.arn
}

output "iam_eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule watching IAM login failures"
  value       = aws_cloudwatch_event_rule.iam_login_fail.arn
}

output "iam_security_log_group" {
  description = "CloudWatch Log Group where raw IAM login failure events are archived"
  value       = aws_cloudwatch_log_group.security_logs.name
}

output "test_instance_id" {
  description = "ID of the EC2 instance — stop or terminate it to trigger the pipeline"
  value       = aws_instance.my_ec2_lab02_eventbridge.id
}

output "console_deep_link" {
  description = "Direct link to the EC2 test instance in the AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/ec2/home?region=${var.aws_region}#Instances:instanceId=${aws_instance.my_ec2_lab02_eventbridge.id}"
}
