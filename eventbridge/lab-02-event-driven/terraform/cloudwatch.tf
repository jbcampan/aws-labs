#############################################
# Log groups
#############################################
resource "aws_cloudwatch_log_group" "ec2_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "security_logs" {
  name              = "/aws/events/security-alerts"
  retention_in_days = var.log_retention_days
}

#############################################
# Log resource policy
#############################################
resource "aws_cloudwatch_log_resource_policy" "eventbridge_to_security_logs" {
  policy_name = "${var.project_name}-eventbridge-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "delivery.logs.amazonaws.com"] }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.security_logs.arn}:*"
    }]
  })
}

#############################################
# EC2 State Change Rule
#############################################
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "${var.project_name}-ec2-state-change"
  description = "Capture EC2 stopped/terminated events"

  event_pattern = jsonencode({
    source = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["stopped", "terminated"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ec2_lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  arn       = aws_lambda_function.handler.arn

  # Optional: retry policy for the target
  # Retry policy: EventBridge retries with exponential backoff if Lambda fails
  retry_policy {
    maximum_event_age_in_seconds = 3600   # Retry for up to 1 hour
    maximum_retry_attempts       = 3      # 3 retries before sending to DLQ
  }  
}

#############################################
# IAM Login Failure
#############################################
resource "aws_cloudwatch_event_rule" "iam_login_fail" {
  name        = "${var.project_name}-iam-login-failure"
  description = "Detect failed AWS console logins"

  event_pattern = jsonencode({
    source = ["aws.signin"]
    detail-type = ["AWS Console Sign-In via CloudTrail"]
    detail = {
      responseElements = {
        ConsoleLogin = ["Failure"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "iam_log_target" {
  rule      = aws_cloudwatch_event_rule.iam_login_fail.name
  target_id = "SecurityLogs"

  arn = aws_cloudwatch_log_group.security_logs.arn
}