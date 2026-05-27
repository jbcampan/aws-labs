# ─── Step Functions State Machine ─────────────────────────────────────────────

resource "aws_sfn_state_machine" "order_pipeline" {
  name     = "${local.prefix}-order-pipeline"
  role_arn = aws_iam_role.sfn_exec.arn
  type     = "STANDARD" # Exactly-once, full auditability, up to 1 year execution history

  # Amazon States Language (ASL) — defines the full workflow
  definition = jsonencode({
    Comment = "E-commerce order processing pipeline — lab-01-orchestration-lambda"
    StartAt = "ValidateOrder"

    States = {

      # ── State 1: Order validation ───────────────────────────────────────────
      ValidateOrder = {
        Type     = "Task"
        Resource = aws_lambda_function.functions["validate-order"].arn
        Comment  = "Validates required fields and order consistency"

        # Retry on transient Lambda errors (throttling, network issues)
        # Note: ValidationError is not retried — it fails immediately
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleFailure"
            ResultPath  = "$.error"
          }
        ]

        Next = "CheckInventory"
      }

      # ── State 2: Inventory check ────────────────────────────────────────────
      CheckInventory = {
        Type     = "Task"
        Resource = aws_lambda_function.functions["check-inventory"].arn
        Comment  = "Checks product availability in inventory"

        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleFailure"
            ResultPath  = "$.error"
          }
        ]

        Next = "CheckStockAvailability"
      }

      # ── State 3: Conditional branching on stock ─────────────────────────────
      # Choice state — equivalent to an if/else in ASL
      CheckStockAvailability = {
        Type    = "Choice"
        Comment = "Branches based on stock availability"

        Choices = [
          {
            # Condition: if in stock → proceed to payment
            Variable      = "$.inventory_status"
            StringEquals  = "in-stock"
            Next          = "ProcessPayment"
          }
        ]

        # If no condition matches (out-of-stock) → failure
        Default = "HandleFailure"
      }

      # ── State 4: Payment processing ─────────────────────────────────────────
      ProcessPayment = {
        Type     = "Task"
        Resource = aws_lambda_function.functions["process-payment"].arn
        Comment  = "Processes payment — with retry and exponential backoff"

        # Retry with exponential backoff: 3 attempts (2s → 4s → 8s)
        Retry = [
          {
            ErrorEquals     = ["PaymentGatewayException", "Lambda.ServiceException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
            Comment         = "Retry on transient payment gateway errors — exponential backoff"
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleFailure"
            ResultPath  = "$.error"
            Comment     = "Catch all errors after retries are exhausted"
          }
        ]

        Next = "FinalizeOrder"
      }

      # ── State 5: Parallel finalization ──────────────────────────────────────
      # Parallel: both branches run simultaneously
      # Step Functions waits for BOTH branches to complete
      FinalizeOrder = {
        Type    = "Parallel"
        Comment = "Sends confirmation AND writes to DynamoDB in parallel"

        Branches = [
          # Branch A — Customer confirmation via Lambda + SNS
          {
            StartAt = "SendConfirmation"
            States = {
              SendConfirmation = {
                Type     = "Task"
                Resource = aws_lambda_function.functions["send-confirmation"].arn
                Comment  = "Publishes confirmation to customer SNS topic"
                Retry = [
                  {
                    ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
                    IntervalSeconds = 1
                    MaxAttempts     = 2
                    BackoffRate     = 2
                  }
                ]
                End = true
              }
            }
          },

          # Branch B — DynamoDB persistence (direct AWS SDK integration, no Lambda)
          {
            StartAt = "SaveOrderToDynamoDB"
            States = {
              SaveOrderToDynamoDB = {
                Type     = "Task"
                Resource = "arn:aws:states:::dynamodb:putItem"
                Comment  = "Persists order in DynamoDB — direct SDK integration"

                Parameters = {
                  TableName = aws_dynamodb_table.orders.name

                  # Values with .$ indicate JSONPath from input
                  Item = {
                    order_id        = { "S.$" = "$.order_id" }
                    customer_id     = { "S.$" = "$.customer_id" }
                    product_id      = { "S.$" = "$.product_id" }
                    transaction_id  = { "S.$" = "$.transaction_id" }
                    payment_status  = { "S.$" = "$.payment_status" }
                    status          = { S = "COMPLETED" }
                  }
                }

                Retry = [
                  {
                    ErrorEquals     = ["DynamoDB.ProvisionedThroughputExceededException", "DynamoDB.RequestLimitExceeded"]
                    IntervalSeconds = 1
                    MaxAttempts     = 2
                    BackoffRate     = 2
                  }
                ]

                End = true
              }
            }
          }
        ]

        # If Parallel fails → handle-failure
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleFailure"
            ResultPath  = "$.error"
          }
        ]

        Next = "OrderSucceeded"
      }

      # ── Success terminal state ──────────────────────────────────────────────
      OrderSucceeded = {
        Type    = "Succeed"
        Comment = "Order successfully processed — normal workflow completion"
      }

      # ── Global failure handler ──────────────────────────────────────────────
      HandleFailure = {
        Type     = "Task"
        Resource = aws_lambda_function.functions["handle-failure"].arn
        Comment  = "Single failure entry point — logging + SNS alerting"

        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]

        Next = "OrderFailed"
      }

      # ── Failure terminal state ──────────────────────────────────────────────
      OrderFailed = {
        Type    = "Fail"
        Error   = "OrderProcessingFailed"
        Cause   = "Order processing failed — see handle-failure logs for details"
        Comment = "Abnormal workflow termination — visible in Step Functions console"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true # Logs inputs/outputs of each state
    level                  = "ALL"
  }
}