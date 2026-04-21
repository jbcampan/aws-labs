######################################
# Zip archive — built by Terraform
######################################
# Instead of zipping index.py manually before every deploy,
# we let Terraform do it via the "archive_file" data source.
#
# Benefits:
#   - No manual step: `terraform apply` always uses the latest code.
#   - source_code_hash is derived from the real zip content, so Lambda
#     only redeploys when the Python file actually changes.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../script/index.py"  # path relative to this .tf file
  output_path = "${path.module}/function.zip"         # Terraform writes the zip here
}

######################################
# Lambda Function
######################################
resource "aws_lambda_function" "lambda_function" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn

  # Point to the zip produced above.
  # output_base64sha256 is the hash Terraform uses to detect code changes —
  # Lambda will only be updated when the hash differs from the deployed version.
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # "index"   = the Python file name (index.py)
  # "handler" = the function name inside that file
  handler = "index.handler"
  runtime = "python3.12"
  timeout = 10  # seconds; default is 3 — raise if your function does I/O

  # ---------------------------------------------------------------------------
  # Structured JSON logging (native Lambda feature, available since 2023)
  # ---------------------------------------------------------------------------
  # Without this block, Lambda writes plain text logs:
  #   "START RequestId: … Version: $LATEST"
  #   "END RequestId: …"
  #   "REPORT RequestId: … Duration: … Billed Duration: …"
  # Those are hard to query in Log Insights.
  #
  # With log_format = "JSON", every log entry becomes a proper JSON object
  # that Log Insights can parse field by field — no regex needed.
  #
  # application_log_level = "INFO"
  #   Controls which levels emitted by *your code* (logger.info/warning/error)
  #   are forwarded to CloudWatch. INFO includes INFO, WARNING, and ERROR.
  #
  # system_log_level = "WARN"
  #   Controls Lambda's own runtime messages (START, END, REPORT, …).
  #   WARN keeps the noise down — you usually don't need DEBUG runtime logs.
  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  # ---------------------------------------------------------------------------
  # Explicit dependency ordering
  # ---------------------------------------------------------------------------
  # Terraform usually infers dependencies from resource references, but here we
  # make two extra guarantees explicit:
  #
  # 1. aws_iam_role_policy_attachment.lambda_logs
  #    The IAM role must have the logging policy *attached* (not just created)
  #    before Lambda starts — otherwise the first invocation may fail with an
  #    access-denied error when it tries to write to CloudWatch.
  #
  # 2. aws_cloudwatch_log_group.lambda_logs
  #    If the log group doesn't exist yet when Lambda first runs, AWS creates it
  #    automatically — but *without* the 7-day retention we configured in
  #    cloudwatch.tf.  Creating it first ensures our retention setting is in place
  #    from the very first log event.
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Environment = var.environment
    Project     = "lab-03-log-insights"
    Application = "log-insights-demo"
    Function    = var.function_name
  }
}
