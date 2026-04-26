###############################
# S3 Buckets
###############################
# Source buckets
resource "aws_s3_bucket" "source" {
  bucket        = "${var.project_name}-source-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Pratique en lab : évite l'erreur "bucket non vide" au destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Destination Bucket
resource "aws_s3_bucket" "destination" {
  bucket        = "${var.project_name}-destination-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = local.common_tags
}


###############################
# S3 Event notification
###############################
# The notification must be created AFTER the Lambda resource policy,
# otherwise S3 cannot validate that it has permission to invoke the Lambda.

resource "aws_s3_bucket_notification" "source" {
  bucket = aws_s3_bucket.source.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"] # Any upload (PUT, POST, COPY, multipart)
    filter_prefix       = "uploads/"             # Only files in this prefix
    filter_suffix       = ".csv"                 # Only CSV files
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}