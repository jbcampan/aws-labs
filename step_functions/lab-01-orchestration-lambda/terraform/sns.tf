# ─── SNS Topics ──────────────────────────────────────────────────────────────

resource "aws_sns_topic" "order_confirmation" {
  name = "${local.prefix}-order-confirmation"
}

resource "aws_sns_topic" "order_alerts" {
  name = "${local.prefix}-order-alerts"
}

# Optional email subscription — uncomment and set the address to receive notifications
# resource "aws_sns_topic_subscription" "confirmation_email" {
#   topic_arn = aws_sns_topic.order_confirmation.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }
#
# resource "aws_sns_topic_subscription" "alerts_email" {
#   topic_arn = aws_sns_topic.order_alerts.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }