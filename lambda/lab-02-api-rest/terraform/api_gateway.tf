# ############################
# Api Gateway HTTP
# ############################
resource "aws_apigatewayv2_api" "main" {
  name = "main-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Content-Type"]
    allow_methods = ["GET", "POST", "DELETE", "PUT", "OPTIONS"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.main.id
  name = "$default"
  auto_deploy = true
}

# ############################
# Api integration with Lambda
# ############################
resource "aws_apigatewayv2_integration" "lambda" {
  for_each = local.lambdas

  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda[each.key].invoke_arn
  payload_format_version = "2.0"
}

# ############################
# Api Route
# ############################
resource "aws_apigatewayv2_route" "route" {
  for_each = local.lambdas

  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value.route
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}