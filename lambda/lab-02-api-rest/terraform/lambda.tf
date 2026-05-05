# ############################
# Zip Lambda
# ############################
data "archive_file" "lambda" {
  for_each = local.lambdas

  type        = "zip"
  source_file = "${path.module}/../script/${each.value.file}"
  output_path = "${path.module}/.zip/${each.key}.zip"
}

# ############################
# Lambda Functions
# ############################
resource "aws_lambda_function" "lambda" {
  for_each = local.lambdas

  function_name = "${var.lab_name}-${each.key}-item"
  role          = aws_iam_role.lambda[each.key].arn

  handler = "${replace(each.value.file, ".py", "")}.handler"
  runtime = "python3.12"

  filename         = data.archive_file.lambda[each.key].output_path
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items.name
    }
  }
}

# ############################
# Permission Lambda for Api Gateway
# ############################
resource "aws_lambda_permission" "api" {
  for_each = local.lambdas

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}