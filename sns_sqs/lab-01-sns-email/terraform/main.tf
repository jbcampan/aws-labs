######################################
# SNS Topic (core pub/sub bus)
######################################
resource "aws_sns_topic" "lab01_topic" {
  name = "lab01-fanout-topic"
}

######################################
# SQS Queue (subscriber #1)
######################################
resource "aws_sqs_queue" "lab01_queue" {
  name = "lab01-fanout-queue"
}

######################################
# SQS Queue Policy
# Allow SNS to publish into SQS
######################################
data "aws_iam_policy_document" "lab01_sqs_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.lab01_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.lab01_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "lab01_queue_policy" {
  queue_url = aws_sqs_queue.lab01_queue.id
  policy    = data.aws_iam_policy_document.lab01_sqs_policy.json
}

######################################
# SNS Subscription → SQS
######################################
resource "aws_sns_topic_subscription" "lab01_sqs_subscription" {
  topic_arn = aws_sns_topic.lab01_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.lab01_queue.arn
}

######################################
# SNS Subscription → Email
######################################
resource "aws_sns_topic_subscription" "lab01_email_subscription" {
  topic_arn = aws_sns_topic.lab01_topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}