#############################################
# Lambda Code packaging
#############################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../script/report_handler.py"
  output_path = "${path.module}/.build/report_handler.zip"
}

#############################################
# Lambda Function
#############################################
resource "aws_lambda_function" "report" {
  function_name = var.project_name
  description   = "Generates a DynamoDB report triggered by an EventBridge Schedule"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.12"
  handler = "report_handler.lambda_handler"

  role = aws_iam_role.lambda_exec.arn

  # Larger timeout for a potentially paginated DynamoDB scan
  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy.lambda_permissions,
  ]
}

############################################
# Lambda Resource Policy (Allow EventBridge to invoke Lambda)
############################################
# KEY CONCEPT: two distinct permission layers

# 1. IAM Role (iam.tf): allows the Lambda to call DynamoDB and CloudWatch Logs
# 2. Resource Policy (here): allows EventBridge to invoke the Lambda

# Without this resource policy, Eventbridge gets an "Access Denied" when it tries
# to trigger the Lambda — a classic, silent, and hard-to-debug error.

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal     = "events.amazonaws.com"

  # Restrict permission to this specific rule (principle of least privilege)
  source_arn = aws_cloudwatch_event_rule.scheduled_report.arn
}