# ─── DynamoDB — Orders table ──────────────────────────────────────────────────
# Used in the Parallel branch to persist the final order state.

resource "aws_dynamodb_table" "orders" {
  name         = "${local.prefix}-orders"
  billing_mode = "PAY_PER_REQUEST" # On-demand, no fixed cost for a lab environment
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}