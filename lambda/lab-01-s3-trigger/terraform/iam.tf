###############################
# IAM Role
###############################
resource "aws_iam_role" "lambda" {
  name        = "${var.project_name}-lambda-role"
  description = "Lambda execution role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

###############################
# IAM Policy
###############################
resource "aws_iam_policy" "lambda_permissions" {
  name        = "${var.project_name}-lambda-policy"
  description = "Least privilege policy for Lambda (S3 + logs)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

        # Reading from the source bucket (least privilege)
      {
        Sid    = "ReadSourceBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },

        # Writing to the destination bucket only
      {
        Sid    = "WriteDestinationBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.destination.arn}/*"
      },

        # CloudWatch logs: creation of log streams and writing of events
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

###############################
# Policy attachment
###############################
resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}