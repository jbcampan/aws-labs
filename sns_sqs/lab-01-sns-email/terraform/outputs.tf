output "sns_topic_arn" {
  description = "ARN of the SNS topic — required for the Python script"
  value       = aws_sns_topic.lab01_topic.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue — used to read messages manually"
  value       = aws_sqs_queue.lab01_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.lab01_queue.arn
}

output "email_subscription_arn" {
  description = "ARN of the email subscription (PendingConfirmation until confirmed)"
  value       = aws_sns_topic_subscription.lab01_email_subscription.arn
}

output "next_steps" {
  description = "Post-deployment steps reminder"
  value       = <<-EOT
    1. Confirm the email subscription: open your inbox and click the AWS link.
    2. Publish a message:
         export SNS_TOPIC_ARN="${aws_sns_topic.lab01_topic.arn}"
         python publish.py
    3. Read messages from the queue:
         python read_sqs.py
  EOT
}
