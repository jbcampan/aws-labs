#############################################
# Lambda Code packaging
#############################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../script/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

#############################################
# Lambda Function
#############################################
resource "aws_lambda_function" "handler" {
  function_name = var.project_name
  description = ""
  filename = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime = "python3.12"
  handler = "handler.handler"
  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.ec2_alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.ec2_lambda_logs]
}

############################################
# Lambda Resource Policy (Allow EventBridge to invoke Lambda)
############################################
# KEY CONCEPT: two distinct permission layers

# 1. IAM Role (iam.tf): allows the Lambda to call DynamoDB and CloudWatch Logs
# 2. Resource Policy (here): allows EventBridge to invoke the Lambda

# Without this resource policy, Eventbridge gets an "Access Denied" when it tries
# to trigger the Lambda — a classic, silent, and hard-to-debug error.
resource "aws_lambda_permission" "lambda_permission" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.ec2_state_change.arn
}