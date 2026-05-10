#############################################
# IAM — Lambda Role
#############################################

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  description = "Execution role for the scheduled reporting Lambda"
}

# Inline policy: CloudWatch Logs + DynamoDB (read-only)
data "aws_iam_policy_document" "lambda_permissions" {

  # CloudWatch Logs — create log group/stream + write logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}:*"
    ]
  }

  # DynamoDB — read-only access to the target table
  # Scan + DescribeTable are sufficient for our reporting use case
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${var.project_name}-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}