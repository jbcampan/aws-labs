###############################
# Cloudwatch Log group
###############################

resource "aws_cloudwatch_log_group" "lambda" {
  # AWS naming convention: /aws/lambda/<function-name>
  name              = "/aws/lambda/${var.project_name}-processor"
  retention_in_days = 7

  tags = local.common_tags
}