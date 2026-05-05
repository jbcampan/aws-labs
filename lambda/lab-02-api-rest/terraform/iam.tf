# ############################
# IAM assume role (shared)
# ############################
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

# ############################
# IAM Role (1 for each Lambda)
# ############################
resource "aws_iam_role" "lambda" {
  for_each = local.lambdas

  name               = "${var.lab_name}-lambda-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}


# ############################
# IAM Policies DynamoDB (1 action for each Lambda)
# ############################
data "aws_iam_policy_document" "dynamo" {
  for_each = local.lambdas

  statement {
    effect    = "Allow"
    actions   = [each.value.action]
    resources = [aws_dynamodb_table.items.arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  for_each = local.lambdas

  name   = "dynamo-${each.key}"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.dynamo[each.key].json
}

# CloudWatch logs
resource "aws_iam_role_policy_attachment" "logs" {
  for_each = local.lambdas

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}