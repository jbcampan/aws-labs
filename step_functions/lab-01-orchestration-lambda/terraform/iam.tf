# ─── IAM — Shared role for all Lambda functions ──────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.prefix}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# CloudWatch Logs access (log group creation + log writing)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS access — publish to both topics
data "aws_iam_policy_document" "lambda_sns" {
  statement {
    actions   = ["sns:Publish"]
    resources = [
      aws_sns_topic.order_confirmation.arn,
      aws_sns_topic.order_alerts.arn,
    ]
  }
}

resource "aws_iam_policy" "lambda_sns" {
  name   = "${local.prefix}-lambda-sns-policy"
  policy = data.aws_iam_policy_document.lambda_sns.json
}

resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_sns.arn
}

# ─── IAM — Role for Step Functions ───────────────────────────────────────────

data "aws_iam_policy_document" "sfn_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_exec" {
  name               = "${local.prefix}-sfn-exec-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role.json
}

# Step Functions must be able to invoke all Lambda functions
data "aws_iam_policy_document" "sfn_invoke_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [for name, _ in local.lambdas : aws_lambda_function.functions[name].arn]
  }
}

resource "aws_iam_policy" "sfn_invoke_lambda" {
  name   = "${local.prefix}-sfn-invoke-lambda-policy"
  policy = data.aws_iam_policy_document.sfn_invoke_lambda.json
}

resource "aws_iam_role_policy_attachment" "sfn_invoke_lambda" {
  role       = aws_iam_role.sfn_exec.name
  policy_arn = aws_iam_policy.sfn_invoke_lambda.arn
}

# Step Functions must write to DynamoDB (Parallel branch)
data "aws_iam_policy_document" "sfn_dynamodb" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }
}

resource "aws_iam_policy" "sfn_dynamodb" {
  name   = "${local.prefix}-sfn-dynamodb-policy"
  policy = data.aws_iam_policy_document.sfn_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "sfn_dynamodb" {
  role       = aws_iam_role.sfn_exec.name
  policy_arn = aws_iam_policy.sfn_dynamodb.arn
}

# Step Functions — CloudWatch access for execution logs
resource "aws_iam_role_policy_attachment" "sfn_logs" {
  role       = aws_iam_role.sfn_exec.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}