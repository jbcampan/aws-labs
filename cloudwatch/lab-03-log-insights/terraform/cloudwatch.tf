######################################
# CloudWatch Log Group
######################################
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7

    tags = {
      Environment = var.environment
      Project     = "lab-03-log-insights"
      Application = "log-insights-demo"
      Function    = var.function_name
    }
}