output "main_queue_url" {
  description = "URL de la queue principale — à passer au script send_messages.py"
  value       = aws_sqs_queue.main.url
}

output "main_queue_arn" {
  description = "ARN de la queue principale"
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "URL de la DLQ — pour inspecter les messages en échec"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN de la DLQ"
  value       = aws_sqs_queue.dlq.arn
}

output "lambda_function_name" {
  description = "Nom de la Lambda consumer"
  value       = aws_lambda_function.consumer.function_name
}

output "lambda_log_group" {
  description = "CloudWatch Log Group de la Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "cloudwatch_url" {
  description = "Lien direct vers les logs CloudWatch (région Paris)"
  value       = "https://eu-west-3.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.lambda_logs.name, "/", "$252F")}"
}
