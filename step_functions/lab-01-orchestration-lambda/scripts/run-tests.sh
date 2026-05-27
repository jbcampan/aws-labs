#!/usr/bin/env bash
# ─── lab-01 : Execution scripts to test different scenarios ────────────────
#
# Usage :
#   chmod +x run-tests.sh
#   ./run-tests.sh
#
# Prerequisites :
#   - AWS CLI configured with proper credentials
#   - Terraform applied (terraform -chdir=terraform apply)
#   - jq installed (brew install jq / apt install jq)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

REGION="${AWS_REGION:-eu-west-3}"

# Retrieve State Machine ARN from Terraform outputs
STATE_MACHINE_ARN=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw state_machine_arn 2>/dev/null || echo "")

if [[ -z "$STATE_MACHINE_ARN" ]]; then
  echo "❌ Unable to retrieve State Machine ARN."
  echo "   Make sure Terraform has been applied: terraform -chdir=terraform apply"
  exit 1
fi

echo "✅ State Machine: $STATE_MACHINE_ARN"
echo ""

# ─── Utility function ────────────────────────────────────────────────────────

run_execution() {
  local scenario="$1"
  local input="$2"
  local execution_name="${scenario}-$(date +%s)"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚀 Scenario : $scenario"
  echo "   Input    : $input"
  echo ""

  EXECUTION_ARN=$(aws stepfunctions start-execution \
    --region "$REGION" \
    --state-machine-arn "$STATE_MACHINE_ARN" \
    --name "$execution_name" \
    --input "$input" \
    --query "executionArn" \
    --output text)

  echo "   Execution started : $EXECUTION_ARN"
  echo "   Console : https://console.aws.amazon.com/states/home?region=${REGION}#/executions/details/${EXECUTION_ARN}"
  echo ""

  # Wait for completion (poll every 2s, max 60s)
  local status="RUNNING"
  local attempts=0
  while [[ "$status" == "RUNNING" && $attempts -lt 30 ]]; do
    sleep 2
    status=$(aws stepfunctions describe-execution \
      --region "$REGION" \
      --execution-arn "$EXECUTION_ARN" \
      --query "status" \
      --output text)
    attempts=$((attempts + 1))
    echo -n "."
  done
  echo ""

  if [[ "$status" == "SUCCEEDED" ]]; then
    echo "   ✅ Status : SUCCEEDED"
    aws stepfunctions describe-execution \
      --region "$REGION" \
      --execution-arn "$EXECUTION_ARN" \
      --query "output" \
      --output text | jq '.' 2>/dev/null || echo "(no output)"
  elif [[ "$status" == "FAILED" ]]; then
    echo "   ❌ Status : FAILED"
    aws stepfunctions describe-execution \
      --region "$REGION" \
      --execution-arn "$EXECUTION_ARN" \
      --query "{cause: cause, error: error}" \
      --output json
  else
    echo "   ⏳ Status : $status (timeout reached, check console)"
  fi

  echo ""
}

# ─── Scenario 1: Valid order, in-stock product, amount < 500 ────────────────
# Expected: SUCCEEDED — full pipeline including Parallel branch
run_execution "scenario-1-happy-path" '{
  "order_id": "ORD-001",
  "customer_id": "CUST-42",
  "product_id": "PROD-001",
  "quantity": 2,
  "amount": 99.99
}'

# ─── Scenario 2: Forced out-of-stock product ────────────────────────────────
# Expected: FAILED — Choice routes to HandleFailure (out-of-stock)
run_execution "scenario-2-out-of-stock" '{
  "order_id": "ORD-002",
  "customer_id": "CUST-42",
  "product_id": "PROD-OUT",
  "quantity": 1,
  "amount": 49.99
}'

# ─── Scenario 3: Amount >= 1000, payment always fails ───────────────────────
# Expected: FAILED — 3 retries in ProcessPayment, then Catch → HandleFailure
run_execution "scenario-3-payment-always-fails" '{
  "order_id": "ORD-003",
  "customer_id": "CUST-99",
  "product_id": "PROD-001",
  "quantity": 1,
  "amount": 1500.00
}'

# ─── Scenario 4: Amount 500–999, flaky payment ──────────────────────────────
# Expected: variable — may SUCCEED after retries or FAIL depending on randomness
# Run multiple times to observe both behaviors
run_execution "scenario-4-payment-flaky" '{
  "order_id": "ORD-004",
  "customer_id": "CUST-77",
  "product_id": "PROD-002",
  "quantity": 3,
  "amount": 750.00
}'

# ─── Scenario 5: Missing fields — validation failure ────────────────────────
# Expected: FAILED — ValidateOrder throws ValidationError
run_execution "scenario-5-validation-error" '{
  "order_id": "ORD-005",
  "customer_id": "CUST-42",
  "product_id": "PROD-001"
}'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All scenarios executed."
echo ""
echo "🔍 To view all executions:"
echo "   https://console.aws.amazon.com/states/home?region=${REGION}#/statemachines/view/${STATE_MACHINE_ARN}"
echo ""
echo "📋 To list executions via CLI:"
echo "   aws stepfunctions list-executions --state-machine-arn ${STATE_MACHINE_ARN} --region ${REGION}"
echo ""
echo "🗑️  To destroy the lab:"
echo "   terraform -chdir=terraform destroy"