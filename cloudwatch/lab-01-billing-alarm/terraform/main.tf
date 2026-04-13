######################################
# SNS Topic
######################################
resource "aws_sns_topic" "billing_alerts" {
  name = "billing-alerts"
}

######################################
# SNS Topic subscription
######################################
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

######################################
# CloudWatch Alarm
######################################
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "billing-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 50
  treat_missing_data  = "notBreaching"

  alarm_description = "Alert when AWS charges exceed 50 USD"

  namespace   = "AWS/Billing"
  metric_name = "EstimatedCharges"

  statistic = "Maximum"
  period    = 21600 # 6 heures

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [
    aws_sns_topic.billing_alerts.arn
  ]
}