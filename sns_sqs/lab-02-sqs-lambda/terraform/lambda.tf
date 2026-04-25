# #########################################
# Lambda - packaging the Python code
# #########################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../script/handler.py"
  output_path = "${path.module}/../lambda/handler.zip"
}

resource "aws_lambda_function" "consumer" {
  function_name    = "${var.project_name}-consumer"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10 # secondes

  environment {
    variables = {
      FAILURE_RATE = var.failure_rate # e.g., "0.4" = 40% chance of failure
      LOG_LEVEL    = "INFO"
    }
  }

  tags = var.tags
}

# #########################################
# Event Source Mapping SQS → Lambda
# #########################################
# This is the AWS mechanism that continuously polls SQS and triggers Lambda
# Lambda receives up to batch_size messages per invocation
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 5    # Lambda receives up to 5 messages per invocation
  enabled          = true

  # report_batch_item_failures allows only failed messages to be retried;
  # otherwise, the entire batch is retried in case of an error.
  function_response_types = ["ReportBatchItemFailures"]
}
