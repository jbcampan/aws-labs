######################################
# SNS Topic (core pub/sub bus)
######################################
resource "aws_sns_topic" "ec2_alerts" {
  name = "${var.project_name}-sns-topic"
}

######################################
# SNS Subscription → Email
######################################
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ec2_alerts.arn
  protocol = "email"
  endpoint = var.email_address
}