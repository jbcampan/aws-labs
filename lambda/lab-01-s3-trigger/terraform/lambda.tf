###############################
# Lambda Code packaging
###############################
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../script"
  output_path = "${path.module}/../script/lambda_package.zip"
}


###############################
# Lambda Function
###############################
resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor"
  description   = "Convert CSV files uploaded to the source S3 bucket into JSON files in the destination S3 bucket"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256  # Triggers redeployment if the code changes
  handler          = "handler.lambda_handler"                      # file.function
  runtime          = "python3.12"

  role    = aws_iam_role.lambda.arn
  timeout = 30   # seconds
  memory_size = 128 # MB — minimum, enough for observing cold start

  # Environment variables for Python
  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.destination.bucket
    }
  }

  # Log group must exist BEFORE the Lambda starts (otherwise permission denied on logs)
  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_permissions,
  ]

  tags = local.common_tags
}


###############################
# Lambda Resource Policy (S3 → Lambda permission)
###############################
# KEY CONCEPT: two distinct permission layers

# 1. IAM Role (above): allows LAMBDA to access S3
# 2. Resource Policy (here): allows S3 to INVOKE Lambda

# Without this resource policy, S3 gets an "Access Denied" when it tries
# to trigger the Lambda — a classic, silent, and hard-to-debug error.

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source.arn

  source_account = data.aws_caller_identity.current.account_id
}