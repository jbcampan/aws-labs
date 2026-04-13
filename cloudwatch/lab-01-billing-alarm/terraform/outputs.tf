output "sns_topic_arn" {
  description = "ARN du SNS topic billing-alerts"
  value       = aws_sns_topic.billing_alerts.arn
}

output "alarm_name" {
  description = "Nom de l'alarme CloudWatch"
  value       = aws_cloudwatch_metric_alarm.billing_alarm.alarm_name
}