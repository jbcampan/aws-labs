#############################################
# CloudWatch Log Group — explicit retention
#############################################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = var.log_retention_days
}

#############################################
# EventBridge Rule — Scheduled Rule
#############################################

resource "aws_cloudwatch_event_rule" "scheduled_report" {
  name        = "${var.project_name}-rule"
  description = "Triggers the DynamoDB report every ${var.schedule_expression}"

  # Schedule expression — two possible syntaxes:
  #   rate(5 minutes)        → every 5 minutes (lab / debugging)
  #   cron(0 8 * * ? *)      → every day at 08:00 UTC (production)
  #
  # NOTE: AWS cron syntax differs from Unix cron:
  #   - 6 fields: Minutes Hours Day-of-month Month Day-of-week Year
  #   - Day-of-month AND Day-of-week cannot both be specified at the same time
  #     → use ? for the field you do not want to constrain
  #   - Day names are SUN, MON, TUE, WED, THU, FRI, SAT (not 0-6)
  schedule_expression = var.schedule_expression

  # BEST PRACTICE: disable instead of destroying a paused rule
  # Set to false to temporarily stop execution without losing the configuration
  state = var.rule_enabled ? "ENABLED" : "DISABLED"
}

#############################################
# EventBridge Target — rule → Lambda binding
#############################################

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.scheduled_report.name
  target_id = "${var.project_name}-target"
  arn       = aws_lambda_function.report.arn

  # Optional: retry policy for the target
  # Default: 24h retry window, maximum 185 retry attempts
  retry_policy {
    maximum_event_age_in_seconds = 3600  # Maximum 1h retry window
    maximum_retry_attempts       = 2
  }
}