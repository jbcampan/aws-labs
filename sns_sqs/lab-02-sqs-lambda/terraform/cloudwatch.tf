# #########################################
# CloudWatch Log Group (explicit retention)
# #########################################
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.consumer.function_name}"
  retention_in_days = 7

  tags = var.tags
}
