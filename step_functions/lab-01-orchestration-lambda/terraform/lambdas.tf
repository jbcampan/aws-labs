# ─── ZIP Packages — one per Lambda function ──────────────────────────────────

data "archive_file" "lambda_zips" {
  for_each = local.lambdas

  type        = "zip"
  source_dir  = each.value
  output_path = "${path.module}/.lambda-zips/${each.key}.zip"
}

# ─── Lambda Functions ─────────────────────────────────────────────────────────

resource "aws_lambda_function" "functions" {
  for_each = local.lambdas

  function_name = "${local.prefix}-${each.key}"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = local.lambda_runtime
  timeout       = local.lambda_timeout
  handler       = "handler.lambda_handler"

  filename         = data.archive_file.lambda_zips[each.key].output_path
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256

  environment {
    variables = {
      CONFIRMATION_TOPIC_ARN = aws_sns_topic.order_confirmation.arn
      ALERT_TOPIC_ARN        = aws_sns_topic.order_alerts.arn
      ORDERS_TABLE_NAME      = aws_dynamodb_table.orders.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs,
  ]
}

# ─── CloudWatch Log Groups ────────────────────────────────────────────────────
# Explicitly created to control retention
# (otherwise Lambda creates them automatically with no retention policy)

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.lambdas

  name              = "/aws/lambda/${local.prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${local.prefix}-order-pipeline"
  retention_in_days = var.log_retention_days
}